# codebase-scribe

A plugin that generates, enriches, and maintains agentic development documentation for any codebase. Ships for both **Claude Code** and **Cursor**; Cursor compatibility is based on Cursor's published documentation, not on testing against a running Cursor instance (see [Known Limitations in Cursor](#known-limitations-in-cursor)).

## What It Does

Codebase Scribe produces structured documentation that helps AI agents (and humans) understand your codebase:

- **AGENTS.md** — A hub file at your repo root with project identity, quick reference, architecture overview, and conventions
- **Topic files** (`docs/agents/`) — Deep-dive documents organized by area: architecture, patterns, testing, build/deploy, and more
- **STATUS.md** — A machine-generated health dashboard showing documentation freshness, human input, and completeness scores

The plugin adapts to any codebase — it discovers your repo's structure first, then proposes a documentation layout tailored to what it finds.

## How It Works

The plugin operates in three modes, automatically selected based on documentation state:

| Mode | When | What happens |
|------|------|-------------|
| **Seed** | No docs exist | Scans repo structure, proposes topics, creates documentation stubs |
| **Draft** | Stubs or thin docs exist | Reads source code, fills stubs with content, extracts claims |
| **Maintain** | Docs are current | Detects drift between code and docs, auto-fixes broken references, flags changes for review |

After each Draft or Maintain run, a **Review gate** automatically verifies documentation accuracy using a separate review agent (see [Documentation Review](#documentation-review) below).

## Installation

This plugin is distributed as part of the [ci-utils](https://github.com/openshift-service-mesh/ci-utils) marketplace.

### Claude Code

```
/plugin marketplace add openshift-service-mesh/ci-utils
/plugin install codebase-scribe@ci-utils
/reload-plugins
```

### Cursor (local)

```bash
ln -s /path/to/ci-utils/plugins/codebase-scribe ~/.cursor/plugins/local/codebase-scribe
```

Then restart Cursor or run **Developer: Reload Window**. If you previously symlinked to `~/.cursor/plugins/codebase-scribe` (without `local/`), remove that link and recreate it at the path above.

### Verify installation

Run `/plugin` in Claude Code or check the plugins panel in Cursor to confirm the plugin is loaded.

## Requirements

- **git** — the drift model is built on it; under the default `main-only` branching strategy the plugin refuses to run outside a git repository.
- **bash** — the validation hook and maintainer scripts are bash (on Windows: Git Bash, as shipped with Git for Windows).
- **python3** (or `python` / `py -3` — the plugin discovers whichever exists) — `scripts/scribe-lib.py` implements the plugin's deterministic computations (section parsing, tier and score calculation, scan validation, review classification) and the skills call it on every run. Without python3 the skills fall back to computing the same results manually from the script's documented definitions — workable, but slower and less reliable.
- **PyYAML** (`pip install pyyaml`) — powers scribe-lib's state-writer verbs, the enforced path for every frontmatter and `.claims.yml` write (stamping, section crediting, decision lifecycle, claims extraction). Without it those verbs refuse with a clear message and the skills fall back to performing the same writes manually — the pre-1.4 behavior, measurably less reliable on multi-step sequences.
- **jq or python3** — the validation hook parses its hook payload with jq, falling back to python; with neither available the hook is a silent no-op and topic files are not structure-checked on write (see the hook note under [Branching Strategy](#branching-strategy)).

## Quick Start

1. Navigate to any git repository
2. Run `/codebase-scribe` — scans your repo and proposes documentation topics
3. Approve the proposed topics — creates stub files and an AGENTS.md hub
4. Run `/codebase-scribe` again — reads source code and fills stubs with content

For large repos (5+ topics), drafting happens in batches of 3 topics per run to ensure quality. Just keep running `/codebase-scribe` until all topics are drafted — the plugin tracks progress and picks up where it left off.

Each subsequent run detects what's changed and updates accordingly. The plugin progresses through phases automatically: seed → draft → maintain.

## Tribal Knowledge Capture

The plugin captures design decisions and architectural rationale alongside auto-generated documentation:

**During regular drafting**, the plugin identifies deliberate-but-unexplained patterns in your code and asks one question per topic — "Why this approach?" Answers are woven into the documentation and tracked as human-sourced knowledge.

**During focus mode** (`/codebase-scribe focus:"area"`), the plugin asks 3-5 deeper observation-driven questions about the specific area. This is where the most valuable tribal knowledge gets captured — design constraints, rejected alternatives, known fragilities.

**Over time**, the Human Input score in STATUS.md tracks how much of each topic has human knowledge behind it, increasing naturally as you engage with the documentation.

Design decisions are tracked as `decisions:` entries in each topic's frontmatter, with provenance — the maintain mode detects when code changes might invalidate a recorded decision and flags it for your review on the next run.

## Documentation Review

Documentation changes are routed through a quality gate powered by a dedicated review agent — `agents/scribe-review.md`, dispatched via the Agent tool as `codebase-scribe:scribe-review` — which runs in its own fresh context, separate from the orchestrating command's session.

**Automatic review** — After a drafting or maintenance batch finishes, `/codebase-scribe` classifies what changed in each topic, checks the classification against the configured trigger list (by default: a new draft, a major rewrite, a claim change, a section change, or a large diff; otherwise offering an opt-in prompt), then dispatches the review agent with the topic's content, its source files, and its recorded claims. The agent checks file path existence, function name accuracy, behavioral claims, and coverage gaps.

**Two-pass verification:**
- **Mechanical pass** — High-confidence filesystem checks (does this path exist? does this function exist?)
- **Semantic pass** — Lower-confidence content verification (does the doc accurately describe what the code does?)

**No pinned model** — The agent's frontmatter has no `model:` key. Per `docs/contributing.md`'s plugin checklist, `model` is optional for plugins shipping to multiple hosts; leaving it unset avoids tying the review agent to a single host's model catalog.

**Human gate** — For large changes (new drafts, major rewrites), the review report is presented for human approval before finalizing.

**Rework loop** — If the review returns `REWORK_NEEDED`, the drafting skill automatically corrects the cited findings and re-submits for a scoped re-review (hard cap: 2 iterations). A persistent or new critical finding, or a second failed rework, escalates straight to the human gate instead of looping further.

Review is enabled by default. Disable with `review.enabled: false` in `.scribe.yml`.

## Commands

### `/codebase-scribe`

Auto-detect mode. Reads existing documentation state and determines whether to seed, draft, or maintain.

### `/codebase-scribe "context"`

Provide context that biases which topics get attention.

```
/codebase-scribe "we just migrated from Webpack to Vite"
/codebase-scribe "the auth system was rewritten last sprint"
```

### `/codebase-scribe focus:"description"`

SME-directed documentation. Focus on a specific area you know well. The plugin asks deeper design-decision questions instead of basic "what does this do" questions.

```
/codebase-scribe focus:"the authentication and authorization system, including OAuth flows and RBAC"
/codebase-scribe focus:"cache layer and its integration with business services"
/codebase-scribe focus:"CI/CD pipeline, especially the multi-arch build process"
```

Multiple areas: `/codebase-scribe focus:"auth system, cache layer"` — processed sequentially with independent file budgets.

## Output Structure

```
your-repo/
  AGENTS.md                    # Hub (scribe-managed after migration prompt, or human-managed)
  docs/agents/
    STATUS.md                  # Health dashboard (auto-generated each run)
    architecture.md            # Topic file with frontmatter
    patterns.md
    testing.md
    build-deploy.md
    .claims.yml                # Cross-topic consistency cache (gitignored, regenerable)
  .scribe/
    session.json               # Session state (gitignored)
```

### Git Integration

The plugin seeds your `.gitignore` for you — every run idempotently ensures `.gitignore` contains `.scribe/` and `<docs_dir>/.claims.yml` (skipping the claims entry if `docs_dir` is already under an ignored path), creating `.gitignore` if it doesn't exist. Any modification is reported in the run summary with an instruction to commit it — nothing is added without you seeing it.

```
.scribe/                    # Session state (local only)
docs/agents/.claims.yml     # Cross-topic consistency cache (regenerable)
```

The topic files, STATUS.md, and AGENTS.md should be committed — they're the documentation output.

### Three-Score System

Each topic file tracks three independent quality scores:

| Score | What it measures |
|-------|-----------------|
| **Freshness** | Has the code changed since docs were last updated? |
| **Human Input** | How much of this topic has human knowledge behind it? |
| **Completeness** | Does the doc cover all the relevant code areas? |

Freshly auto-generated content shows: 100% fresh, 0% human, N% complete — no false confidence.

### Topic File Structure

Every topic file needs one thing: a **TL;DR** blockquote right after the `#` heading, for relevance routing — is this the right doc for your task? That is the whole requirement for a topic that already has content, and it is what the validation hook enforces on one.

Newly drafted stubs get a starting skeleton, organized by agent intent rather than by depth:

- **Key Entry Points** — Files, commands, configs to orient yourself
- **Patterns & Conventions** — What to follow when writing new code
- **Gotchas** — What will bite you if you don't know
- **Dependencies & Context** — Deeper understanding, design rationale
- **Links** — Cross-references to other topics and external docs

Those five are a floor and a ceiling for a stub's first draft. Once a topic is no longer a stub it keeps whatever headings it has grown — your own domain-specific ones included. The scribe rewrites those sections in place rather than forcing the skeleton back on, and neither the hook nor a maintain pass requires the five names on a mature topic. Do not "correct" a mature topic back to this list.

## Example Output

### AGENTS.md hub

```markdown
# My Project

REST API service for managing widgets with PostgreSQL storage.

## Quick Reference

| Action | Command |
|--------|---------|
| Build | `go build ./...` |
| Test | `make test` |
| Run locally | `make run` |

## Architecture at a Glance

├── cmd/server/       → Entry point, CLI
├── internal/api/     → HTTP handlers, routing
├── internal/store/   → PostgreSQL data access
├── internal/models/  → Domain types
└── deploy/           → Dockerfile, Helm chart

## Documentation

- [Backend Architecture](docs/agents/backend-architecture.md) — Server, routing, handlers, data access
- [Deployment & Operations](docs/agents/deployment-ops.md) — Container builds, Helm, CI/CD
```

### Topic file

`scan` below is illustrative — an 8-character placeholder shaped like a git SHA. The real value is a commit hash from your repo's history; a made-up one like this is shape-valid but would fail resolution against your actual commits.

```markdown
---
scribe:
  scan: "a1b2c3d4"
  freshness: 100
  human_input: 20
  completeness: 85
  watch_paths: ["cmd/", "internal/api/", "internal/store/"]
  human_sections:
    - dependencies--context
  decisions:
    - id: backend-architecture-3
      type: technology
      claim: "chi/v5 chosen over gorilla/mux for middleware chaining"
      context: "gorilla/mux was evaluated but chi's middleware composition fit the handler pattern better"
      recorded: "2026-04-12"
      source: "internal/api/router.go"
      status: active
---

# Backend Architecture

> Go backend: HTTP server, routing, handlers, and PostgreSQL data access.
> For deployment and CI/CD, see [deployment-ops.md](deployment-ops.md).

## Key Entry Points

- `cmd/server/main.go`: Entry point — config loading, server startup
- `internal/api/router.go`: All routes registered via `chi.NewRouter()`
- `internal/store/postgres.go`: Database connection pool and migrations
- `make run`: Start with hot-reload via air

## Patterns & Conventions

Handlers follow a consistent pattern: extract params, call store, return JSON.
Dependencies are injected via the `Server` struct created in `main.go`.

## Gotchas

- Database migrations run automatically on startup — no separate step needed
- The health endpoint (`/healthz`) bypasses auth middleware
- `PGSSL=disable` is required for local development

## Dependencies & Context

- **chi/v5**: HTTP router (chosen over gorilla/mux for middleware chaining)
- **pgx/v5**: PostgreSQL driver (pure Go, no CGO)
- **zerolog**: Structured logging

## Links

- [deployment-ops.md](deployment-ops.md) — How to deploy
- [internal/api/router.go](../../internal/api/router.go) — Route definitions
```

### STATUS.md

```markdown
# Documentation Status

| Topic | Fresh | Human | Complete | Claims | File |
|-------|-------|-------|----------|--------|------|
| Backend Architecture | 100% | 20% | 85% | 12 | backend-architecture.md |
| Deployment & Operations | 100% | 0% | 100% | 8 | deployment-ops.md |
```

#### Ownership and the scribe marker

When the scribe creates AGENTS.md, it includes an invisible HTML comment marker (`<!-- scribe:managed -->`) that tells future runs the file is scribe-owned. On subsequent runs, the scribe silently appends new topic links.

If the scribe finds an AGENTS.md without this marker (i.e., a human-authored file), it prompts you to choose: replace it with a scribe hub (backing up the original), append topic links to it, or leave it alone.

**For third-party tools:** Include `<!-- scribe:managed -->` in generated AGENTS.md files for scribe compatibility, or omit it to trigger the ownership prompt. Users can also manually add the marker to opt in to scribe management, or remove it from a scribe-managed file to reclaim manual control.

## Configuration

Create a `.scribe.yml` at your repo root to customize behavior. All fields are optional:

```yaml
# Cost controls
budgets:
  files_per_topic: 30          # Max source files read per topic
  files_per_session: 150       # Soft limit — warns, doesn't block
  topics_per_run: 3            # Max topics drafted per invocation (prevents context exhaustion)

# Content guidelines
content:
  split_threshold: 500         # Auto-propose split above this
  hard_split: 800              # Not read from config yet — the 800-line threshold above which
                                # draft proposes an overview + deep-dive split is hardcoded in
                                # skills/scribe-draft/SKILL.md; this key currently has no effect

# Drift detection
drift:
  sensitivity: medium          # low | medium | high
  stale_commit_threshold: 50   # Commits before demoting stale flags
  decision_lines_threshold: 5  # Lines changed before flagging decision drift

# Review system
review:
  enabled: true                  # Enable/disable review after draft and maintain
  diff_threshold: 20             # Lines changed to trigger review via safety net
  auto_trigger:                  # Change types that always trigger review
    - new_draft
    - major_rewrite
    - claim_change
    - section_change
    - large_diff

# Branching
branching_strategy: main-only  # main-only | branch-local | branch-commit
default_branch: auto-detect    # main-only gates compare against this. The literal `auto-detect` shown here
                                # means UNSET, exactly like omitting the key — Step 0's detection ladder
                                # falls through to `origin/HEAD`, then origin/main, then origin/master.
                                # Replace it with a real branch name only to pin one explicitly.

# Questioning
questions: true                 # false suppresses draft's Critical Gap Check, Design Decision Prompt, and
                                 # Observation-Driven Questioning, the Wrap-Up Pass, and the question-pass
                                 # route; Standard Files prompts, split proposals, ownership prompts,
                                 # and Decision Drift Resolution still fire.
                                 # (Human-Input pinning note also carried in commands/codebase-scribe.md's
                                 # Error Handling #8 — content-equivalent adaptations for their
                                 # audiences, not byte-identical copies; keep them in sync in substance.)
                                 # Human-Input pinning: no §5/§6/§7 or Wrap-Up path writes to human_sections,
                                 # so no questioning path can raise human_input while the setting is on —
                                 # topics that already earned human credit keep it, and Decision Drift
                                 # Resolution remains the one path that can add credit. Expected, not a bug;
                                 # it will not classify topics unverified.

# AGENTS.md hub
agents_md_policy: auto          # auto | none | manual — who owns the AGENTS.md hub.
                                 # `auto` (default): the scribe creates the hub if it is
                                 # missing and appends links for new topic files.
                                 # `none`: Step 12 is skipped entirely — no creation, no
                                 # modification, no prompts, no reminders.
                                 # `manual`: AGENTS.md is never modified; a run only prints a
                                 # reminder when topic files exist that the hub does not link.
                                 # The plugin writes this key itself: `manual` when you pick
                                 # "Leave it alone" at the ownership prompt, and `none` or
                                 # `auto` when you answer the deleted-hub prompt.

# Output location
output:
  docs_dir: "docs/agents"
  agents_md: "AGENTS.md"       # Read for routing but not yet honored by the hub writes —
                                # Step 1's route table consults it to pick seed / migration /
                                # orphan / normal mode, while Step 12 writes the literal
                                # `AGENTS.md` at every write site. A non-default value
                                # therefore changes which mode a run takes but not which file
                                # gets written; recorded as a post-release follow-up
```

## Drift Detection

The maintain mode detects two types of drift:

**Mechanical drift** (auto-fixed): Renamed files, renamed functions, changed commands. The plugin fixes these automatically and tells you what changed.

**Semantic drift** (handled by review agent): Architecture changes, deprecated patterns, deleted components. The maintain mode flags major drift, and the review agent performs thorough verification against source code.

Drift attention is proportional to code churn — stable code gets zero prompts.

## Branching Strategy

| Strategy | Behavior |
|----------|----------|
| `main-only` (default) | Run `/codebase-scribe` on main only. Feature branches inherit docs. After merge, next run detects drift. |
| `branch-local` | Run on branches, docs go to `.scribe/branch-docs/` (gitignored). Personal aid, not shared. |
| `branch-commit` | Run on branches, commit changes. Handles merge conflicts on frontmatter. |

Under `main-only` (the default), running the plugin outside a git repository — or with no git binary available — refuses rather than degrading: the plugin's documented scope is git repositories, and its drift model needs one. `branch-local` and `branch-commit` proceed in that case with git-dependent features skipped.

**Hook gap:** the `PostToolUse` validation hook (`hooks/doc-validate.sh`) resolves `docs_dir` from `.scribe.yml`'s `output.docs_dir` only — it does not know about the `branch-local` strategy's `.scribe/branch-docs/` override, so under `branch-local` the hook validates against the configured `docs_dir` path, not the branch-local output location. This is a known gap, not planned to be fixed. (Test-only: the hook extracts `.tool_input.file_path` with `jq`, falling back to python; with neither parser available the hook is a silent no-op — validation requires one of the two. `SCRIBE_NO_JQ=1` forces the python path and `SCRIBE_NO_PYTHON=1` disables python; neither variable is meant for normal use. `hooks/test-doc-validate.sh` runs its case list under both parser modes and additionally asserts the no-parser no-op.)

## Resumability

Sessions can be interrupted at any point. The plugin tracks progress per-topic and resumes where it left off. Long-running workflows decompose naturally into chunks across multiple sessions.

## File Skipping

The plugin skips vendored dependencies, lock files, and known boilerplate generator output (protoc, swagger-codegen, etc.). It does NOT skip files generated by AI coding agents — those are real application code.

## Known Limitations in Cursor

This plugin ships a `.cursor-plugin/plugin.json` manifest alongside the Claude Code one (see [Installation](#installation)). This audit exercised nothing against a running Cursor instance — the table below is documentary: each row traces to Cursor's own published documentation, or, where marked, to community reports, not to behavior this audit observed. Nothing here should be read as confirmed working, or confirmed broken, in Cursor — only as what Cursor's documentation (or the community reports cited) does or doesn't say.

| Dependency | Status in Cursor |
|---|---|
| Structured question prompts (`AskUserQuestion`, ~12 call sites across the command, the drafting skill, and their reference files, 3 of them multi-select — Step 2c topic approval, Step 6c focus plan, and the drafting skill's Standard Files prompt in `references/standard-files.md`) | **Documented as different.** Cursor documents an interactive Q&A tool with a different contract from this one. Its 2.4 changelog describes "the interactive Q&A tool used by agents in Plan and Debug mode" and states that it "now lets agents ask clarifying questions in any conversation", adding that "you can also build custom subagents and skills that use this tool by instructing them to 'use the ask question tool'". Multi-select appears nowhere in that documentation; the only statement of it is a community report — a Cursor team member wrote on 4 January 2026 that "Multi-select already exists, but only when the model detects the question as multi-choice", i.e. inferred from the question rather than requested by the caller. What remains undocumented is this plugin's own shape: caller-supplied labeled options, a multi-select mode the caller asks for, and the 2-to-4-option bound the command's Step 2c/6c splitting rules are built around. Whether an instruction naming `AskUserQuestion` — rather than the phrasing Cursor's changelog documents — reaches that tool from a plugin's bundled skills and agents is not addressed either way. |
| Plugin-bundled subagent dispatch (`agents/scribe-review.md`, dispatched as `codebase-scribe:scribe-review`) | **Not documented.** Cursor's plugin format auto-discovers an `agents/` directory the same way this plugin ships it, and Cursor's Agent has an equivalent Task tool for subagent delegation, including sending multiple Task tool calls in one message to run subagents in parallel. Cursor documents three ways a subagent gets invoked — slash syntax (`/agent-name`), natural language, and automatic delegation based on task complexity and the subagent's description — but none of the three is a namespaced `plugin:agent` identifier passed as a structured parameter. Whether a Cursor session maps this plugin's dispatch instructions onto its own Task tool correctly is not addressed either way. |
| `PostToolUse` hook (`hooks/hooks.json`, matcher `Write\|Edit\|MultiEdit`) | **Not documented.** Cursor auto-discovers a plugin's `hooks/hooks.json` — this plugin's layout matches Cursor's own example plugins exactly — and Cursor documents a Claude Code compatibility layer that maps `PostToolUse` to its own `postToolUse`. That documented mapping is scoped to `.claude/settings.json` files and requires enabling "Include third-party Plugins, Skills, and other configs" in Cursor's settings; whether it also covers a plugin's own bundled hooks file is not documented. Cursor's documented tool-name mapping for this compatibility layer has no entry for `MultiEdit` — only `Write` and `Edit` are listed. |
| `$CLAUDE_PROJECT_DIR` (used by `doc-validate.sh` to locate `.scribe.yml`) | **Documented as supported.** Cursor's hooks documentation lists `CLAUDE_PROJECT_DIR` as a supported alias environment variable, kept for Claude Code compatibility — available to hooks that load, which the row above marks as not documented either way. |
| Skills (`skills/*/SKILL.md`) | **Documented as supported.** Cursor's plugin format documents Skills as a first-class, auto-discovered component, invocable via "Agent Decides" or manually with `/skill-name`. |
| `bash` availability for hook scripts, specifically on Windows | **Not documented.** Community forum threads report hook failures on Windows with a Git Bash default shell — hook metadata decoding written for PowerShell, and commands hanging indefinitely. Cursor's documentation does not address this. |

Where Cursor's documentation is silent on a specific interaction — true for most rows above — that silence is reported here as not documented, never as a working feature.

## License

Apache-2.0
