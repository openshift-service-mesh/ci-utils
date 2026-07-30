---
scribe:
  scan: "1111111aaaa2222bbbb3333cccc4444dddd5555"
  freshness: 60
  human_input: 25
  completeness: 70
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: components
      heading: "## Components"
    - id: links
      heading: "## Links"
  human_sections:
    - gotchas
  decisions:
    - id: backend-architecture-2
      type: constraint
      claim: "Route registration is centralized in router.go rather than per-package init()"
      context: "Per-package init() registration made route ordering non-deterministic across builds; centralizing in router.go made the route table auditable in one place."
      recorded: "2026-04-02"
      source: "internal/api/router.go"
      status: active
  question_passes: 0
  watch_paths: ["internal/api/"]
  stale_flags: []
---

# Backend Architecture

> This doc covers the HTTP API layer under `internal/api/`. For the payments
> subsystem, see [payments-integration.md](payments-integration.md).

## Overview

The API layer is a thin HTTP surface over the service's business logic,
built around `net/http` with no external router library.

## Components

- `UserHandler` in `internal/api/user_handler.go` — user CRUD endpoints.
- `router.go` in `internal/api/router.go` — registers every route in one
  place at startup.

## Gotchas

Route registration is centralized in `router.go` rather than per-package
`init()` — per-package registration made route ordering non-deterministic
across builds, so this was deliberately consolidated to keep the route
table auditable in one place.

## Links
- [payments-integration.md](payments-integration.md) — payment processing endpoints
