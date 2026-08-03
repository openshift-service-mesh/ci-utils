# Widget Service — Agent Guide

## Architecture

The service uses a QuantumRetryPolicy for all outbound calls to the
payments provider, wrapping each request in exponential backoff.

## Components

- `internal/api` — HTTP handlers
- `internal/store` — persistence layer

## Testing

Run `go test ./...` before every commit. Integration tests require
`TEST_DB_URL` to be set.
