---
skill: scribe-draft
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: 497b6d6b485c
execution_mode: case
headless: false
dry_run: false
suggested_judges:
  - cost_budget
  - agent_md_generated
  - required_sections_present
  - component_mentions
  - no_inventory_leakage
  - documentation_quality
---

# scribe-draft Analysis

## Purpose

`scribe-draft` is the second skill in the `codebase-scribe` pipeline. It transforms the machine-readable inventory from `scribe-discover` into a human-readable `AGENT.md` that developers use to understand and work with the codebase. It is the primary content-generating skill in the pipeline.

The skill may invoke `scribe-discover` as a sub-skill if the inventory is stale or missing — hence the `Skill` tool permission required in evaluation.

## Inputs

The skill operates on `.claude/scribe/inventory.yaml` (from `scribe-discover`). Optional interactive clarification via `AskUserQuestion` for:
- Audience (developer, contributor, operator)
- Scope (full AGENT.md or specific section only)
- Focus areas to emphasize

## Output Artifacts

The skill writes **`AGENT.md`** to the project root. For a full-scope draft, the document contains:

### AGENT.md Structure

```markdown
# Project Overview
<1-3 paragraphs: what this project does, who uses it, key constraints>

# Architecture
## Components
<per-component description with relative paths and responsibilities>
## Data Flow (optional)
<sequence or description of how data moves through components>

# Development Guide
## Setup
<prerequisites and initial setup steps>
## Building and Testing
<actual runnable commands from build_system inventory>
## Common Commands
<additional useful commands>

# Key Conventions
## Code Organization
<file/directory organization patterns>
## Testing Conventions
<test file naming, framework, coverage expectations>

# Contributing
<PR process, branch naming, review expectations>
```

## Sub-skill Invocation

`scribe-draft` calls `scribe-discover` via the `Skill` tool when:
- `.claude/scribe/inventory.yaml` does not exist
- The inventory is stale (older than 7 days or project structure has changed significantly)

This makes `Skill` a required permission for headless evaluation.

## Key Behavioral Constraints

- **Prose, not YAML**: the generated AGENT.md must be human-readable prose. Raw YAML blocks from inventory.yaml must not appear in the output.
- **Runnable commands**: commands in the Development Guide must use actual values from `build_system.commands` in the inventory, not placeholder text.
- **Component accuracy**: component descriptions must match the inventory — no invented components, no missing core components.
- **Section scope**: when scope is "section", only the requested section is regenerated; the rest of AGENT.md is unchanged.

## Evaluation Notes

Files are written to disk, so judges use `outputs["files"]` to access AGENT.md. Key quality signals:

1. **AGENT.md presence and length**: minimum length signals complete generation (not truncated)
2. **Required section headers**: architecture, development, conventions sections must be present
3. **Component mentions**: key component names from inventory must appear in the document
4. **No YAML leakage**: no raw `entry_points:`, `key_directories:`, etc. in code blocks
5. **Documentation quality**: LLM judge evaluates specificity and usefulness

The evaluation hook answers `AskUserQuestion` calls using the case's `answers.yaml`, providing audience and scope values. The inventory must pre-exist in each case's `.claude/scribe/inventory.yaml` to avoid triggering scribe-discover during evaluation (which would consume extra tokens and complicate output attribution).
