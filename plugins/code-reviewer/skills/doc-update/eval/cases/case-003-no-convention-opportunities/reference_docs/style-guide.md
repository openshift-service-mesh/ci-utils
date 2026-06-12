---
format_version: 1
---
## Conventions

### Naming

- Packages use lowercase single-word names; avoid underscores in package names.
- Exported functions and types use PascalCase; unexported identifiers use camelCase.
- Acronyms follow Go convention: `HTTP`, `URL`, `ID` (not `Http`, `Url`, `Id`).
- Sentinel error variables use the `ErrXxx` pattern and are intended for `errors.Is` comparisons.
- Typed error structs (carrying context fields) use the `XxxErr` suffix (e.g., `ValidationErr`).
- Interface names for a single method end with `-er` (e.g., `Reader`, `Closer`).
- Test helpers are prefixed with `test` (unexported) or `Test` (exported if shared).

### Code Structure

- Each package exposes a minimal surface area; internal types stay unexported where possible.
- Constructor functions are named `New` or `NewXxx` and always return the concrete type plus an error.
- Context is always the first parameter for functions that touch I/O, databases, or external services.
- Pointer types that may be nil must be documented in the godoc comment of the type or field.

### Error Handling

- Errors are wrapped with `fmt.Errorf("...: %w", err)` to preserve the chain.
- Sentinel errors defined at the package level must be exported for `errors.Is`.
- Functions must not swallow errors silently; use `_ = err` only with an explanatory comment.
- Log errors at the boundary where they cross package lines, not at every intermediate call site.
- Nil pointer guards are required at each call site that dereferences an optional pointer type;
  do not assume callers will always pass non-nil values.

### Formatting & Style

- All code is formatted with `gofmt`; indentation uses tabs, never spaces.
- Line length soft limit is 120 characters; hard limit is 160.
- Comments on exported identifiers begin with the identifier name (godoc convention).
- Inline comments explain the *why*, not the *what*.

### Imports

- Imports are grouped in three blocks: stdlib, external, internal — each separated by a blank line.
- Use `goimports` to maintain import order automatically.
- Never mix stdlib and external imports in the same group.

### Testing

- Test files live alongside the package they test (`foo_test.go` next to `foo.go`).
- Use `testify/assert` for non-fatal assertions and `testify/require` for fatal ones.
- Table-driven tests define cases as `[]struct{ name, input, expected }` and run with
  `for _, tc := range tests { t.Run(tc.name, ...) }`.
- New packages reach 70% line coverage before merge.

## Changelog

| Date | Change | Trigger |
|------|--------|---------|
| 2026-01-15 | Initial creation | headless-setup |
| 2026-03-02 | Added error wrapping with %w convention | IMP-2 from feature/payment-errors |
| 2026-04-10 | Added context-as-first-param rule | IMP-2 from feature/db-layer |
| 2026-04-28 | Added typed error struct XxxErr naming | IMP-1 from feature/error-handling-refactor |
| 2026-05-15 | Added testify/assert as standard | IMP-1 from feature/order-service-tests |
| 2026-05-22 | Added table-driven test structure | IMP-1 from feature/user-search |
| 2026-06-01 | Added nil pointer guard rule | Review feedback on fix/session-nil |
