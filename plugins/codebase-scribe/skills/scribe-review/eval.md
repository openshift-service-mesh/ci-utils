---
skill: scribe-review
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: da611c0321be
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - staleness_assessment_correct
  - evidence_with_file_refs
  - recommendation_actionable
  - review_quality
---

# scribe-review Analysis

## Purpose

`scribe-review` is the assessment skill in the `codebase-scribe` pipeline. It checks whether the existing `AGENT.md` is still accurate relative to the current codebase state and produces a structured staleness report with evidence and a specific remediation recommendation.

It is the diagnostic skill — it does not modify any files. Its output tells the engineer whether action is needed and which scribe skill to run next.

## Inputs

The skill operates on:
- The current `AGENT.md` at the project root
- The current codebase (source files, config files)
- `.claude/scribe/inventory.yaml` (may be stale — scribe-review checks this too)

No user input is required. The skill runs headlessly.

## Output Artifacts

The skill produces **stdout-only output** — a structured staleness report:

```
## Staleness Assessment: [Stale | Up to date] (confidence: High/Medium/Low)

## Stale Sections
- **Architecture**: Component `AuthService` in AGENT.md but not found in src/auth/; 
  instead `src/auth/oauth.go` defines `OAuthProvider`
  → Evidence: `src/auth/oauth.go:1` defines package `oauth`, not `auth`
- ...

## Up-to-Date Sections
- Development Guide: build commands `go build ./...` verified against go.mod
- ...

## Recommendation
Run /codebase-scribe:scribe-maintain to update: Architecture, Key Conventions
(or Run /codebase-scribe:scribe-draft for a full redraft if drift is severe)
```

### Staleness Categories

- `new_component_undocumented`: a component exists in code but not in AGENT.md
- `wrong_command`: a command in AGENT.md doesn't match what's actually in the build config
- `renamed_module`: a module name in AGENT.md doesn't match current package names
- `outdated_architecture`: the architecture description doesn't match current structure
- `fresh_up_to_date`: AGENT.md matches current code — no action needed

## Key Behavioral Constraints

- **Evidence required**: every staleness claim must cite a specific file:line that contradicts AGENT.md. "The architecture may have changed" is not a finding.
- **No false positives**: the reviewer must verify that a section is actually stale before flagging it — checking test files before claiming they're not mentioned, reading the actual build config before claiming the command is wrong.
- **Recommendation precision**: the recommendation must name the specific sections to update (for `scribe-maintain`) or state "full redraft" (for `scribe-draft`). "Update the documentation" is too vague.
- **Severity calibration**: recommend full redraft only if ≥50% of sections are stale; otherwise, targeted maintain.

## Evaluation Notes

Since the output is stdout-only, all judges use `{{ conversation }}` to access the report. Key quality signals:

1. **Correct assessment**: stale vs. up-to-date judgment matches injected drift type
2. **Evidence quality**: file:line citations for every stale claim
3. **No false positives**: up-to-date sections not incorrectly flagged
4. **Actionable recommendation**: specific sections named for maintain, or full redraft stated

The evaluation dataset injects different types of staleness into otherwise-current AGENT.md files and verifies that `scribe-review` detects only the injected drift (not phantom staleness) and produces evidence pointing to the actual discrepancy.
