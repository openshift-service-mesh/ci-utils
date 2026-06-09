# Inventory Service — Agent Guide

## Project Overview

The Inventory Service is a Go REST microservice that manages physical inventory items for the fulfilment platform. It is built with the Gin HTTP framework and exposes a JSON API for listing, fetching, and creating items.

The service is stateless, deployed as a single binary, and configured via environment variables.

## Architecture

The service follows a handler/model pattern. Gin routes requests to `InventoryHandler`, which validates inputs and returns JSON responses.

**Components:**

- `handlers/inventory.go` — `InventoryHandler`: Handles GET /items, GET /items/:id, and POST /items. Validates request bodies using `ShouldBindJSON`.
- `models/item.go` — `Item`: Domain struct with fields ID, Name, SKU, Quantity (int), and Price (float64).
- `main.go` — Entry point. Registers routes and starts the HTTP listener on port 8080.

## Development Guide

### Prerequisites

- Go 1.21 or later
- `make` (GNU Make)

### Common Commands

| Command | Description |
|---------|-------------|
| `make build` | Compile the binary to `./bin/inventoryservice` |
| `make test` | Run the full test suite |
| `make run` | Build and run the service locally on port 8080 |

### Running Locally

```bash
make run
```

The service starts on port 8080 and logs `Starting inventory service on :8080`.

## Key Conventions

- Handlers live under `handlers/`; domain structs live under `models/`.
- JSON field names use snake_case via struct tags.
- Error responses always use `{"error": "<message>"}`.
- Handlers are stateless structs with no shared mutable state.
- Tests live alongside source files using the `_test.go` naming convention.
