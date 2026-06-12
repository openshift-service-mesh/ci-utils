---
base_branch: main
languages: [go]
key_paths: ["handlers/", "services/", "repositories/"]
skip_phases: []
---
This is a Go microservice for user management with REST API endpoints.
The service uses gin framework and PostgreSQL for persistence.
The codebase is being refactored from a flat handlers->db pattern to a layered
handlers -> services -> repositories architecture.
- handlers/ contains HTTP handler functions wired to gin routes
- services/ contains business logic and orchestration
- repositories/ contains data access objects and interfaces
Each layer should only depend on the layer directly below it.
Tests live alongside the package they test (e.g., services/user_service_test.go).
