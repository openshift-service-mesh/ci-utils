---
format_version: 1
---
## Conventions

### Test Organization

- Test files live alongside the package they test (`foo_test.go` next to `foo.go`).
- Integration tests requiring external dependencies are in a separate `integration/`
  subdirectory, gated with `//go:build integration`.
- Test function names follow the `TestFunctionName_Scenario` pattern
  (e.g., `TestCreate_DuplicateKey`, `TestBuildQuery_EmptyInput`).

### Assertions

- Use `testify/assert` for non-fatal assertions that allow the test to continue on failure.
- Use `testify/require` for fatal assertions where subsequent steps would be meaningless
  if the assertion fails (e.g., require a response is non-nil before asserting on its fields).
- Assertion messages should describe what was expected: `"expected status 200"` not `"wrong status"`.

### Table-Driven Tests

- Table-driven tests are the preferred structure for testing multiple scenarios of the same function.
- Test cases are collected in a slice named `tests` using an anonymous struct.

### Test Helpers

- Shared test setup belongs in `TestMain` or a helper named `setupTest(t *testing.T)`.
- Test helpers that call `t.Fatal` must accept `testing.TB` (not `*testing.T`) so they
  work inside subtests.
- Do not use `init()` in test files.

### Mocking

- Interfaces used for mocking are defined in the consuming package, not the implementing package.
- Hand-rolled fakes are preferred over generated mocks for small interfaces (< 5 methods).
- For larger or frequently-changing interfaces, use `go generate` with `mockgen`.

### Coverage

- New packages should reach 70% line coverage before merge.
- Coverage is checked in CI via `go test -coverprofile`; do not disable with build tags.

## Changelog

| Date | Change | Trigger |
|------|--------|---------|
| 2026-01-15 | Initial creation | headless-setup |
| 2026-02-20 | Added mocking conventions | IMP-1 from feature/auth-middleware |
| 2026-05-10 | Added testify/assert and require conventions | IMP-1 from feature/order-service-tests |
