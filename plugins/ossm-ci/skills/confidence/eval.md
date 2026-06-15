---
skill: confidence
analyzed_at: 2026-06-15T00:00:00Z
skill_hash: b2c3d4e5f6a7
execution_mode: batch
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - scope_determined
  - score_in_range
  - score_breakdown_complete
  - recommendations_present
  - report_portal_queried
---

# confidence Analysis

## Purpose

`confidence` produces a release readiness report for an OSSM build by:
1. Determining the required test scope (FULL/CORE/BASIC) from the nature of changes
2. Querying the Report Portal MCP server for real midstream and downstream test data
3. Applying a six-factor weighted scoring model to produce a 1–10 confidence score
4. Outputting a structured analysis with recommendations and a release decision

The skill does not fabricate test data — all numbers must come from Report Portal MCP tool responses.

## Inputs

The skill gathers via `AskUserQuestion` (or headless `input.yaml`):
- `build_id`: operator build identifier or release tag
- `ossm_version`: OSSM semantic version (e.g., "3.2.0")
- `istio_version`: Istio version (e.g., "1.27.1")
- `sail_version`: Sail Operator version
- `change_type`: nature of changes — "new_minor", "patch_update", "cve_fix", "code_change", "base_image_update"
- `known_issues`: optional list of known blockers

## Output Artifacts

The skill produces a single conversational analysis containing:
1. Scope determination with rationale
2. Score breakdown table (six factors with weights)
3. Test matrix analysis (platforms, environments, OCP versions)
4. Test execution summary (midstream + downstream pass/total)
5. Recommendations list
6. Release decision: APPROVED / NEEDS ATTENTION / SCOPE NOT MET

## Sub-skills and Pipeline

No sub-skills. The pipeline is:
1. Scope determination
2. Report Portal MCP queries
3. Score calculation
4. Report generation

## Key Constraints

- Score must be 1.0–10.0.
- All pass/fail numbers must come from Report Portal data, not be fabricated.
- Scope must be stated before the score.
- Release decision must be one of: APPROVED, NEEDS ATTENTION, SCOPE NOT MET.

## Evaluation Notes

Cases should exercise:
1. FULL scope — healthy build with good coverage → high score (7–10)
2. CORE scope — mixed results with some failures → mid score (4–7)
3. BASIC scope — minimal but complete coverage → moderate score
4. Missing coverage — required suites not run → low score / SCOPE NOT MET

Judges focus on: scope determination correctness, score in valid range, breakdown present, recommendations actionable, Report Portal MCP actually called.
