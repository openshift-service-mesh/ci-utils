---
base_branch: main
languages: [go, typescript]
key_paths: ["handlers/", "models/", "frontend/src/"]
skip_phases: []
---
This project is a full-stack payment platform with a Go backend and a React/TypeScript frontend.
The backend exposes a REST API using gin and persists data in PostgreSQL via direct sql queries.
The frontend is a Create React App application that communicates with the backend via axios.
Database schema changes are managed through sequential SQL migration files in migrations/.
Both the Go backend and the TypeScript frontend must be reviewed for any payment-related changes
due to the sensitivity of financial data handling.
