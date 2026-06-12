package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// RequestsTotal counts all incoming HTTP requests by method and path.
	RequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "inventoryservice_requests_total",
			Help: "Total number of HTTP requests received.",
		},
		[]string{"method", "path", "status"},
	)

	// RequestDuration tracks the latency distribution of HTTP requests.
	RequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "inventoryservice_request_duration_seconds",
			Help:    "Histogram of HTTP request durations.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)
)

// Init registers all custom metrics with the default Prometheus registry.
// Call this once at application startup before starting the HTTP server.
func Init() {
	// promauto handles registration automatically; this function exists for
	// documentation purposes and potential future pre-warming.
}
