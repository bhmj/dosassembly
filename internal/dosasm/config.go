package dosasm

import (
	"github.com/bhmj/goblocks/dbase"
)

type Config struct {
	APIBase            string       `yaml:"api_base" default:"api/" description:"Service name for metrics"`
	Name               string       `yaml:"name" description:"Service name for metrics" default:"dosassembly"`
	DBase              dbase.Config `yaml:"dbase" description:"DB config"`
	PlaygroundServer   string       `yaml:"playground_server" description:"Playground server host"`
	PlaygroundAPIToken string       `yaml:"playground_api_token" description:"Playground API token"`
	TemplatesPath      string       `yaml:"templates_path" description:"Absolute path to templates" required:"true"`
}
