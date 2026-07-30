---
scribe:
  scan: "aaaa1111bbbb2222cccc3333dddd4444eeee5555"
  freshness: 70
  human_input: 20
  completeness: 65
  inferred_sections:
    - id: overview
      heading: "## Overview"
    - id: charging
      heading: "## Charging"
    - id: links
      heading: "## Links"
  human_sections: []
  decisions: []
  watch_paths: ["internal/billing/"]
  stale_flags: []
---

# Billing

> This doc covers charge processing under `internal/billing/`.

## Overview

Charges are created synchronously on checkout and reconciled nightly against
the payment provider's ledger.

## Charging

`UploadReceipt` and charge validation live in `internal/billing/legacy_charge.go`.

## Links
No related topics yet.
