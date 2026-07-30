package api

import "net/http"

// HandleUsers serves the /users resource: list and create.
func HandleUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		// list users
	case http.MethodPost:
		// create user
	}
}
