package main

import (
	"fmt"
	syslog "log"

	"github.com/bhmj/dosassembly/internal/dosasm"
	"github.com/bhmj/goblocks/app"
)

var appVersion = "local"

func DosasmFactory(config any, options app.Options) (app.Service, error) {
	svc, err := dosasm.New(config.(*dosasm.Config), options.Logger, options.MetricsRegistry, options.ServiceReporter)
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
