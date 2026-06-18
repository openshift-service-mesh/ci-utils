---
name: ci-review
description: Run fully autonomous code review in CI — no user interaction required. Performs ephemeral setup if needed, runs all review phases, and posts results to the PR.
argument-hint:
---

# CI Code Review

You are running a fully autonomous code review pipeline in a CI environment. There is no human in the loop — every step runs automatically and all output goes to GitHub.

## CI Context Detection

Determine the PR context from the environment:
1. Run `gh pr view --json number,headRefName,baseRefName,url` to get the current PR details
2. If no PR is associated with the current branch, stop with an error message: "No PR found for the current branch. /code-reviewer:ci-review must run in the context of a pull request."
3. Store: PR number, head branch, base branch, PR URL, owner/repo (from `gh repo view --json nameWithOwner`)

## Step 0: Setup — Ensure Reference Docs Exist

Check if the project has reference docs:
1. Check if `.code-reviewer/config.md` exists
2. If not, fall back to `.claude/code-reviewer/config.md` (legacy path)
3. Check if the corresponding `reference/` directory exists with at least one `.md` file

Use whichever path has the config. If both exist, prefer `.code-reviewer/`.

**If found:** Use them as-is. Proceed to Step 1.

**If neither location has these files:** Invoke the headless-setup skill to auto-discover project conventions and generate reference docs. The headless-setup skill runs non-interactively — it analyzes the codebase and auto-accepts all discovered conventions. Proceed to Step 1 after setup completes.

## Step 1: Triage

Invoke the triage skill to analyze the diff and build review briefs.

Use the **base branch from the PR** (detected in CI Context Detection) as the diff target, overriding any `base_branch` in the project config.

The triage skill will:
1. Capture the diff (PR head vs. PR base)
2. Load the project config and reference docs
3. Group changes into review units
4. Produce unit-scoped briefs and a full-scope brief

If triage reports no changes, post a brief PR comment noting that no reviewable changes were found, and stop.

## Step 2: Dispatch Review Subagents

Dispatch all three agents **in parallel** using the Agent tool. Pass the brief as the agent's prompt content — the brief IS the message the subagent receives. Include the reference doc content inline in the prompt so the subagent has everything it needs.

- Agent tool → `adversarial-reviewer` subagent type, prompt = full-scope brief + all reference doc contents
- Agent tool → `style-reviewer` subagent type, prompt = unit-scoped brief + style guide content
- Agent tool → `testing-reviewer` subagent type, prompt = unit-scoped brief + testing practices content

For multiple review units, dispatch one style-reviewer and one testing-reviewer per unit, all in parallel.

## Step 3: Consolidation

After all subagents return, invoke the consolidation skill to:
1. Collect all phase reports
2. Assign final structured IDs (BUG-N, SEC-N, STY-N, TST-N, IMP-N)
3. Deduplicate findings (keep lowest ID when merging)
4. Surface cross-unit issues
5. Produce the final consolidated report with verdict

## Step 4: Self-Validation

Immediately after consolidation, perform a validation pass on every finding:

1. **Re-examine each finding** — Go back to the code and verify the issue is real
2. **Trace context** — For each finding, check:
   - How the code is actually called (trace callers)
   - Whether the issue is handled elsewhere (e.g., validation at a different layer)
   - Whether the pattern is intentional design
   - Related code in other files that might resolve the concern
3. **Check for common false positives:**
   - "Security issues" that require pre-existing vulnerabilities to exploit
   - "Missing validation" when validation happens at a different layer (e.g., Kubernetes API, framework middleware)
   - "Race conditions" in code paths that are actually serialized
   - "Missing features" that are intentionally out of scope
   - "Unused code" that is used via reflection, generics, or external calls
   - "Style violations" for patterns the project intentionally deviates from
4. **Remove false positives** — Drop any finding confirmed as invalid after deeper analysis
5. **Adjust severity** — Downgrade or upgrade findings based on the wider context discovered

Continue directly to Step 5.

## Step 5: Convention Update Suggestions

Before posting results, check whether the review revealed conventions that should be updated (the CI equivalent of the doc-update skill, but output-only):

- Look for patterns in the diff that contradict reference docs
- Look for consistent undocumented patterns that could be captured
- Look for documented conventions that are consistently not followed

Collect these as suggestions — do NOT write any files. These will be appended to the summary comment.

## Step 6: Post Inline PR Review

Create a **submitted** GitHub PR review with inline comments for each finding.

### Build the Review Payload

For each finding that has a valid `file:line` reference where the file and line are part of the PR diff:
- Map the `file:line` to the correct diff position
- Format the comment body:

```
**{ID}: {Title}** — {Severity}

{Description}

{Why it matters}

{How to fix (if provided)}
```

### Post the Review

```bash
cat << 'REVIEW_EOF' | gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --method POST --input -
{
  "event": "COMMENT",
  "body": "Automated code review by code-reviewer — see inline comments for details.",
  "comments": [
    {
      "path": "path/to/file.go",
      "line": 123,
      "body": "**BUG-1: <Title>** — Critical\n\n<Description>\n\n**Why:** <consequence>\n\n**Fix:** <suggestion>"
    }
  ]
}
REVIEW_EOF
```

Use `event: "COMMENT"` — this posts the review as informational feedback without blocking the merge.

### Line Number Mapping
- Line numbers must refer to lines that are part of the diff (added or modified lines)
- For new files, line numbers correspond directly to the file
- Use `--paginate` when fetching PR files if there are many
- If a finding references a line that is not part of the diff, include it only in the summary comment (Step 7), not as an inline comment

### Findings Without Valid Diff Lines
Some findings may reference lines outside the diff or have ambiguous locations. Collect these separately — they will be included in the summary comment under a "General Findings" section.

## Step 7: Post Summary PR Comment

Post a standalone PR comment with the full consolidated report.

```bash
gh pr comment {pr_number} --body "$(cat <<'COMMENT_EOF'
## Code Review Summary

{consolidated_report}

---

### Suggested Convention Updates

{convention_suggestions_from_step_5, or "No convention updates suggested." if none}

---

*Automated review by [code-reviewer](https://github.com/openshift-service-mesh/ci-utils/tree/main/plugins/code-reviewer) — `/code-reviewer:ci-review`*
COMMENT_EOF
)"
```

The summary comment should include:
- The full verdict and reasoning
- All findings organized by severity (Critical → Important → Minor)
- Cross-unit findings
- Strengths
- Open questions
- Any findings that could not be posted as inline comments (under "General Findings")
- Convention update suggestions from Step 5

## Important Notes

- This command runs all three review phases — phase-specific variants are not supported in CI mode
- Do NOT modify any code — this pipeline only analyzes and reports
- Do NOT prompt for user input at any point — every step is automatic
- Do NOT write report files to disk — all output goes to GitHub
- If a subagent fails, include what you have and note the gap in the consolidated report and summary comment
- Every finding MUST have a structured ID
- Use `event: "COMMENT"` for the PR review — never `"REQUEST_CHANGES"` or `"APPROVE"`
- If the `gh` CLI is not authenticated or the PR cannot be found, fail with a clear error message describing what is missing

## Structured Issue IDs

Every finding in the pipeline must be assigned a structured ID:

| Prefix | Category | Assigned By |
|--------|----------|-------------|
| `BUG-N` | Bugs (logic, correctness, crashes) | adversarial-reviewer |
| `SEC-N` | Security vulnerabilities | adversarial-reviewer |
| `STY-N` | Style / convention violations | style-reviewer |
| `TST-N` | Testing gaps or quality issues | testing-reviewer |
| `IMP-N` | General improvements | any phase |
