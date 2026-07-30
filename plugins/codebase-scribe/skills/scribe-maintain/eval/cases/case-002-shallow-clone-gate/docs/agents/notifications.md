---
scribe:
  scan: "bbbb2222cccc3333dddd4444eeee5555ffff6666"
  freshness: 85
  human_input: 0
  completeness: 50
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: links
      heading: "## Links"
  human_sections: []
  decisions: []
  watch_paths: ["internal/notify/"]
  stale_flags: []
---

# Notifications

> This doc covers outbound notification delivery under `internal/notify/`.

## Overview

`Send` dispatches a notification through whichever channel the recipient
prefers, falling back to email if the preferred channel is unavailable.

## Links
No related topics yet.
