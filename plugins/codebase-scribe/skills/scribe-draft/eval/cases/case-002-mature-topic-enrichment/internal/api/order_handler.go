package api

import "net/http"

// HandleOrders serves the /orders resource. Added after the last docs pass —
// backend-architecture.md does not mention it yet.
func HandleOrders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		// list orders
	case http.MethodPost:
		// create order
	}
}
