---
skill: testing-review
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: e0a1c46d5990
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - structured_finding_ids
  - suggestions_reference_existing_tests
  - finding_file_line_refs
  - testing_coverage_quality
---

# testing-review Analysis

## Purpose

`testing-review` is one of four review phases in the `code-reviewer` plugin. It performs a **unit-scoped** review of test coverage, checking the changed code against the project's documented testing conventions in `testing-practices.md`. Its primary job is identifying **genuine coverage gaps** — new or changed code that lacks corresponding tests.

The skill must be a careful false-positive avoider: it inspects existing test files before claiming coverage is missing. A common failure mode is flagging a function as untested when a test for it already exists under a slightly different name.

## Inputs

The skill receives a single argument: the **unit-scoped review brief** for one review unit. The brief contains:
- Changed source files and test files with their diffs
- Commit messages relevant to this unit
- Relevant excerpts from `testing-practices.md` (pre-filtered by `triage`)
- Cross-unit context summary

## Output Artifacts

The skill produces **stdout-only output** following the structure in `templates/phase-report.md`:

- **Heading**: "Testing Review Report — [Unit Name]"
- **Strengths**: Existing good test coverage highlighted with file:line references
- **Issues by severity** (Critical/Important/Minor) with `TST-N` prefixed findings:
  - Each finding: ID, `file:line` reference to the **source code** lacking coverage, description of missing test, consequence, suggested test case (with reference to similar existing tests)
- **`IMP-N` findings**: test quality improvements (not coverage gaps)
- **Open Questions**: testing situations genuinely ambiguous

### Severity Calibration

- **Critical**: Auth, security, or core business logic with zero tests
- **Important**: Key functions or error paths lacking tests
- **Minor**: Nice-to-have coverage improvements, edge case tests missing

## Key Quality Signal: Suggestion Specificity

Unlike style or adversarial review, testing findings must suggest specific test names and reference similar existing tests. "Add tests for GetUser" is vague. "Add `TestGetUser_NotFound` following the pattern of `TestCreateUser_NotFound` in `user_test.go:45`" is actionable.

## Evaluation Notes

Since the output is stdout-only, all judges use `{{ conversation }}` to access the report. The critical quality signals are:

1. **TST-N sequential IDs**: validated by `structured_finding_ids` judge
2. **Suggestion specificity**: test names suggested + references to similar tests
3. **File:line references**: to the source code lacking coverage (not the test file)
4. **No false positives**: no findings for tests that already exist
5. **Scope discipline**: no bugs or style issues flagged (those belong to other phases)

The evaluation dataset should include:
- Code with existing comprehensive tests (no findings expected)
- Code with injected coverage gaps of varying severity
- Code where tests exist but under slightly different names (false-positive trap)
- Testing-practices.md conventions explicitly violated
