---
format_version: 1
---
## Conventions

### URL Structure

- All API endpoints are versioned under `/api/v1/`.
- Resource collections use lowercase plural nouns: `/api/v1/orders`, `/api/v1/users`.
- Resource instances include the ID as a path parameter: `/api/v1/orders/:id`.
- Nested resources are expressed as sub-paths: `/api/v1/orders/:id/items`.
- Query parameters are used for filtering, sorting, and pagination — never for resource identity.

### Resource IDs

- All resource IDs are UUID v4 strings.
- IDs appear in URLs as `:id` path parameters (never as query parameters for primary resource lookup).
- IDs are generated server-side; clients must not supply IDs for new resources.

### HTTP Methods

- `GET` — retrieve a resource or collection; must be idempotent and side-effect-free.
- `POST` — create a new resource; body contains the resource representation.
- `PUT` — replace a resource fully; body must contain all fields.
- `PATCH` — partial update; body contains only the fields to change (JSON Merge Patch format).
- `DELETE` — remove a resource; returns 204 on success.

### Request & Response Format

- All request and response bodies use `application/json`.
- Field names in JSON use `camelCase` (not snake_case).
- Timestamps are always in RFC 3339 format with UTC timezone: `"2026-01-15T14:22:00Z"`.
- Empty collections are returned as `[]`, never as `null`.
- Partial responses (field selection) are not supported; always return the full resource.

### Pagination

- Collection endpoints support cursor-based pagination via `?cursor=` and `?limit=` parameters.
- Responses include a `meta.nextCursor` field (null when no more pages) and `meta.total`.
- Default page size is 20; maximum is 100. Requests above 100 return a 400.

### Error Responses

- Error responses use a consistent envelope:
  ```json
  {
    "error": {
      "code": "VALIDATION_ERROR",
      "message": "human-readable description",
      "fields": { "fieldName": "field-specific message" }
    }
  }
  ```
- `code` is a SCREAMING_SNAKE_CASE string stable across versions.
- HTTP status codes map to error categories: 400 (client error), 401 (auth), 403 (authz), 404 (not found), 422 (validation), 500 (server error).

### Authentication

- All endpoints except `/api/v1/health` and `/api/v1/docs` require a valid Bearer token.
- Tokens are passed in the `Authorization: Bearer <token>` header.
- Expired tokens return 401; insufficient permissions return 403.

## Changelog

| Date | Change | Trigger |
|------|--------|---------|
| 2026-01-15 | Initial creation | headless-setup |
| 2026-02-08 | Added cursor-based pagination convention | IMP-3 from feature/list-endpoints |
| 2026-03-17 | Added error envelope format | IMP-1 from feature/error-standardization |
| 2026-05-01 | Added JSON Merge Patch note for PATCH | Review feedback on feature/partial-updates |
