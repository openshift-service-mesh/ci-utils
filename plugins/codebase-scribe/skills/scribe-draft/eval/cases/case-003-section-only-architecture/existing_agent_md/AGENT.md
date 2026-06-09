# user-api

A REST API service for managing user accounts.

## Architecture

<!-- TODO: Architecture section needs to be written -->

This section is a placeholder. The architecture has not yet been documented.
Component details and data flow will be added here.

## Development Guide

### Setup

1. Install Go 1.21+
2. Copy `.env.example` to `.env` and fill in database credentials
3. Run `make run` to start the server

### Building and Testing

```
make build   # compile binary to bin/user-api
make test    # run all unit tests
make lint    # run golangci-lint
```

## Key Conventions

- All handlers live in `handlers/` — one file per resource
- Services must not import from `repositories/` directly; use interfaces
- Use `testify/assert` for test assertions
