---
skill: scribe-maintain
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: fd9539e7ad3b
execution_mode: case
headless: false
dry_run: false
suggested_judges:
  - cost_budget
  - correct_sections_updated
  - no_unauthorized_edits
  - approval_workflow_used
  - maintenance_quality
---

# scribe-maintain Analysis

## Purpose

`scribe-maintain` is the update skill in the `codebase-scribe` pipeline. It detects **drift** between the current codebase and the existing `AGENT.md`, then applies selective updates — only to sections that are actually stale — with engineer approval before each change.

The skill is designed for ongoing use after `scribe-draft` has produced an initial AGENT.md. As the codebase evolves (new components added, modules renamed, architecture changes), `scribe-maintain` identifies which sections are affected and refreshes only those.

## Inputs

The skill operates on:
- The current `AGENT.md` at the project root
- The current codebase (source files)
- `.claude/scribe/inventory.yaml` (re-generated via `scribe-discover` sub-skill to detect drift)

Interactive input via `AskUserQuestion` is required for each proposed section update — the engineer approves, declines, or requests refinement per section.

## Pipeline

1. Re-run `scribe-discover` (via Skill tool) to generate a fresh inventory
2. Compare fresh inventory against current `AGENT.md` for each section
3. For each detected discrepancy, ask the engineer to approve the proposed update
4. Apply approved updates in-place, leaving declined sections unchanged
5. If inventory changed significantly, also update `.claude/scribe/inventory.yaml`

## Output Artifacts

The skill modifies **`AGENT.md` in-place** at the project root. Only approved sections are changed. Declined sections are preserved character-for-character.

If no drift is detected or all proposals are declined, `AGENT.md` is unchanged (not in `modified_files`).

## Key Behavioral Constraints

- **Approval required for each section**: the engineer must approve each section update before it is applied. Silent bulk updates are a bug.
- **Section isolation**: updating the Architecture section must not affect the Development Guide section, even if both need changes.
- **Preserved sections unchanged**: character-level preservation of declined sections — no "minor reformatting" of preserved content.
- **Inventory refresh**: the stale inventory file at `.claude/scribe/inventory.yaml` should be updated with the fresh discovery result after a maintenance run.

## Sub-skill Invocation

`scribe-maintain` calls `scribe-discover` via the `Skill` tool to get the fresh inventory needed for drift detection. This makes `Skill` a required permission.

## Evaluation Notes

Files are modified in-place, so judges use `outputs["modified_files"]` to access changed content. Key quality signals:

1. **Correct section selection**: only stale sections modified; fresh sections untouched
2. **No unauthorized edits**: declined sections must be byte-identical to input
3. **Approval workflow**: conversation should show per-section questions before changes
4. **Content accuracy**: updated sections must reflect the current code state, not the old state

The evaluation hook answers `AskUserQuestion` calls using the case's `answers.yaml`, specifying which sections to approve and which to decline. The evaluation dataset must include cases where some sections are stale and others are current — the skill's ability to distinguish between them is the primary evaluation target.
