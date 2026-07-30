---
scribe:
  scan: "not-a-real-sha"
  freshness: 55
  human_input: 0
  completeness: 40
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
  watch_paths: ["internal/search/"]
  stale_flags: []
---

# Search Indexing

> This doc covers the search index build pipeline under `internal/search/`.

## Key Entry Points
- `internal/search/indexer.go`: `BuildIndex` walks the corpus and writes the index

## Patterns & Conventions
Indexing runs as a single-pass batch job; there is no incremental indexing yet.

## Gotchas
`BuildIndex` holds the whole corpus in memory — large corpora need a bigger
worker instance.

## Dependencies & Context
No external dependencies beyond the standard library at this time.

## Links
No related topics yet.
