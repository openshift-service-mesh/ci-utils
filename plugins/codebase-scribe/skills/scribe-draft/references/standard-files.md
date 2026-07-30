# Standard Files (reference)

Loaded from `skills/scribe-draft/SKILL.md` § Standard Files. Step letters (A-D) are canonical — other files reference them. The command file's Definitions (Option-count rule) apply here.


After all topics are processed and STATUS.md is regenerated — once per draft invocation, not per topic — check the repo's standard files.

## Step A: Classify each standard file

For `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CLAUDE.md`, `GEMINI.md` at the repo root (AGENTS.md is the orchestrator's — skip):

**README / CONTRIBUTING / ARCHITECTURE:** **Missing** — doesn't exist. **Thin** — under 30 lines, OR passes the threshold but has no project-specific detail (no commands, links, or named components — only a title, generic prose, or placeholder text). **Substantive** — ≥30 lines AND at least one concrete project-specific signal. Substantive → skip entirely, no prompt.

**CLAUDE.md / GEMINI.md:** **Missing** — doesn't exist. **Thin** — no reference to `AGENTS.md`. **Substantive** — references `AGENTS.md` (the redirect works) → skip entirely.

## Step B: Ask which missing/thin files to generate

Apply the Option-count rule over the qualifying files, in the order README → CONTRIBUTING → ARCHITECTURE → CLAUDE → GEMINI (0 qualify: skip B and C; 5 qualify: split 3+2). Each option's description: `"<filename> is [missing / thin, ~N lines]. I'll draft content based on the codebase and context already loaded."` Unselected files are left as-is.

## Step C: Generate each selected file

Use only context already in scope — source files read during drafting, AGENTS.md, build files from Phase 0, `.claims.yml`. Do **not** read additional source files. **Orphan mode:** AGENTS.md doesn't exist yet (Step 12 creates it later) — the README and ARCHITECTURE generators fall back to the repo README for project identity.

---

**README.md** (30–80 lines):

```markdown
# <Project Name>

<1-3 sentence description pulled from AGENTS.md or existing README.>

## Quick Start

<Minimal build/run commands from build files already read.>

## Documentation

<Links to existing topic files in docs_dir, one-line description each —
use each topic's blockquote TL;DR.>

- [AGENTS.md](AGENTS.md) — quick reference hub for commands and architecture overview

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
```

If no build files were read, note "See Makefile / package.json for build commands."

---

**CONTRIBUTING.md** (40–80 lines):

```markdown
# Contributing

## Development Setup

<Steps derived from build files already read.>

## Running Tests

<Test commands from Makefile, package.json, etc.>

## Submitting Changes

1. Fork the repo and create a branch from `main`.
2. Make your changes with tests where applicable.
3. Run tests and ensure they pass.
4. Open a pull request with a clear description of what changed and why.

## Code Style

<Linters/formatters whose config files were visible during source reading.>
```

---

**ARCHITECTURE.md** (< 40 lines) — a **thin navigation hub**, never prose content; all real detail lives in docs_dir:

```markdown
# Architecture

> This file is a navigation index. For detailed documentation, follow the links below.

## Documentation Index

- [<Topic Title>](<docs_dir>/<name>.md) — <TL;DR blockquote from the topic file>

## Quick Reference

See [AGENTS.md](AGENTS.md) for commands, build instructions, and a directory overview.
```

List topics with architectural concerns (architecture, patterns, data model, API surface, core logic); skip purely operational ones. Stub topics: use the description instead of the TL;DR. No topics yet: placeholder links, valid after drafting.

---

**CLAUDE.md** (4–6 lines, intentionally minimal — AGENTS.md is the source of truth):

```markdown
# Claude Code Instructions

See [AGENTS.md](AGENTS.md) for project identity, architecture overview, build commands, and conventions.

For detailed topic documentation, see [<docs_dir>/](<docs_dir>/).
```

**GEMINI.md:** identical, titled `# Gemini Instructions`.

## Step D: Record outcome

Note which files were created, updated, or skipped — reported in the orchestrator's Step 13 summary.
