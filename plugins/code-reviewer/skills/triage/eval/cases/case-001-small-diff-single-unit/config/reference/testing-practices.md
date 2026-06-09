# Testing Practices (Go)

## Handler Tests
- Use `net/http/httptest` recorder and a real `gin.Engine` in `gin.TestMode`.
- Test at least: success path, validation failure, and not-found case.
- Assert status code and response body shape; do not assert exact error strings.

## Test File Naming
- Place handler tests in `handlers/<file>_test.go` with package `handlers_test`.
- Use `testify/assert` for assertions and `testify/require` when a failure must stop the test.

## Coverage
- New exported functions must have at least one table-driven test.
- Do not commit tests with `t.Skip("not yet implemented")` — either implement or delete.

## Test Doubles
- Prefer interface-based fakes over mocking frameworks.
- Fakes live in `<package>/testdata/` or alongside the package as `_test.go` files.
