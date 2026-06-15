---
skill: consolidation
analyzed_at: 2026-06-09T00:00:00Z
skill_hash: 670c525a853c
---

# Consolidation Skill Analysis

## Purpose

The `consolidation` skill is the final step in the code review pipeline. After the `triage`, `adversarial-review`, `style-review`, and `testing-review` subagents complete their passes, `consolidation` merges their reports into a single, deduplication-clean, verdict-bearing output for the engineer.

## Invocation

The skill is never invoked standalone. It is always triggered as Step 3 in `/code-reviewer:review` (interactive) or `/code-reviewer:ci-review` (CI). It receives subagent reports via conversation context, not CLI arguments.

In eval, each test case provides mock phase reports via a `{prompt}` argument, simulating the assembled context the skill would normally receive from the preceding pipeline steps.

## Input Structure

Each eval test case has:

- `input.yaml` — `prompt` (string): assembled consolidation context, including:
  - Triage metadata (branch name, base branch, file count, unit count)
  - Review unit definitions
  - One or more phase reports formatted per `templates/phase-report.md`
  - Each phase report has sections: Strengths, Issues (Critical/Important/Minor), Improvements, Open Questions
  - Finding IDs follow phase-specific prefixes: BUG-N/SEC-N (adversarial), STY-N (style), TST-N (testing), IMP-N (any phase)
- `annotations.yaml` (optional): `expected_verdict`, `expected_finding_count`, `phases_present`, `has_cross_unit`

## Output Structure

The skill produces all output as conversation text (no files written to disk). The consolidated report contains:

1. **## Review Summary** — overview of what was reviewed; notes any missing phases
2. **## Findings** — organized by severity (Critical, Important, Minor)
   - Each finding: `**PREFIX-N** [Sub-category] file:line — description — why it matters — how to fix`
   - Deduplicated findings tagged with all phases: `**[adversarial, testing]**`
   - IDs sequential within each prefix, ordered by severity
3. **## Cross-Unit Findings** — issues spanning multiple review units (omitted if none)
4. **## Strengths** — aggregated and deduplicated from all phases
5. **## Open Questions** — aggregated and deduplicated
6. **## Verdict** — `**Ready to submit?** Yes / No / With fixes` + `**Reasoning:**` (1-2 sentences)

## Pipeline

1. Collect all available phase reports from subagents
2. Extract findings, preserving severity, file:line, and phase source
3. Deduplicate: group by file:line or conceptual issue; keep most detailed version; use lowest ID; tag with all phases
4. Assign final sequential IDs within each prefix, ordered Critical → Important → Minor
5. Scan across review units for cross-unit issues (API changes, shared types, config impacts)
6. Aggregate strengths and open questions; deduplicate
7. Determine verdict based on severity profile
8. Format and output the consolidated report as conversation text

## No Sub-Skills

The consolidation skill does not invoke other skills. It is a pure text-processing orchestrator.

## No External APIs

The skill does not call MCP tools, scripts, or external services. It requires no `inputs.tools` configuration.

## Quality Criteria

**Deterministic checks:**
- Verdict section is present with a valid value (Yes/No/With fixes) and Reasoning
- Required sections present: Review Summary, Findings, Verdict
- Finding IDs use valid prefixes (BUG, SEC, STY, TST, IMP) and are sequential within each prefix

**LLM judgment:**
- No findings lost from input phase reports
- Deduplication is correct: same conceptual issue merged, tagged with all phases
- Severity levels match SKILL.md definitions (Critical reserved for bugs/security/data-loss)
- Cross-unit section correctly identifies multi-unit issues or is correctly omitted
- Verdict accurately reflects the finding profile
- Consolidated output is scannable and well-structured
