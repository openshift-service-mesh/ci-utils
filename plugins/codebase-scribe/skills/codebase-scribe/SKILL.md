---
name: codebase-scribe
description: Generate, enrich, or maintain AGENTS.md and topic documentation for a codebase. Use for codebase documentation, architecture notes, documentation drift, or SME-directed enrichment.
---

# Codebase scribe

Run the codebase-scribe workflow. Detect whether the repository needs seed, draft, or maintain mode, then use the focused skills `$codebase-scribe:scribe-discover`, `$codebase-scribe:scribe-draft`, `$codebase-scribe:scribe-maintain`, and `$codebase-scribe:scribe-review` as appropriate.

Accept optional context or a `focus:` request from the user. Read source files before making claims, preserve progressive disclosure, and keep generated documentation grounded in evidence. Review every proposed documentation change with `$codebase-scribe:scribe-review` before finalizing it. Ask before committing changes or deleting existing documentation.

The legacy command workflow is documented in `commands/codebase-scribe.md`; translate its `/codebase-scribe` examples into this skill and use Codex file and shell tools.
