---
format_version: 1
---
## Conventions

### Test Organization

- Test files live alongside the package they test (`foo_test.go` next to `foo.go`).
- Integration tests that require external dependencies (DB, network) are in a separate
  `integration/` subdirectory and are gated with a build tag: `//go:build integration`.
- Test function names follow `TestFunctionName_Scenario` (e.g., `TestCreate_DuplicateKey`).

### Assertions

- Use `t.Errorf` for non-fatal assertion failures that allow the test to continue.
- Use `t.Fatalf` when a failure makes further assertions meaningless (e.g., nil pointer check).
- Assertion messages should describe what was expected, not what went wrong:
  prefer `"expected status 200"` over `"got wrong status"`.

### Test Helpers

- Shared test setup belongs in `TestMain` or a helper called `setupTest(t *testing.T)`.
- Test helpers that call `t.Fatal` must accept `testing.TB` (not `*testing.T`) so they
  work inside subtests.
- Do not use `init()` in test files.

### Mocking

- Interfaces used for mocking are defined in the package that consumes them, not the package
  that implements them.
- Hand-rolled fakes are preferred over generated mocks when the interface is small (< 5 methods).
- For large or frequently-changing interfaces, use `go generate` with `mockgen`.

### Coverage

- New packages should reach 70% line coverage before merge.
- Coverage is checked in CI via `go test -coverprofile` — do not disable with build tags.

## Changelog

| Date | Change | Trigger |
|------|--------|---------|
| 2026-01-15 | Initial creation | headless-setup |
| 2026-02-20 | Added mocking conventions | IMP-1 from feature/auth-middleware |
