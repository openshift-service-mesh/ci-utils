---
skill: doc-update
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: 77d30db81429
execution_mode: case
headless: false
dry_run: false
suggested_judges:
  - cost_budget
  - changelog_entries_added
  - no_wholesale_rewrites
  - one_change_per_question
  - update_quality
---

# doc-update Analysis

## Purpose

`doc-update` is an optional post-review skill that identifies convention patterns from the code review discussion and proposes targeted updates to the project's reference documentation (style guide, testing practices, API conventions). It bridges the review process and the living documentation — when a review reveals a pattern that should be codified, `doc-update` handles the update loop.

The skill is driven by the **consolidated review findings and engineer responses** — specifically IMP-N findings (improvement suggestions) and patterns that emerged as recurrent across multiple review cycles. It does not update documentation based on BUG or SEC findings (those are bugs to fix, not conventions to codify).

## Inputs

The skill receives the `{review_context}` argument — the text of the consolidated review plus any engineer discussion. It reads the existing reference docs from `.claude/code-reviewer/reference/` to understand what's already documented before proposing additions.

Interactive input via `AskUserQuestion` is central to the skill:
- For each proposed convention update, the skill asks the engineer to **approve, decline, or refine** the proposed wording
- Questions are asked **one convention at a time** — never batched
- The engineer's answer determines whether the change is applied

## Output Artifacts

The skill modifies reference doc files **in-place** at `.claude/code-reviewer/reference/`:
- `style-guide.md` (if style conventions are being added)
- `testing-practices.md` (if testing patterns are being codified)
- `api-conventions.md` (if API conventions are being added)

Each modification:
1. Inserts the new convention into the appropriate `## Conventions` section
2. Appends a changelog entry to the `## Changelog` table with columns: `Date | Change | Trigger`

The trigger column records what caused the update (e.g., "review of branch/feature-X", "IMP-3 from consolidation").

## Key Behavioral Constraints

- **No wholesale rewrites**: doc-update makes surgical inserts only. The document structure, existing conventions, and formatting must be preserved.
- **One question per convention**: asking "should I update both the naming convention AND the error handling convention?" is a bug in this skill.
- **Declined changes are not applied**: the skill must honor decline responses and leave the document unchanged.
- **Changelog is required**: every accepted change must produce a changelog entry.

## Evaluation Notes

Since changes are in-place edits (not new files), judges must use `outputs["modified_files"]` to access the updated content. The key quality signals are:

1. **Changelog presence**: every modified file must have a `## Changelog` section with the new entry
2. **Structure preservation**: `## Conventions` section must survive the edit
3. **Question granularity**: one question per convention (regex detection in conversation)
4. **Decline compliance**: declined questions must not produce file changes

The evaluation hook needs to respond to `AskUserQuestion` calls using the `answers.yaml` per case, which specifies approve/decline/refine for each proposed change.
