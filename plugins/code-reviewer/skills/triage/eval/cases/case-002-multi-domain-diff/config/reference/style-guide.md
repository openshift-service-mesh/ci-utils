# Style Guide (Go + TypeScript)

## Go Backend
- Handler functions must validate input before calling services.
- Map domain errors to HTTP status codes explicitly; never leak internal error text.
- Financial amounts must be stored and transmitted as integers (cents), never floats.

## TypeScript / React
- Components must be typed with explicit `Props` interfaces; avoid `any`.
- Use `async/await` for async operations; handle errors in try/catch.
- Loading and error states must be represented in component state and rendered.
- Do not inline API base URLs; use environment variables or a central config.

## SQL Migrations
- Migrations must be idempotent: use `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`.
- Include a comment header with migration number and date.
- Add indexes for all foreign keys and frequently filtered columns.
