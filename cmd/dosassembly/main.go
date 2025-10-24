package main

import (
	"fmt"
	syslog "log"

	"github.com/bhmj/dosassembly/internal/dosasm"
	"github.com/bhmj/goblocks/app"
	"github.com/bhmj/goblocks/appstatus"
	"github.com/bhmj/goblocks/log"
	"github.com/bhmj/goblocks/metrics"
)

var appVersion = "local"

func DosasmFactory(config any, logger log.MetaLogger, metricsRegistry *metrics.Registry, statusReporter appstatus.ServiceStatusReporter) (app.Service, error) {
	svc, err := dosasm.New(config.(*dosasm.Config), logger, metricsRegistry, statusReporter)
	if err != nil {
		return nil, fmt.Errorf("create dosassembly service: %w", err)
	}
	return svc, nil
}

func main() {
	app := app.New("dosassembly", appVersion)
	err := app.RegisterService("dosasm", &dosasm.Config{}, DosasmFactory)
	if err != nil {
		syslog.Fatalf("register service: %v", err)
	}
	app.Run(nil)
}
