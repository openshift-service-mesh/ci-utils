---
base_branch: main
languages: [go]
key_paths: ["handlers/", "models/"]
skip_phases: []
---
This is a Go microservice for user management with REST API endpoints.
The service uses gin framework and PostgreSQL for persistence.
Authentication is handled via JWT tokens passed in the Authorization header.
The codebase follows a simple handlers -> services -> db layering convention.
