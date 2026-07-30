---
scribe:
  scan: null
  freshness: 95
  human_input: 10
  completeness: 60
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: rollout-philosophy
      heading: "## Rollout Philosophy"
    - id: links
      heading: "## Links"
  human_sections: []
  decisions: []
  watch_paths: ["internal/deploy/"]
  stale_flags: []
---

# Deployment Guide

## Overview

Deployments roll out via `internal/deploy/rollout.go`'s `RolloutManager`,
which stages a new version behind a feature gate before promoting it.

## Rollout Philosophy

We believe in careful, incremental change. Every deployment should be
reversible, observable, and boring. Teams are encouraged to think about
failure modes before they ship, not after something breaks in production.
A culture of caution serves everyone better than a culture of speed for
its own sake, and this guide exists to reinforce that value across the
organization regardless of which service is being deployed.

## Links
No related topics yet.
