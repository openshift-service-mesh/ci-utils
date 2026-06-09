# User Service — Agent Guide

## Project Overview

The User Service is a Go REST microservice that manages user accounts. It is built with the Gin HTTP framework and exposes a JSON API consumed by the API gateway and other internal services.

The service is deployed as a single binary, configured entirely via environment variables, and expected to be stateless between requests.

## Architecture

The service follows a handler/model separation pattern. Incoming HTTP requests are routed by Gin to the appropriate handler, which performs validation and delegates to the model layer.

**Components:**

- `handlers/user.go` — `UserHandler`: Handles GET /users, GET /users/:id, and POST /users. Validates request bodies using `ShouldBindJSON` and returns structured JSON responses.
- `models/user.go` — `User`: The primary domain struct. Fields: ID (string), Name (string), Email (string).
- `main.go` — Entry point. Initialises the Gin router, registers all routes, and starts the HTTP listener on port 8080.

The service does not implement any database layer at present; persistence is left to the caller.

## Development Guide

### Prerequisites

- Go 1.21 or later
- `make` (GNU Make)

### Common Commands

| Command | Description |
|---------|-------------|
| `make build` | Compile the binary to `./bin/userservice` |
| `make test` | Run the full test suite |
| `make run` | Build and start the service locally on port 8080 |
| `make lint` | Run `golangci-lint` |

### Running Locally

```bash
export PORT=8080
make run
```

The service will start and log `Starting user service on :8080`.

### Adding a New Handler

1. Create a file under `handlers/` named after the resource.
2. Define a struct ending in `Handler` and a `New<Name>Handler()` constructor.
3. Register routes in `main.go`.

## Key Conventions

- All handlers live under `handlers/`; models live under `models/`.
- JSON field names use snake_case (enforced by struct tags).
- HTTP errors are returned as `{"error": "<message>"}`.
- No global state; handlers are stateless structs.
- Tests live alongside the code they test (`_test.go` suffix).
