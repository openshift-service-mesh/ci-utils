# Testing Practices (Go)

## Test Execution
- Run `go test -race ./...` in CI to catch race conditions.
- Coverage reports must be generated with `-coverprofile` and uploaded to Codecov.
- `go mod tidy` and `go mod verify` should be run before tests in CI to ensure clean dependencies.

## Local Development
- Use `make test` for quick local test runs.
- Use `make ci` for the full check sequence: tidy, lint, test.

## Coverage Requirements
- New handler functions must have at least one test covering the success path.
- Tests must not be skipped via `t.Skip` without a linked issue.
