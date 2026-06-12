# Style Guide

This document captures the agreed-upon coding conventions for this repository.
All contributors are expected to follow these guidelines; CI enforces many of them automatically.

## General Principles

- Prefer clarity over brevity. Code is read far more often than it is written.
- A function should do one thing and do it well.
- Avoid global mutable state; pass dependencies explicitly.

## Go Conventions

### Naming

| Entity | Style | Example |
|---|---|---|
| Package | lowercase, no underscores | `handlers`, `models` |
| Exported type | PascalCase | `UserHandler` |
| Unexported variable | camelCase | `nextID` |
| Constant | ALL_CAPS only for true constants shared across packages | `MaxRetries` (prefer PascalCase) |
| Test function | `Test<Subject>_<Condition>` | `TestGetUser_NotFound` |

### Error Handling

- Always check returned errors; never use `_` to discard them silently.
- Wrap errors with `fmt.Errorf("context: %w", err)` to preserve the chain.
- Return early on error rather than nesting success paths.

### Comments

- Every exported function, type, and constant must have a GoDoc comment.
- Comments should describe *why*, not *what* — the code itself shows what.
- Use full sentences starting with the name of the thing being described.

### Testing

- Use table-driven tests with `t.Run` for parallel subtests.
- Prefer the standard `testing` package; avoid adding testify unless the team has agreed.
- Test file names must end in `_test.go` and live in the same package as the code under test.

## Formatting

- Run `gofmt` (or `goimports`) before every commit; CI will reject unformatted code.
- Line length is not enforced by tooling, but keep lines under 120 characters where practical.

## Imports

Order import blocks as follows (separated by blank lines):

1. Standard library
2. Third-party packages
3. Internal packages

```go
import (
    "context"
    "net/http"

    "github.com/gin-gonic/gin"

    "example.com/userservice/models"
)
```
