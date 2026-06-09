# Catalog Service — Agent Guide

## Project Overview

The Catalog Service is a Go REST microservice responsible for managing the product catalog. It is built with the Gin HTTP framework and exposes a JSON API for listing, retrieving, and creating products.

The service is stateless, deployed as a single binary, and configured via environment variables.

## Architecture

The service follows a handler/model pattern. Gin routes requests to the appropriate handler based on the URL path.

**Components:**

- `handlers/product.go` — `ProductHandler`: Handles GET /products, GET /products/:id, and POST /products. Validates request bodies with `ShouldBindJSON`.
- `models/product.go` — `Product`: Domain struct with fields ID, Name, CategoryID, Price (float64), and InStock (bool).
- `main.go` — Entry point. Registers routes and starts the HTTP listener on port 8080.

## Development Guide

### Prerequisites

- Go 1.21 or later
- `make` (GNU Make)

### Common Commands

| Command | Description |
|---------|-------------|
| `make build` | Compile the binary to `./bin/catalogservice` |
| `make test` | Run the full test suite |
| `make run` | Build and run the service locally on port 8080 |
| `make lint` | Run `golangci-lint` |

### Running Locally

```bash
make run
```

The service starts on port 8080 and logs `Starting catalog service on :8080`.

## Key Conventions

- Handlers live under `handlers/`; domain structs live under `models/`.
- JSON field names use snake_case via struct tags.
- Error responses always use `{"error": "<message>"}`.
- Handlers are stateless structs with no shared mutable state.
- Tests live alongside source files using the `_test.go` naming convention.
