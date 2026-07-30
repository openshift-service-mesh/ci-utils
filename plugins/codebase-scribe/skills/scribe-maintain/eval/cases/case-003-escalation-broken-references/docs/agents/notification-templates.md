---
scribe:
  scan: null
  freshness: 90
  human_input: 0
  completeness: 70
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: template-pipeline
      heading: "## Template Pipeline"
    - id: links
      heading: "## Links"
  human_sections: []
  decisions: []
  watch_paths: ["internal/notifytemplates/"]
  stale_flags: []
---

# Notification Templates

> This doc covers template rendering for outbound notifications under
> `internal/notifytemplates/`.

## Overview

Templates are loaded, validated, cached, and rendered as a small pipeline
before a notification is sent.

## Template Pipeline

- `LoadTemplateSet` in `internal/notifytemplates/loader.go` loads the
  template set for a notification type.
- `ValidateTemplate` in `internal/notifytemplates/validate.go` checks
  required placeholders are present before rendering.
- `CacheTemplates` in `internal/notifytemplates/cache.go` caches compiled
  templates in memory to avoid re-parsing on every send.
- `RenderTemplate` in `internal/notifytemplates/render.go` renders the final
  message body.

## Links
No related topics yet.
