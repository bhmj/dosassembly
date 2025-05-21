package service

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/bhmj/goblocks/dbase"
	"github.com/bhmj/goblocks/dbase/abstract"
	"github.com/bhmj/goblocks/httpreply"
	"github.com/bhmj/goblocks/httpserver"
	"github.com/bhmj/goblocks/log"
	"github.com/bhmj/goblocks/metrics"
	"github.com/bhmj/goblocks/prometheus"
	"github.com/bhmj/goblocks/sentry"
	"golang.org/x/sync/errgroup"
)

const (
	sentryShutdownTimeout = 1 * time.Second
)

type Config struct {
	Name               string            `yaml:"name" description:"Service name for metrics" default:"dosassembly"`
	DBase              dbase.Config      `yaml:"dbase" description:"DB config"`
	ShutdownDelay      time.Duration     `yaml:"shutdown_delay" description:"Grace period from readiness off to server down" default:"2s"`
	Prometheus         prometheus.Config `yaml:"prometheus" description:"Prometheus config for the service"`
	HTTP               httpserver.Config `yaml:"http" description:"HTTP endpoint configuration"`
	Sentry             sentry.Config     `yaml:"sentry" description:"Sentry configuration"`
	PlaygroundServer   string            `yaml:"playground_server" description:"Playground server host"`
	PlaygroundAPIToken string            `yaml:"playground_api_token" description:"Playground API token"`
	TemplatesPath      string            `yaml:"templates_path" description:"Absolute path to templates" required:"true"`
}

type Service struct {
	cfg              *Config
	logger           log.MetaLogger
	apiMetrics       *apiMetrics
	prometheusServer *metrics.PrometheusServer
	apiServer        *apiServer
	sentryService    *sentry.Service
	replier          httpreply.Replier
	db               abstract.DB
}

// HandlerDefinition contains method definition to use by HTTP server
type HandlerDefinition struct {
	Code   string
	Method string
	Path   string
	Func   http.HandlerFunc
}

// New returns proxy service instance
func New(
	logger log.MetaLogger,
	cfg *Config,
	metricsRegistry *metrics.Registry,
) (*Service, error) {
	database := dbase.New(context.Background(), logger, cfg.DBase)
	if database == nil {
		return nil, errors.New("couldn't connect to DB")
	}

	apiMetrics := newAPIMetrics(metricsRegistry.Get(), cfg.Prometheus.Metrics)

	sentryService, err := sentry.NewService(cfg.Sentry)
	if err != nil {
		return nil, fmt.Errorf("create sentry service: %w", err)
	}

	svc := &Service{
		logger:        logger,
		cfg:           cfg,
		apiMetrics:    apiMetrics,
		sentryService: sentryService,
		replier:       httpreply.NewReplier(logger),
		db:            database,
	}

	apiServer, err := newAPIServer(cfg.HTTP, logger, metricsRegistry.Get(), sentryService)
	if err != nil {
		return nil, fmt.Errorf("failed to create API server: %w", err)
	}
	svc.apiServer = apiServer

	// add service handlers
	for _, v := range svc.GetHandlers() {
		apiServer.HandleFunc(v.Method, v.Path, v.Func)
	}
	svc.prometheusServer = metrics.NewPrometheusServer(logger, metricsRegistry.Handler(), cfg.Prometheus.Server)

	return svc, nil
}

func (s *Service) Run(ctx context.Context) error {
	eg, ctx := errgroup.WithContext(ctx)

	eg.Go(func() error {
		if err := s.prometheusServer.Run(); err != nil {
			return fmt.Errorf("prometheus server: %w", err)
		}
		return nil
	})

	eg.Go(func() error {
		if err := s.apiServer.Run(); err != nil {
			return fmt.Errorf("api server: %w", err)
		}
		return nil
	})

	eg.Go(func() error {
		<-ctx.Done()
		_ = s.sentryService.Flush(sentryShutdownTimeout)
		_ = s.apiServer.Shutdown(ctx)
		_ = s.prometheusServer.Shutdown(ctx)
		return nil
	})

	return eg.Wait() //nolint:wrapcheck
}
