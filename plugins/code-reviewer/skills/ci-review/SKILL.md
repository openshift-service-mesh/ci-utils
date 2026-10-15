---
name: ci-review
description: Run a non-interactive code-reviewer review suitable for CI, including setup fallback and a consolidated report. Use only when the user explicitly requests CI-style automation.
---

# Code reviewer CI mode

Run the review pipeline without waiting for convention-by-convention confirmation. If project reference docs are absent, use `$code-reviewer:headless-setup` to derive them for this run without committing them. Then run `$code-reviewer:triage`, the three phase skills, and `$code-reviewer:consolidation`.

Produce machine-readable findings with file and line locations, finding IDs, severity, evidence, remediation, and a final verdict. Keep generated setup artifacts ephemeral unless the user asks to save them. Do not post comments or submit a review automatically: require an explicit user request and confirmation immediately before any external write.
