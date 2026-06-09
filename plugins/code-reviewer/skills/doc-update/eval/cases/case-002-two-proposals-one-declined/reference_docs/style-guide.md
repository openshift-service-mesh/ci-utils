---
format_version: 1
---
## Conventions

### Naming

- Packages use lowercase single-word names; avoid underscores.
- Exported types and functions use PascalCase; unexported identifiers use camelCase.
- Acronyms are fully uppercase: `HTTP`, `URL`, `ID`.

### Formatting & Style

- All code is formatted with `gofmt`. Indentation uses tabs, never spaces.
- Line length soft limit is 120 characters.
- Comments on exported identifiers begin with the identifier name.

### Error Handling

- Errors are wrapped with `fmt.Errorf("...: %w", err)` to preserve the chain.
- Sentinel errors at package level use the `ErrXxx` pattern.

## Changelog

| Date | Change | Trigger |
|------|--------|---------|
| 2026-01-15 | Initial creation | headless-setup |
