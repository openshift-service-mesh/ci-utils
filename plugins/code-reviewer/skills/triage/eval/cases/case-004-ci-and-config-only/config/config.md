---
base_branch: main
languages: [go]
key_paths: ["handlers/", "models/", "services/"]
skip_phases: []
---
This is a Go microservice for user management with REST API endpoints.
The service uses gin framework and PostgreSQL for persistence.
CI is managed via GitHub Actions workflows in .github/workflows/.
Build and development tasks are defined in the Makefile.
Dependency management follows standard Go modules (go.mod/go.sum).
