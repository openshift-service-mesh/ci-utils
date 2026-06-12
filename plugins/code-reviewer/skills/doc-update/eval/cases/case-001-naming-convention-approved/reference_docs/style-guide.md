---
format_version: 1
---
## Conventions

### Naming

- Packages use lowercase single-word names; avoid underscores in package names.
- Exported functions and types use PascalCase; unexported identifiers use camelCase.
- Acronyms in names follow Go convention: `HTTP`, `URL`, `ID` (not `Http`, `Url`, `Id`).
- Sentinel error variables use the `ErrXxx` pattern (e.g., `ErrNotFound`, `ErrUnauthorized`)
  and are intended for use with `errors.Is`.
- Interface names that describe a single method end with `-er` (e.g., `Reader`, `Closer`).
- Test helper functions (not test cases) are prefixed with `test` (unexported) or `Test` (exported if shared across packages).

### Code Structure

- Each package exposes a minimal surface area; internal types stay in unexported files where possible.
- Constructor functions are named `New` or `NewXxx` and always return the concrete type plus an error.
- Context is always the first parameter when a function touches I/O, databases, or external services.

### Error Handling

- Errors are wrapped with `fmt.Errorf("...: %w", err)` to preserve the chain.
- Sentinel errors defined at the package level must be exported so callers can use `errors.Is`.
- Functions should not swallow errors silently; use `_ = err` only when the comment explains why.
- Log errors at the boundary where they cross package lines, not at every intermediate call site.

### Formatting & Style

- All code is formatted with `gofmt`; no manual column alignment of struct fields.
- Line length soft limit is 120 characters; hard limit is 160.
- Comments on exported identifiers begin with the identifier name (godoc convention).
- Inline comments explain the *why*, not the *what*.

### Imports

- Imports are grouped in three blocks: stdlib, external, internal. Each separated by a blank line.
- Use `goimports` to maintain import order automatically.

## Changelog

| Date | Change | Trigger |
|------|--------|---------|
| 2026-01-15 | Initial creation of style guide | headless-setup |
| 2026-03-02 | Added error wrapping with %w convention | Review feedback on feature/payment-errors |
| 2026-04-10 | Added context-as-first-param rule | IMP-2 from consolidation of feature/db-layer |
