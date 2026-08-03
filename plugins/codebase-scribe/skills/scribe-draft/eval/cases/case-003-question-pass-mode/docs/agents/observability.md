---
scribe:
  scan: "9999999fff8888eee7777ddd6666ccc5555bbb0"
  freshness: 45
  human_input: 0
  completeness: 55
  inferred_sections:
    - id: key-entry-points
      heading: "## Key Entry Points"
    - id: patterns--conventions
      heading: "## Patterns & Conventions"
    - id: gotchas
      heading: "## Gotchas"
    - id: dependencies--context
      heading: "## Dependencies & Context"
    - id: links
      heading: "## Links"
  human_sections: []
  decisions: []
  question_passes: 0
  watch_paths: ["internal/metrics/"]
  stale_flags:
    - id: patterns--conventions
      heading: "## Patterns & Conventions"
      flagged_at_sha: "1111111aaa2222bbb3333ccc4444ddd5555eee6"
      reason: "semantic"
      detail: "Registry wiring may have changed since this section was written."
---

# Observability

> This doc covers metrics collection under `internal/metrics/`. For log
> aggregation, see the platform runbook (not part of this repo's docs).

## Key Entry Points
- `internal/metrics/exporter.go`: hand-rolled Prometheus exporter wrapping `promhttp`
- `internal/metrics/collector.go`: registers all custom collectors at startup

## Patterns & Conventions
All custom metrics are registered through a single `Registry` instance in
`collector.go` rather than using `prometheus.DefaultRegisterer` directly.

## Gotchas
Metric names must be prefixed with `svc_` or the exporter's naming linter
rejects registration at startup.

## Dependencies & Context
The exporter wraps `promhttp.Handler` in a custom `exporter.go` instead of
mounting it directly on the mux.

## Links
- [backend-architecture.md](backend-architecture.md) — the HTTP layer this exporter is mounted on
