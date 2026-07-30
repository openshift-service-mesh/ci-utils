package api

import "net/http"

// RegisterRoutes centralizes every route registration for the service.
// Per-package init() registration was deliberately avoided here.
func RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/users", HandleUsers)
	mux.HandleFunc("/orders", HandleOrders)
}
