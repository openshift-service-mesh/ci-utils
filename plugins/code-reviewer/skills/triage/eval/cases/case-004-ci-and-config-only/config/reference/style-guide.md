# Style Guide (Go)

## Error Handling
- Always check returned errors; never discard with `_` in production paths.
- Wrap errors with context: `fmt.Errorf("doing X: %w", err)`.

## HTTP Handlers
- Validate all input before calling service layer.
- Map domain errors to appropriate HTTP status codes.

## CI / Makefile
- All Makefile targets must be declared in `.PHONY`.
- CI steps should run `go mod verify` before building or testing.
- Use `-race` flag in test runs for race condition detection.
