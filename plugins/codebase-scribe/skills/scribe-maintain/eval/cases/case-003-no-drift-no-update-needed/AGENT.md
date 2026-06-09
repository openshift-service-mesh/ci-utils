# Order Service — Agent Guide

## Project Overview

The Order Service is a Go REST microservice responsible for managing customer orders within the platform. It is built with the Gin HTTP framework and exposes a JSON API for creating, retrieving, and updating order state.

The service is stateless and deployed as a single binary. All runtime configuration is provided through environment variables.

## Architecture

The service uses a handler/model separation. Gin routes HTTP requests to `OrderHandler`, which validates inputs and returns structured JSON.

**Components:**

- `handlers/order.go` — `OrderHandler`: Handles GET /orders, GET /orders/:id, POST /orders, and PUT /orders/:id/status. Uses `ShouldBindJSON` for body parsing and returns 400 on validation failure.
- `models/order.go` — `Order`: Domain struct with fields ID, UserID, Total (float64), and Status (string).
- `main.go` — Entry point. Registers all four routes on the Gin router and starts the HTTP listener on port 8080.

## Development Guide

### Prerequisites

- Go 1.21 or later
- `make` (GNU Make)

### Common Commands

| Command | Description |
|---------|-------------|
| `make build` | Compile the binary to `./bin/orderservice` |
| `make test` | Run the full test suite |
| `make run` | Build and run the service locally on port 8080 |
| `make lint` | Run `golangci-lint` |

### Running Locally

```bash
make run
```

The service starts on port 8080 and logs `Starting order service on :8080`.

## Key Conventions

- Handlers live under `handlers/`; domain structs live under `models/`.
- All JSON field names use snake_case via struct tags.
- Error responses always use `{"error": "<message>"}`.
- Handlers are stateless structs with no shared mutable state.
- Tests live alongside their source files using the `_test.go` naming convention.
