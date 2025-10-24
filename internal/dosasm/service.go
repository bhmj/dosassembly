package dosasm

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/bhmj/goblocks/appstatus"
	"github.com/bhmj/goblocks/dbase"
	"github.com/bhmj/goblocks/dbase/abstract"
	"github.com/bhmj/goblocks/log"
	"github.com/bhmj/goblocks/metrics"
)

const (
	sentryShutdownTimeout = 1 * time.Second
)

type Service struct {
	cfg             *Config
	logger          log.MetaLogger
	metricsRegistry *metrics.Registry
	statusReporter  appstatus.ServiceStatusReporter
	db              abstract.DB
}

// HandlerDefinition contains method definition to use by HTTP server
type HandlerDefinition struct {
	Code   string
	Method string
	Path   string
	Func   http.HandlerFunc
}

// New returns dosasm service instance
func New(
	cfg *Config,
	logger log.MetaLogger,
	metricsRegistry *metrics.Registry,
	statusReporter appstatus.ServiceStatusReporter,
) (*Service, error) {
	database := dbase.New(context.Background(), logger, cfg.DBase)
	if database == nil {
		return nil, errors.New("couldn't connect to DB")
	}

	svc := &Service{
		logger:          logger,
		cfg:             cfg,
		metricsRegistry: metricsRegistry,
		statusReporter:  statusReporter,
		db:              database,
	}

	return svc, nil
}

func (s *Service) Run(ctx context.Context) error {
	s.statusReporter.Ready()
	<-ctx.Done()
	return nil
}
