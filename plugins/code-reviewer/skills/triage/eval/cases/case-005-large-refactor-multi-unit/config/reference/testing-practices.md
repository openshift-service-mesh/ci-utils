# Testing Practices (Go — Layered Architecture)

## Unit Tests (Services)
- Test services using the `InMemoryRepository` fake — never a real database.
- Cover: happy path, validation errors, not-found, and conflict cases.
- Service tests live in `services/<name>_test.go` with package `services_test`.

## Unit Tests (Repositories)
- Test repository implementations (InMemory) with pure in-process tests.
- The Postgres implementation must have integration tests gated behind a build tag.

## Handler Tests
- Use `httptest.NewRecorder` and wire handlers with a fake service.
- Do not test handler logic that belongs in services; test HTTP contract only.

## Refactoring Tests
- When moving logic from one layer to another, ensure existing tests still pass.
- Do not delete `t.Skip` placeholders — replace them with real tests or delete the file.
