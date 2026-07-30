---
scribe:
  scan: "4444dddd5555eeee6666ffff7777aaaa8888bbbb"
  freshness: 40
  human_input: 25
  completeness: 50
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: cache-population
      heading: "## Cache Population"
    - id: configuration
      heading: "## Configuration"
    - id: gotchas
      heading: "## Gotchas"
    - id: links
      heading: "## Links"
  human_sections:
    - gotchas
  decisions:
    - id: cache-layer-2
      type: boundary
      claim: "Cache has no RBAC filtering of its own"
      context: "Callers must not assume per-request authorization; anything the service account can list is readable through the cache."
      recorded: "2026-03-15"
      source: "cache/informer_cache.go"
      status: active
  question_passes: 0
  watch_paths: ["cache/"]
  stale_flags: []
---

# Cache Layer

> This doc covers the in-memory Kubernetes object cache under `cache/`.

## Overview

The cache mirrors a subset of cluster objects locally to avoid hammering
the API server on every reconcile loop.

## Cache Population

The cache is populated by informers in `NewKubeCache` in
`cache/kube_cache.go`. Informers watch the relevant object types and push
updates into the cache as they arrive.

## Configuration

The cache's resync interval and object-type allowlist are read from the
`CACHE_CONFIG` environment variable at startup; there is no config file.

## Gotchas

The cache has no RBAC filtering of its own — anything the service account
can list, every caller of the cache can read. Callers must not assume
per-request authorization.

## Links
- [backend-architecture.md](backend-architecture.md)
