---
name: code-reviewer
description: Run the full code-reviewer pipeline (setup guard, triage, parallel phase sub-agents, consolidation). Use for merge-readiness review of current branch changes.
---

# Code reviewer (Codex entry)

Codex does not load Claude `commands/` as `/code-reviewer:*` slash commands. Use this skill (or `$code-reviewer:review`) as the main entry.

Optional arguments: `adversarial`, `style`, or `testing` for a single phase; omit for all three.

## Workflow

1. Verify that the repository is readable and identify the base branch and diff. Check for `.code-reviewer/config.md` and reference docs, also accepting the legacy `.claude/code-reviewer/` location. If no setup exists, explain that `$code-reviewer:setup` should be run first and ask whether to continue with repository guidance only.
2. Invoke the `triage` skill to capture the diff, load applicable project guidance, and produce review briefs.
3. Delegate the selected review phases to Codex sub-agents using the prompts in `agents/adversarial-reviewer.md`, `agents/style-reviewer.md`, or `agents/testing-reviewer.md`, with the triage brief and relevant reference excerpts. Do not run specialist review in the coordinator when sub-agent delegation is available.
4. Invoke the `consolidation` skill on sub-agent reports, then present the consolidated report (blocking findings first, then verdict and open questions).

If sub-agent delegation is unavailable, say so and offer a clearly labeled single-agent fallback. Do not post to GitHub or mutate a PR unless the user explicitly requests it.

Phase-only skills (`adversarial-review`, `style-review`, `testing-review`) and agent files are for sub-agents and evals — prefer this skill so triage and consolidation always run.
