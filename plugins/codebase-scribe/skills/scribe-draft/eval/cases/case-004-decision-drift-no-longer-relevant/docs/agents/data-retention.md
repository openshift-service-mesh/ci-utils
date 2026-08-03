---
scribe:
  scan: "2222bbbb3333cccc4444dddd5555eeee6666ffff"
  freshness: 80
  human_input: 33
  completeness: 60
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: dependencies--context
      heading: "## Dependencies & Context"
    - id: links
      heading: "## Links"
  human_sections:
    - dependencies--context
  decisions:
    - id: data-retention-3
      type: constraint
      claim: "Retention window is a fixed 90 days for GDPR compliance headroom"
      context: "Legal asked for a fixed, auditable window rather than a per-tenant configurable one, to simplify the compliance story."
      recorded: "2026-03-01"
      source: "internal/retention/policy.go"
      status: active
  question_passes: 0
  watch_paths: ["internal/retention/"]
  stale_flags:
    - id: decision-data-retention-3
      heading: "## Dependencies & Context"
      flagged_at_sha: "3333cccc4444dddd5555eeee6666ffff7777aaaa"
      reason: decision_drift
      detail: >-
        Claim 'Retention window is a fixed 90 days for GDPR compliance
        headroom' (recorded 2026-03-01) may be outdated —
        internal/retention/policy.go changed since it was recorded.
---

# Data Retention

> This doc covers the retention policy under `internal/retention/`.

## Overview

Records are purged by a scheduled job that reads the retention policy and
deletes anything older than the configured window.

## Dependencies & Context

Retention window is a fixed 90 days for GDPR compliance headroom. Legal
asked for a fixed, auditable window rather than a per-tenant configurable
one, to simplify the compliance story.

## Links
- [backend-architecture.md](backend-architecture.md)
