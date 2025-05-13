package service

import (
	"context"
	"fmt"
	"net/http"

	"github.com/bhmj/goblocks/gorillarouter"
	"github.com/bhmj/goblocks/httpserver"
	"github.com/bhmj/goblocks/log"
	"github.com/bhmj/goblocks/sentry"
	"github.com/prometheus/client_golang/prometheus"
)

type apiServer struct {
	httpServer httpserver.Server
}

func newAPIServer(
	cfg httpserver.Config,
	logger log.MetaLogger,
	metricsRegistry prometheus.Registerer,
	sentryService *sentry.Service,
) (*apiServer, error) {
	httpServer, err := httpserver.NewServer(cfg, gorillarouter.New(), logger, metricsRegistry, sentryService.GetHandler())
	if err != nil {
		return nil, fmt.Errorf("create http server: %w", err)
	}
	return &apiServer{
		httpServer: httpServer,
	}, nil
}

func (s *apiServer) Run() error {
	return s.httpServer.Run() //nolint:wrapcheck
}

func (s *apiServer) Shutdown(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx) //nolint:wrapcheck
}

func (s *apiServer) HandleFunc(method, pattern string, handler http.HandlerFunc) {
	s.httpServer.HandleFunc(method, pattern, handler)
}
