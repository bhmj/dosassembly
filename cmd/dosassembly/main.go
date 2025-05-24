package main

import (
	"flag"
	"fmt"
	syslog "log"
	"os"

	"github.com/bhmj/dosassembly/internal/app/dosassembly"
	"github.com/bhmj/goblocks/conftool"
	"github.com/bhmj/goblocks/log"
)

const appVersion string = "dev" // set at build time to "YYYY-MM-DD-HASH", see Makefile

func main() {
	fmt.Printf("dosassembly project, version %s\n", appVersion)
	// try to load config
	conf := flag.String("config-file", "", "")
	flag.Parse()
	configFile := ""
	if conf == nil || *conf == "" {
		fmt.Println("--help for help")
		os.Exit(0)
	}
	configFile = *conf
	cfg := &dosassembly.Config{}
	err := conftool.ReadFromFile(configFile, cfg)
	if err != nil {
		syslog.Fatal(err.Error())
	}

	logger, err := log.New(cfg.LogLevel, false)
	if err != nil {
		syslog.Fatal(err.Error())
	}
	defer func() { _ = logger.Sync() }()

	dosassembly.New(cfg, logger).Run()
}
