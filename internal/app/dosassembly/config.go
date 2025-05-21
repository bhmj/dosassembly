package dosassembly

import (
	"github.com/bhmj/dosassembly/internal/app/service"
	"github.com/bhmj/goblocks/sentry"
)

type Config struct {
	Service    service.Config `yaml:"service" description:"All about service"`
	Sentry     sentry.Config  `yaml:"sentry" description:"Sentry configuration"`
	LogLevel   string         `yaml:"log_level" description:"Log level" default:"info" choice:"debug,info,warn,error,dpanic,panic,fatal"` // nolint:staticcheck
	Production bool           `yaml:"production" description: "Run in production mode" default:"false"`                                   //nolint:govet
}
