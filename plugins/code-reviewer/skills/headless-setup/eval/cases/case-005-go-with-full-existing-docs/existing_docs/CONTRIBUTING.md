# Contributing to User Service

Thank you for taking the time to contribute! Please read this document carefully before opening a pull request.

## Development Setup

1. Install Go 1.22 or later from https://go.dev/dl.
2. Clone the repository:
   ```bash
   git clone https://github.com/example/userservice.git
   cd userservice
   ```
3. Install dependencies:
   ```bash
   go mod download
   ```
4. Run the test suite to verify your setup:
   ```bash
   go test ./...
   ```

## Branching Strategy

- `main` is the stable branch. Direct pushes are disabled.
- Create feature branches from `main` using the naming convention `<type>/<short-description>`:
  - `feat/add-user-roles`
  - `fix/null-pointer-in-handler`
  - `chore/update-dependencies`

## Pull Request Process

1. Ensure all tests pass (`go test ./...`) and there are no linter errors (`golangci-lint run`).
2. Update the CHANGELOG.md entry for your change.
3. Open a pull request against `main`.
4. Fill in the PR template — a description of the change, motivation, and how to test it.
5. At least one reviewer must approve before merging.
6. Squash-merge is preferred to keep the history clean.

## Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`.

Example:
```
feat(handlers): add pagination support to ListUsers endpoint

Added cursor-based pagination using the `after` query parameter.
Closes #42.
```

## Code Style

See [STYLE_GUIDE.md](./STYLE_GUIDE.md) for detailed coding conventions.
