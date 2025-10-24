package dosasm

import (
	"fmt"
	"strings"

	"github.com/bhmj/goblocks/app"
)

// GetHandlers returns a list of handlers for the server
func (s *Service) GetHandlers() []app.HandlerDefinition {
	apiBase := strings.Trim(s.cfg.APIBase, "/")
	api := func(path string) string {
		return fmt.Sprintf("/%s/%s", apiBase, strings.TrimPrefix(path, "/"))
	}
	return []app.HandlerDefinition{
		{Endpoint: "/", Method: "GET", Path: "/", Func: s.HandleIndex},
		{Endpoint: "/source_token", Method: "GET", Path: "/{source_token:[a-zA-Z0-9]{6}}/", Func: s.HandleIndexWithToken},
		{Endpoint: "/save", Method: "POST", Path: api("/save/"), Func: s.HandleSave},
		{Endpoint: "/compile", Method: "POST", Path: api("/compile/"), Func: s.HandleCompile},
		{Endpoint: "/compile(cors)", Method: "OPTIONS", Path: api("/compile/"), Func: s.HandleCompileCORS},
	}
}
