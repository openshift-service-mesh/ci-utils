---
skill: triage
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: 54a1bd95b78e
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - setup_guard_passes
  - review_units_produced
  - brief_sections_present
  - triage_quality
---

# triage Analysis

## Purpose

`triage` is the **entry point** of the `code-reviewer` pipeline. It orchestrates the entire review by:

1. **Setup guard**: verifying that `config.md` and reference docs exist (aborting with an error if not)
2. **Diff analysis**: reading the branch diff and commit messages
3. **Unit grouping**: partitioning changed files into semantically coherent "review units"
4. **Brief generation**: producing a self-contained review brief per unit (for style and testing phases) plus a full-scope brief (for adversarial review)
5. **Pipeline launch**: invoking the downstream review phases with the appropriate briefs

## Inputs

The skill takes no explicit arguments — it reads everything from the project state:
- `git diff <base_branch>...HEAD` for the changeset
- `git log --oneline <base_branch>...HEAD` for commit messages
- `.code-reviewer/config.md` for project configuration (base_branch, languages, skip_phases)
- `.code-reviewer/reference/*.md` for reference documentation excerpts

## Output Artifacts

The skill produces **stdout-only output** (no files written to disk). The output contains:

- **Review unit list**: unit names and their file assignments
- **Unit-scoped briefs** (one per unit), each containing:
  - Change Overview (branch, base_branch, file count)
  - What Changed (summary paragraph)
  - Files in This Unit (with change types: A/M/D)
  - Commit Messages (relevant commits)
  - Relevant Reference Doc Excerpts (scoped to this unit's language/domain)
  - Cross-Unit Context (one sentence per other unit)
  - Full Diff for This Unit (actual diff content)
- **Full-scope brief** (for adversarial reviewer): all units, all reference docs
- **Metadata**: branch, base_branch, total files changed, unit count

### Unit Grouping Logic

Files are grouped by semantic domain, not alphabetically:
- Go source → testing → generated files in one unit (keep language-adjacent files together)
- Frontend components separate from backend API handlers
- Database migrations separate from application code
- Configuration and CI files often in their own unit

### Reference Doc Scoping

A key responsibility: triage must **excerpt** relevant sections from reference docs (not include the whole document). Style guide sections relevant to Go code go in Go units; sections about TypeScript don't appear in Go unit briefs.

## Evaluation Notes

Since the output is stdout-only, all judges use `{{ conversation }}` to access briefs. Key quality signals:

1. **Setup guard**: fails correctly when config is missing
2. **Unit count sanity**: 1–8 units typical; 1 unit for small diffs, up to 8 for large changesets
3. **Brief completeness**: all required sections (What Changed, Files, Commits, Reference Excerpts, Full Diff) present in each brief
4. **Semantic groupings**: files grouped by domain, not randomly or alphabetically
5. **Excerpt precision**: reference docs excerpted, not full documents dumped

The evaluation dataset must provide pre-configured `.code-reviewer/` directories (config.md + reference docs) since triage fails without them. Each case should supply a git diff and commit messages for triage to process.
