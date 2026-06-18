---
name: testing-review
description: Use when performing testing review — checks test coverage, test quality, missing edge cases, and adherence to the project's testing practices document.
---

# Testing Review

## Purpose

Evaluate whether the code change is properly tested. This is the "is this properly tested?" pass.

## When to Use

- **DO:** Use when dispatched by the `/code-reviewer:review` or `/code-reviewer:review:testing` command
- **DO NOT:** Use for correctness, security, or style — those have dedicated phases

## Input

You receive:
- A **unit-scoped review brief** for the specific review unit you're checking
- The project's **testing practices** reference doc from `.code-reviewer/reference/testing-practices.md`

## Review Focus

### Coverage
- Does the diff add or modify logic? If so, are there corresponding test changes?
- If logic changed but no test files were touched, **always flag this** (severity depends on the change's risk)
- Are new code paths covered by at least one test?
- Read existing test files to understand what's already covered before flagging gaps

### Test Quality
- Do tests verify real behavior or just mock everything?
- Are assertions meaningful (testing outcomes, not implementation details)?
- Do test names clearly describe what they verify?
- Is test setup reasonable or excessively complex?

### Edge Cases
- Are boundary values tested (zero, one, max, empty, nil/null)?
- Are error paths tested (invalid input, network failures, permission errors)?
- Are concurrent/async scenarios tested where applicable?
- Suggest specific missing test cases, referencing similar existing tests as examples

### Testing Practices Compliance
- Does the test structure follow the project's documented patterns?
- Are the right test frameworks and helpers used?
- Do test file locations follow the project's conventions?

## Output Format

Findings must use the `**TST-N**` inline bullet format. The reason this matters: the consolidation phase parses `**TST-N**` identifiers to build a unified finding list across all review phases (adversarial, style, testing). If you use numbered headings or any other format, those findings become invisible to downstream tooling and engineers cannot track or prioritize them.

```
# Testing Review Report — [testing]

## Review Unit: {unit_name}

### Strengths
[Specific observations with file:line references]

### Issues

#### Critical
- **TST-1** [Coverage] `path/to/file.go:42` — what is missing — why it matters — how to fix it

#### Important
- **TST-2** [Coverage] `path/to/file.go:87` — what is missing — why it matters — how to fix it

#### Minor
- **TST-3** [Quality] `path/to/file.go:12` — what is suboptimal — why it matters — how to fix it

### Improvements
- **IMP-1** `path/to/file.go:5` — description

### Open Questions
[Genuinely uncertain items requiring engineer input]
```

The `**TST-N**` prefix is a parseable token — it's what distinguishes a trackable finding from a prose comment. A finding written as a heading (`### 1. No tests for ...`) is just text; a finding written as `- **TST-1** [Coverage] \`file:line\` — ...` is an addressable item that appears in cross-phase reports and can be linked to specific lines in CI. Put the `` `file:line` `` reference on the same bullet line as the ID so the parser captures location without ambiguity.

If coverage is adequate, output the report with no TST findings — do not add a notes section acknowledging gaps you chose not to report.

## Critical Rules

- **Read existing tests first.** Before flagging missing coverage, check what's already tested. Don't ask for tests that exist.
- **Report or omit — never both.** If a code path lacks test coverage, either report it as a TST-N finding or decide it's not worth reporting. Do not acknowledge gaps in notes while also declaring "no findings" — this contradicts the verdict and gives engineers nothing actionable.
- **Suggest specific tests.** Don't say "add tests for edge cases." Say "add a test for when `input` is nil — similar to `TestFoo_NilInput` in `foo_test.go:42`."
- **Grade severity by risk.** Missing tests for a critical auth path → Important. Missing tests for a trivial getter → Minor.
- **Reference testing practices.** Cite the relevant section when flagging convention violations.
- **Acknowledge good tests.** Well-structured, thorough tests are strengths worth calling out.
