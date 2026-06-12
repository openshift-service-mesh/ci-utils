# Style Guide (Go)

## Error Handling
- Always check returned errors; never discard with `_` in production paths.
- Wrap errors with context: `fmt.Errorf("doing X: %w", err)`.
- Return early on errors; avoid deeply nested happy-path logic.

## HTTP Handlers
- Use `gin.H{"error": "..."}` for JSON error responses.
- Map domain errors (e.g., `ErrNotFound`) to appropriate HTTP status codes.
- Validate all input before calling service layer.

## Naming
- Exported handler functions: `VerbNoun` (e.g., `GetUser`, `CreateUser`).
- Keep handler bodies thin; business logic belongs in services.

## Comments
- Exported functions must have a doc comment starting with the function name.
- Internal helpers do not require comments unless non-obvious.
