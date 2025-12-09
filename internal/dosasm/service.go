package dosasm

import (
	"context"
	"errors"

	"github.com/bhmj/goblocks/appstatus"
	"github.com/bhmj/goblocks/dbase"
	"github.com/bhmj/goblocks/dbase/abstract"
	"github.com/bhmj/goblocks/log"
	"github.com/bhmj/goblocks/metrics"
)

type Service struct {
	cfg            *Config
	logger         log.MetaLogger
	statusReporter appstatus.ServiceStatusReporter
	db             abstract.DB
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
		logger:         logger,
		cfg:            cfg,
		statusReporter: statusReporter,
		db:             database,
	}

	return svc, nil
}

func (s *Service) Run(ctx context.Context) error {
	s.statusReporter.Ready()
	<-ctx.Done()
	return nil
}
