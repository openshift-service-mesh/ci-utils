---
name: review
description: Run the code-reviewer pipeline against current repository changes, optionally limiting it to adversarial, style, or testing review. Use for a structured code review or merge-readiness assessment.
---

# Code reviewer

Run a review of the current repository changes. An argument of `adversarial`, `style`, or `testing` selects one phase; with no phase, run all three.

## Workflow

1. Verify that the repository is readable and identify the base branch and diff. Check for `.code-reviewer/config.md` and reference docs, also accepting the legacy `.claude/code-reviewer/` location. If no setup exists, explain that `$code-reviewer:setup` should be run first and ask whether to continue with a review using repository guidance only.
2. Run `$code-reviewer:triage` to capture the diff, load applicable project guidance, and produce review briefs. Keep the briefs as the source of truth for the review phases.
3. Run the selected phase skill(s): `$code-reviewer:adversarial-review`, `$code-reviewer:style-review`, and/or `$code-reviewer:testing-review`. When delegation is available, run independent phases in parallel; otherwise run them sequentially. Each phase must report evidence, file and line locations, severity, and a concrete remediation. Do not report personal preferences as defects.
4. Run `$code-reviewer:consolidation` on the phase reports. Deduplicate findings, preserve the strongest evidence, identify cross-unit issues, and assign stable finding IDs and a verdict.
5. Present the consolidated report with blocking findings first, followed by non-blocking findings, strengths, open questions, and the verdict. Ask before writing a report file, changing project reference docs, or posting to a code-hosting service.

Never submit comments, approve, merge, or otherwise mutate a pull request as part of this skill unless the user explicitly requests that action. Use Codex skill names (`$code-reviewer:*`), not Claude slash-command syntax.
