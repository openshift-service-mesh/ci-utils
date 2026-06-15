---
skill: prow-metrics
analyzed_at: 2026-06-15T00:00:00Z
skill_hash: c3d4e5f6a7b8
execution_mode: batch
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - python_script_executed
  - tsv_file_created
  - summary_statistics_present
  - no_fabricated_numbers
  - output_format_correct
---

# prow-metrics Analysis

## Purpose

`prow-metrics` fetches live Prow CI job data for the four OSSM repositories (`istio`, `proxy`, `sail-operator`, `ztunnel`) and presents it as a structured summary with a TSV export suitable for Excel. The skill is strictly a data presentation tool — no recommendations, no analysis, no invented numbers.

The skill runs an inline Python script that calls `https://prow.ci.openshift.org/prowjobs.js`, filters for OSSM repos, applies count/time limits, computes statistics, writes a TSV file, and returns JSON. Claude then formats the JSON into the output table.

## Inputs

The skill gathers via `AskUserQuestion` (or headless `input.yaml`):
- `mode`: "count" or "days"
- `count`: number of completed jobs to collect (default 100, used when mode="count")
- `days`: number of days to look back (used when mode="days")

## Output Artifacts

1. **Conversational summary** — formatted statistics table matching the canonical output format
2. **TSV file** — written to the working directory as `ossm_prow_{label}_plus_pending_{timestamp}.tsv`

## Sub-skills and Pipeline

No sub-skills. Single Python script execution followed by statistics formatting.

## Key Constraints

- All statistics must derive from the Python script's JSON output.
- The TSV file must be written.
- No fabricated job names, counts, or durations.
- API errors must be reported honestly — no guessed numbers.
- The Python script `COUNT` and `DAYS` variables must be correctly substituted before execution.

## Evaluation Notes

Cases exercise:
1. Default 100-completed collection (count mode, 100)
2. Custom count (count mode, 50)
3. Time-based collection (days mode, 7)

Key judges: Python script ran, TSV file created, summary statistics section present, numbers are internally consistent (no fabrication), output matches canonical format.
