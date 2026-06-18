# codebase-scribe

A plugin that generates, enriches, and maintains agentic development documentation for any codebase. Works natively with both **Claude Code** and **Cursor**.

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
ln -s /path/to/ci-utils/plugins/codebase-scribe ~/.cursor/plugins/codebase-scribe
```

Then restart Cursor or run **Developer: Reload Window**.

### Verify installation

Run `/plugin` in Claude Code or check the plugins panel in Cursor to confirm the plugin is loaded.

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

Design decisions are tracked in `.claims.yml` with provenance — the maintain mode detects when code changes might invalidate a recorded decision and flags it for your review on the next run.

## Documentation Review

Every documentation change goes through a quality gate powered by a separate review agent:

**Automatic review** — After drafting or maintenance, a fresh-session review agent verifies documentation against source code. It checks file path existence, function name accuracy, behavioral claims, and coverage gaps.

**Two-pass verification:**
- **Mechanical pass** — High-confidence filesystem checks (does this path exist? does this function exist?)
- **Semantic pass** — Lower-confidence content verification (does the doc accurately describe what the code does?)

**Human gate** — For large changes (new drafts, major rewrites) or autonomous runs, the review report is presented for human approval before finalizing.

**Rework loop** — If the review finds critical errors, the drafting skill automatically corrects them and re-submits for review (hard cap: 2 iterations).

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
    .claims.yml                # Cross-topic consistency cache (gitignored)
  .scribe/
    session.json               # Session state (gitignored)
```

### Git Integration

Add these to your `.gitignore`:

```
.scribe/                    # Session state (local only)
docs/agents/.claims.yml     # Cross-topic consistency cache (regenerated each run)
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

Topic files are organized by agent intent, not by depth:

- **TL;DR** — Relevance routing: is this the right doc for your task?
- **Key Entry Points** — Files, commands, configs to orient yourself
- **Patterns & Conventions** — What to follow when writing new code
- **Gotchas** — What will bite you if you don't know
- **Dependencies & Context** — Deeper understanding, design rationale
- **Links** — Cross-references to other topics and external docs

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

```markdown
---
scribe:
  scan: "a1b2c3d4"
  freshness: 100
  human_input: 0
  completeness: 85
  watch_paths: ["cmd/", "internal/api/", "internal/store/"]
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
| Backend Architecture | 100% | 0% | 85% | 12 | backend-architecture.md |
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
  hard_split: 800              # Refuse to generate single file above this

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

# Topic customization
topics:
  skip: [tech-debt]            # Topics to never generate
  custom:                      # Additional topic definitions
    - name: api
      description: "REST API endpoints and contracts"
      watch_paths: ["api/", "pkg/handlers/"]

# Cross-repo
cross_repo:
  known_repos:
    - name: my-operator
      relationship: "deployment operator"
      path: "../my-operator"

# Output location
output:
  docs_dir: "docs/agents"
  agents_md: "AGENTS.md"
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

## Multi-Repo Usage

The plugin is single-repo focused but cross-repo aware. It detects references to other repos (go.mod, package.json, symlinks, CI configs) and documents the relationships. Run `/codebase-scribe` in each repo independently.

## Resumability

Sessions can be interrupted at any point. The plugin tracks progress per-topic and resumes where it left off. Long-running workflows decompose naturally into chunks across multiple sessions.

## File Skipping

The plugin skips vendored dependencies, lock files, and known boilerplate generator output (protoc, swagger-codegen, etc.). It does NOT skip files generated by AI coding agents — those are real application code.

## License

Apache-2.0
