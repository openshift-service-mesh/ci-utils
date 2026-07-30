---
scribe:
  scan: null
  freshness: 88
  human_input: 15
  completeness: 75
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: media-handling
      heading: "## Media Handling"
    - id: export
      heading: "## Export"
    - id: links
      heading: "## Links"
  human_sections: []
  decisions: []
  watch_paths: ["internal/profile/"]
  stale_flags: []
---

# User Profiles

> This doc covers profile media and data export under `internal/profile/`.

## Overview

Profiles hold display data (avatar, bio) plus export/erasure hooks for data
requests.

## Media Handling

`UploadAvatar` in `internal/profile/avatar_upload.go` validates and stores
the uploaded image, delegating each of the three thumbnail sizes to
`ResizeThumbnail` in `internal/profile/thumbnail/resize.go`.

## Export

`ExportProfile` in `internal/profile/legacy_export.go` produces a JSON dump
of a user's profile data for data-portability requests, serialized by
`FormatExport` in `internal/profile/export_schema.go`.

## Links
No related topics yet.
