# Testing Practices (Go + TypeScript)

## Go Handler Tests
- Use `httptest.NewRecorder` and a real gin router in `gin.TestMode`.
- Cover: success, invalid input, and service error paths.
- Assert HTTP status and response body shape using `testify/assert`.

## TypeScript Component Tests
- Use React Testing Library; avoid testing implementation details.
- Test: renders without crashing, user can fill form, submit calls API, error state shown.
- Mock `axios` at the module level in component tests.

## Integration
- Payment-related handlers require an integration test with a test database.
- SQL migrations must be tested by running them against a fresh schema in CI.
