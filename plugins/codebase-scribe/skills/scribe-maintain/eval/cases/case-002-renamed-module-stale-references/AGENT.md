# API Gateway — Agent Guide

## Project Overview

The API Gateway is a Go service that sits at the network edge and provides a single ingress point for all downstream services. It handles request routing, authentication enforcement, and rate limiting.

The gateway is stateless and horizontally scalable. All configuration is supplied via environment variables. JWT signing keys are read from the `JWT_SIGNING_KEY` environment variable at startup.

## Architecture

The gateway is structured as a thin Gin application with middleware applied globally. Business logic is isolated into focused packages rather than embedded in route handlers.

**Components:**

- `auth/middleware.go` — `JWTMiddleware`: The `auth` package provides JWT validation for all incoming requests. The middleware extracts the Bearer token from the `Authorization` header, verifies the HMAC-SHA256 signature against `JWT_SIGNING_KEY`, and aborts with a 401 if validation fails. All routes are protected by default.
- `main.go` — Entry point. Reads environment configuration, wires middleware onto the Gin router, and starts the HTTP listener on port 8080.

**Request flow:**

```
Client → JWTMiddleware (auth package) → Route Handler → Downstream Service
```

## Development Guide

### Prerequisites

- Go 1.21 or later
- `make` (GNU Make)
- A valid JWT signing key exported as `JWT_SIGNING_KEY`

### Common Commands

| Command | Description |
|---------|-------------|
| `make build` | Compile the binary to `./bin/apigateway` |
| `make test` | Run the full test suite |
| `make run` | Build and run the gateway locally on port 8080 |
| `make lint` | Run `golangci-lint` |

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_SIGNING_KEY` | Yes | HMAC-SHA256 key used to verify JWT tokens |
| `PORT` | No | Override the default listen port (default: 8080) |

## Key Conventions

- Middleware packages expose a single factory function returning `gin.HandlerFunc`.
- Packages are named for their domain responsibility, not their implementation detail.
- All 4xx responses use `{"error": "<message>"}` JSON bodies.
- Tests live alongside source files (`_test.go` suffix).
