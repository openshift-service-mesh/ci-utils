---
skill: consolidation
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: 670c525a853c
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - verdict_present
  - finding_id_format
  - verdict_matches_findings
  - consolidation_quality
---

# consolidation Analysis

## Purpose

`consolidation` is the final phase of the `code-reviewer` pipeline. It receives the completed reports from all preceding phases (adversarial, style, testing — or a subset if some phases were skipped), deduplicates findings, assigns globally sequential IDs across all prefixes, and produces a single unified report with a clear "ready to submit?" verdict.

The consolidation phase is what the engineer reads — not the individual phase reports. It must be coherent, non-redundant, and end with a definitive verdict that the engineer can act on.

## Inputs

The skill receives a single argument: the **full text of all completed phase reports** concatenated into one string (`{phase_reports_context}`). This includes:
- The adversarial review report (with BUG-N, SEC-N IDs from that phase)
- The style review report (with STY-N IDs from that phase)
- The testing review report (with TST-N IDs from that phase)
- Any phase failure notices (if a phase was skipped or errored)

## Output Artifacts

The skill produces **stdout-only output** (no files written to disk). The consolidated report contains:

- **Review Summary**: phases completed, unit count, total findings
- **Findings by severity** with globally re-assigned sequential IDs:
  - `BUG-N`: Logical bugs (from adversarial phase)
  - `SEC-N`: Security findings (from adversarial phase)
  - `STY-N`: Style violations (from style phase)
  - `TST-N`: Testing coverage gaps (from testing phase)
  - `IMP-N`: Improvements across all phases
- **Cross-Unit Findings**: findings that span multiple review units (if any)
- **Strengths**: aggregated strengths from all phases (deduplicated)
- **Open Questions**: aggregated open questions from all phases
- **Verdict**: `Ready to submit? Yes / No / With fixes` — with brief reasoning

### Verdict Logic

- **Yes**: no Critical findings, no unresolved Open Questions
- **With fixes**: Important findings that block submission, but fixable
- **No**: Critical findings or unresolved security vulnerabilities

## Key Behavior: Deduplication

When multiple phases flag the same issue (e.g., adversarial flags a missing nil check, testing also flags the missing test for that code path), consolidation merges them into a single finding under the most relevant prefix, noting that multiple phases flagged it.

## Evaluation Notes

Since the output is stdout-only, all judges use `{{ conversation }}` to access the report. The critical quality signals are:

1. **Verdict presence and parsability**: must end with `Ready to submit? Yes / No / With fixes`
2. **ID sequential within prefix**: BUG-1, BUG-2, ... SEC-1, SEC-2, ... (not globally sequential across prefixes)
3. **Verdict consistency**: Critical findings → not "Yes"; no critical findings → not "No"
4. **Proper deduplication**: no duplicate findings from different phases
5. **All required sections present**: Summary, Strengths, Questions, Verdict

Evaluation cases should include:
- Reports from all three phases with overlapping findings (dedup testing)
- Reports with phase failures (e.g., testing phase skipped)
- Clean code with no findings → "Yes" verdict
- Reports with critical security findings → "No" verdict
