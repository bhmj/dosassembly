package service

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/bhmj/goblocks/log"

	"github.com/google/uuid"
)

type (
	HandlerWithResult func(w http.ResponseWriter, r *http.Request) int
)

type rawHandlerDefinition struct {
	Method string
	Path   string
	Func   HandlerWithResult
}

// GetHandlers returns a list of handlers for the server
func (s *Service) GetHandlers() (handlers []HandlerDefinition) {
	web := func(path string) string {
		return fmt.Sprintf("/web%s", path)
	}
	api := func(path string) string {
		return fmt.Sprintf("/%s%s", s.cfg.HTTP.APIBase, path)
	}
	raw := []rawHandlerDefinition{
		{Method: "GET", Path: "/", Func: s.Index},
		{Method: "GET", Path: "/about", Func: s.About},
		{Method: "POST", Path: web("/refresh"), Func: s.WebRefresh},
		{Method: "POST", Path: api("/run"), Func: s.RunProgram},
	}
	for i := range raw {
		handler := HandlerDefinition{
			Method: raw[i].Method,
			Path:   raw[i].Path,
			Func:   s.applyMiddlewares(raw[i].Func, "disassembly", raw[i].Method),
		}
		handlers = append(handlers, handler)
	}
	return handlers
}

// applyMiddlewares wraps a handler with a number of middlewares
//
// The working sequence is as follows:
//  1. incoming request is enriched with RID and possibly key_id (stored in meta logger)
//  2. panic logger, if invoked, writes RID and key_id to logs
//  3. errorer writes meaningful error messages to log and response
//  4. handler executes business logic
func (s *Service) applyMiddlewares(fn HandlerWithResult, backendName, handlerName string) http.HandlerFunc {
	// in reverse order
	errorer := s.responderMiddleware(fn, backendName, handlerName)
	recovery := s.panicLoggerMiddleware(errorer)
	requestid := s.loggingMiddleware(recovery)
	return requestid
}

func (s *Service) loggingMiddleware(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		fields := []log.Field{
			log.String("method", r.Method),
			log.String("uri", r.RequestURI),
			log.String("remote", r.RemoteAddr),
		}
		ctx := r.Context()
		reqID := uuid.New().String()
		fields = append(fields, log.String("rid", reqID)) // request ID is not needed when log is one line only
		contextLogger := s.logger.With(fields...)
		ctx = context.WithValue(ctx, log.ContextMetaLogger, contextLogger)
		fn(w, r.WithContext(ctx))
	}
}

func (s *Service) panicLoggerMiddleware(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				err := recovered.(error)
				ctxlogger := r.Context().Value(log.ContextMetaLogger)
				logger, ok := ctxlogger.(log.MetaLogger)
				if !ok {
					logger = s.logger
				}
				logger.Error("PANIC", log.Error(err), log.Stack("stack"))
				//p.replier.ReplyJSONCode(w, map[string]string{"error": err.Error()}, http.StatusInternalServerError)
				// repanic to pass error to Sentry
				panic(err)
			}
		}()
		fn(w, r)
	}
}

func (s *Service) responderMiddleware(fn HandlerWithResult, backendName, handlerName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctxLogger := r.Context().Value(log.ContextMetaLogger)
		logger, ok := ctxLogger.(log.MetaLogger)
		if !ok {
			logger = s.logger
		}

		logger.Info("started serving request")

		start := time.Now()
		result := fn(w, r)
		duration := time.Since(start)

		s.apiMetrics.ScoreAPI(backendName, handlerName, result, duration)

		//p.replier.ReplyJSONCode(w, result.Response, result.HTTPCode)

		logger.Info("finish serving request", log.Int("http_code", result), log.Duration("duration", duration))
	}
}
