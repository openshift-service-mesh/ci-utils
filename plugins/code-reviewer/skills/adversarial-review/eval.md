---
skill: adversarial-review
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: 23a57321a255
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - finding_ids_present
  - file_line_references
  - no_vague_findings
  - finding_quality
---

# adversarial-review Analysis

## Purpose

`adversarial-review` is one of four review phases in the `code-reviewer` plugin. It performs a **full-scope, cross-unit** adversarial pass — looking for bugs, security vulnerabilities, and logic errors across the entire changeset. Unlike the other phases (style, testing), adversarial-review receives the full-scope review brief (all units combined) and must identify findings that span multiple units or that require understanding the complete diff.

The word "adversarial" is intentional: the reviewer takes the posture of someone trying to break the code rather than approve it, actively looking for correctness issues, edge cases, and security vulnerabilities that the author may have missed.

## Inputs

The skill receives a single argument: the **review brief** — a markdown document containing:
- The full git diff of the branch under review
- Commit messages
- The complete content of all reference docs (style guide, testing practices, security posture, API conventions)
- Cross-unit context (what changed across all review units)

This brief is assembled by `triage` and passed to `adversarial-review` as the `{review_brief}` argument template.

## Output Artifacts

The skill produces **stdout-only output** (no files written to disk). The report follows a structured format defined in `templates/phase-report.md`:

- **`[adversarial]` tag** in the heading to distinguish from other phase reports
- **Strengths section**: file:line references for well-implemented patterns
- **Findings by severity** (Critical → Important → Minor) with structured IDs:
  - `BUG-N`: Logic bugs, correctness issues, crashes, data corruption risks
  - `SEC-N`: Security vulnerabilities (injection, auth bypass, insecure defaults, credential exposure)
  - `IMP-N`: Improvements (not bugs, but noteworthy patterns)
- **Each finding contains**: ID, taxonomy sub-category tag, `file:line` reference in backticks, description of the issue, consequence of leaving it unfixed, suggested fix
- **Open Questions**: findings the reviewer is uncertain about and wants clarification on

### Bug Taxonomy Sub-Categories

The adversarial reviewer categorizes bugs by sub-type: `Logic & Control Flow`, `Error Handling & Propagation`, `Concurrency & Race Conditions`, `Resource Management`, `Input Validation & Boundary Conditions`, `Data Integrity`, `API Contract Violations`, `Configuration & Initialization`.

Security findings use: `Authentication & Authorization`, `Injection & Input Handling`, `Cryptography & Secrets`, `Dependency & Supply Chain`, `Information Disclosure`, `Configuration Security`.

## Evaluation Notes

Since the output is stdout-only, all judges must use `{{ conversation }}` to access the report (not `{{ outputs }}`). The key quality signals are:

1. **Finding ID structure**: BUG-N and SEC-N prefixed, sequential within each prefix
2. **File:line precision**: Every finding must include a backtick-wrapped `file:line` reference
3. **No vague findings**: Adversarial findings must identify specific code patterns, not general concerns
4. **Taxonomy accuracy**: Correct categorization by bug sub-type
5. **Consequence articulation**: Each finding explains why it matters, not just what's wrong

The evaluation dataset should include cases with:
- Clean code (minimal findings expected)
- Code with injected bugs of known categories
- Code with security issues (injection, auth gaps, credential exposure)
- Cross-unit bugs that only appear when viewing the full diff
