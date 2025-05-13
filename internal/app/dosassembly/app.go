package dosassembly

import (
	"context"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/bhmj/dosassembly/internal/app/service"
	"github.com/bhmj/goblocks/log"
	"github.com/bhmj/goblocks/metrics"
)

// App ...
type App interface {
	Run()
}

type app struct {
	cfg    *Config
	logger log.MetaLogger
}

// New creates application
func New(cfg *Config, logger log.MetaLogger) App {
	// init app
	return &app{cfg: cfg, logger: logger}
}

// Run runs application
func (a *app) Run() {
	metricsRegistry, err := metrics.NewRegistry(a.cfg.Service.Prometheus.Metrics)
	if err != nil {
		a.logger.Error(err.Error())
		return
	}
	// main service
	svc, err := service.New(a.logger, &a.cfg.Service, metricsRegistry)
	if err != nil {
		a.logger.Error("creating main service", log.Error(err))
		return
	}

	a.launch(svc)
}

// launch/shutdown scheme
// 1. process start
//       |
// 2. k8s health set alive=true, ready=false
// 3. async start: prometheus server, http_api server
// 4. set ready=true if all services from (3) are ready
//
// 1. shutdown signal
//       |
// 2. k8s health set ready=false
// 3. stop accepting new connections and requests to http server
// 4. finalize responses to running requests
// 5. stop prometeus server
// 6. set alive=false
// 7. stop http server

func (a *app) launch(svc *service.Service) {
	var wg sync.WaitGroup

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	wg.Add(1)
	// backend service
	go func() {
		defer wg.Done()
		defer cancel()
		_ = svc.Run(ctx)
	}()

	wg.Add(1)
	// SIGTERM handler
	go func() {
		defer wg.Done()
		defer cancel()
		ch := make(chan os.Signal, 1)
		signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)
		select {
		case <-ctx.Done():
			return
		case signal := <-ch:
			a.logger.Info("signal received", log.String("signal", signal.String()))
			a.logger.Info("shutting down", log.Duration("delay", a.cfg.Service.ShutdownDelay))
			time.Sleep(a.cfg.Service.ShutdownDelay)
			cancel()
		}
	}()

	wg.Wait()
}
