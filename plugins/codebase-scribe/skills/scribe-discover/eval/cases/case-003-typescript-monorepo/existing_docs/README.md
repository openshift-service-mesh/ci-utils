# User Directory Monorepo

This repository is a TypeScript monorepo managed with npm workspaces. It contains two packages:

- **packages/frontend** — React single-page application that displays and manages users.
- **packages/backend** — Express REST API that serves user data.

## Structure

```
packages/
  frontend/   React app (Vite, React 18)
  backend/    Express API (Node 20)
```

## Getting Started

```bash
npm install          # install all workspace deps
npm run dev:backend  # start backend on :3001
npm run dev:frontend # start frontend on :5173
npm test             # run jest test suites for all packages
```

## Architecture

The frontend proxies `/api/v1/*` requests to the backend during development. In production both artifacts are deployed separately behind a reverse proxy.
