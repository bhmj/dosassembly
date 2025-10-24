package dosasm

import (
	"strconv"
	"time"

	"github.com/bhmj/goblocks/metrics"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

type apiMetrics struct {
	apiLatency *prometheus.HistogramVec
}

func newAPIMetrics(metricsRegistry prometheus.Registerer, conf metrics.Config) *apiMetrics {
	metrics := &apiMetrics{}
	factory := promauto.With(metricsRegistry)

	labelNames := []string{"backend", "method", "code"}
	defaultBuckets := []float64{0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.007, 0.008, 0.009, 0.010, 0.018, 0.030, 0.055, 0.100, 0.180, 0.300, 0.550, 1}
	var buckets []float64
	if len(conf.Buckets) > 0 {
		buckets = conf.Buckets
	} else {
		buckets = defaultBuckets
	}

	metrics.apiLatency = factory.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "api_request_latency",
		Help:    "HTTP API total duration of request in seconds",
		Buckets: buckets,
	}, labelNames)

	return metrics
}

func (m *apiMetrics) ScoreAPI(backend, method string, code int, duration time.Duration) {
	labels := prometheus.Labels{
		"backend": backend,
		"method":  method,
		"code":    strconv.Itoa(code),
	}
	m.apiLatency.With(labels).Observe(duration.Seconds())
}
