---
scribe:
  scan: "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678"
  freshness: 100
  human_input: 0
  completeness: 80
  inferred_sections:
    - id: key-entry-points
      heading: "## Key Entry Points"
    - id: patterns--conventions
      heading: "## Patterns & Conventions"
  watch_paths: ["deploy/", "Makefile"]
  stale_flags: []
---

# Build & Deploy

> OrbitalCacheWarmer note: this file already exists from a prior draft run.
> scribe-discover must refuse to overwrite it and report the collision back
> to the orchestrator rather than silently replacing this content.

## Key Entry Points
- `Makefile`: defines `build`, `test`, and `deploy` targets
- `deploy/pipeline.yaml`: CI pipeline definition

## Patterns & Conventions
Deploys go through the `deploy` target only; direct `docker push` is not used.
