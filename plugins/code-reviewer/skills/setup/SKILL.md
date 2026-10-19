---
name: setup
description: Onboard a repository for code-reviewer by discovering conventions and creating project reference docs. Use before the first review or when conventions have changed.
---

# Code reviewer setup

Use this skill when the user asks to set up, initialize, or refresh the code-reviewer workflow.

1. Check for `.code-reviewer/reference/` and `.code-reviewer/config.md`. Also recognize the legacy Claude location `.claude/code-reviewer/`. If setup already exists, ask whether to refresh it or start fresh before changing anything.
2. Inspect the repository's instructions, contributing docs, formatter and linter configuration, build files, CI configuration, representative source files, and tests. Do not invent conventions that are not supported by repository evidence.
3. Present proposed conventions to the user for confirmation, grouped into style, testing, security, and API guidance. Skip categories that do not apply.
4. After confirmation, create or update `.code-reviewer/reference/` and `.code-reviewer/config.md`. Preserve existing changelogs during refreshes. Prefer the Codex path; do not move or delete legacy `.claude` files without explicit approval.
5. Ask whether the generated files should be committed or ignored. Never commit on the user's behalf unless requested.

The detailed discovery and reference-document format are in `commands/setup.md` in this plugin. Adapt its Claude-specific `/code-reviewer:*` examples to Codex `$code-reviewer:*` skills and use normal Codex file and shell tools.
