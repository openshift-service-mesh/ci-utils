# User Service

A minimal REST API for managing users, secured with JWT authentication.

## Features

- CRUD operations for users
- JWT-based authentication with bcrypt password hashing
- Health check endpoint

## Quick Start

### Prerequisites

- Go 1.22+
- `JWT_SECRET` environment variable set

### Running Locally

```bash
export JWT_SECRET="your-secret-key"
go run ./...
```

The server starts on port `8080` by default. Override with:

```bash
PORT=9090 go run ./...
```

### Running Tests

```bash
go test ./...
```

## API Overview

| Method | Path              | Auth required | Description          |
|--------|-------------------|---------------|----------------------|
| POST   | /auth/login       | No            | Obtain a JWT token   |
| GET    | /api/v1/users/:id | Yes           | Fetch a user by ID   |
| POST   | /api/v1/users     | Yes           | Create a new user    |
| GET    | /healthz          | No            | Health check         |

## Contributing

1. Fork the repository and create a feature branch.
2. Write tests for any new functionality.
3. Open a pull request against `main` with a clear description of the change.
4. Ensure all CI checks pass before requesting a review.
