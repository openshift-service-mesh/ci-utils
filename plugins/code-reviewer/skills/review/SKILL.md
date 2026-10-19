---
name: review
description: Alias for the code-reviewer entry skill. Prefer $code-reviewer or $code-reviewer:code-reviewer in Codex; use /code-reviewer:review in Claude Code and Cursor.
---

# Code reviewer (`review` skill)

Same workflow as `skills/code-reviewer/SKILL.md`. An argument of `adversarial`, `style`, or `testing` selects one phase; with no phase, run all three.

## Workflow

1. Verify that the repository is readable and identify the base branch and diff. Check for `.code-reviewer/config.md` and reference docs, also accepting the legacy `.claude/code-reviewer/` location. If no setup exists, explain that setup should be run first (`$code-reviewer:setup` on Codex, `/code-reviewer:setup` on Claude Code/Cursor) and ask whether to continue with a review using repository guidance only.
2. Invoke the `triage` skill to capture the diff, load applicable project guidance, and produce review briefs. Keep the briefs as the source of truth for the review phases.
3. Delegate the selected review phases to Codex sub-agents. For a full review, spawn three independent sub-agents in parallel; for a phase-specific review, spawn only that phase's sub-agent. Use the corresponding prompt in `agents/adversarial-reviewer.md`, `agents/style-reviewer.md`, or `agents/testing-reviewer.md` as the specialist instructions, and pass the triage brief plus relevant reference-doc excerpts in each sub-agent prompt. Do not perform the specialist review in the coordinator context when delegation is available. Each sub-agent must report evidence, file and line locations, severity, and concrete remediation. Do not report personal preferences as defects.
4. Wait for all selected sub-agents to return, record any failed phase, and invoke the `consolidation` skill on their reports. Deduplicate findings, preserve the strongest evidence, and assign stable finding IDs and a verdict.
5. Present the consolidated report with blocking findings first, followed by non-blocking findings, strengths, open questions, and the verdict. Ask before writing a report file, changing project reference docs, or posting to a code-hosting service.

If the current Codex host does not expose sub-agent delegation, say so explicitly and ask whether to run a clearly labeled single-agent fallback; do not silently claim that sub-agents ran. Never submit comments, approve, merge, or otherwise mutate a pull request as part of this skill unless the user explicitly requests that action. Use Codex skill names (`$code-reviewer:*`), not Claude slash-command syntax.
