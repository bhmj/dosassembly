package service

import (
	"context"
	"fmt"
	"net/http"
	"regexp"
	"time"

	"github.com/bhmj/goblocks/log"

	"github.com/google/uuid"
)

type (
	HandlerWithResult func(w http.ResponseWriter, r *http.Request) (int, error)
)

type rawHandlerDefinition struct {
	Method string
	Path   string
	Func   HandlerWithResult
}

// GetHandlers returns a list of handlers for the server
func (s *Service) GetHandlers() (handlers []HandlerDefinition) {
	api := func(path string) string {
		return fmt.Sprintf("/%s%s", s.cfg.HTTP.APIBase, path)
	}
	raw := []rawHandlerDefinition{
		{Method: "GET", Path: "/", Func: s.HandleIndex},
		{Method: "GET", Path: "/{source_token:[a-zA-Z0-9]{6}}/", Func: s.HandleIndexWithToken},
		{Method: "POST", Path: api("/save/"), Func: s.HandleSave},
		{Method: "POST", Path: api("/compile/"), Func: s.HandleCompile},
		{Method: "OPTIONS", Path: api("/compile/"), Func: s.HandleCompileCORS},
	}
	for i := range raw {
		handler := HandlerDefinition{
			Method: raw[i].Method,
			Path:   raw[i].Path,
			Func:   s.applyMiddlewares(raw[i].Func, "dosasm", raw[i].Path),
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
	var remoteAddressMask = regexp.MustCompile(`(.*):\d+`)

	return func(w http.ResponseWriter, r *http.Request) {
		// get real remote address
		remoteAddr := r.RemoteAddr
		if x, found := r.Header["X-Real-IP"]; found { //nolint:go-staticcheck
			remoteAddr = x[0]
		} else if x, found := r.Header["X-Real-Ip"]; found {
			remoteAddr = x[0]
		} else if x, found := r.Header["X-Forwarded-For"]; found {
			remoteAddr = x[0]
		}
		r.RemoteAddr = remoteAddressMask.ReplaceAllString(remoteAddr, "$1")

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
		code, err := fn(w, r)
		if err != nil {
			logger.Error(fmt.Sprintf("%v", err))
			s.replier.ReplyError(w, err, code)
		}
		duration := time.Since(start)

		s.apiMetrics.ScoreAPI(backendName, handlerName, code, duration)

		logger.Info("finish serving request", log.Int("http_code", code), log.Duration("duration", duration))
	}
}
