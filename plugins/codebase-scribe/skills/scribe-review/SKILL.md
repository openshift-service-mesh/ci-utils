---
name: scribe-review
description: Use when reviewing documentation content after drafting or maintenance. Runs a two-pass review (mechanical + semantic) against source code, classifies findings, and produces a structured report with verdict.
---

# Scribe Review — Documentation Quality Gate

This skill is superseded by the `scribe-review` agent, which holds the review protocol. When invoked (including by the eval runner), construct the Step 9c brief from the provided inputs, dispatch the `scribe-review` agent via the Agent tool (`subagent_type`: `codebase-scribe:scribe-review`) — **exactly once per brief; never a second dispatch to verify, compare, or retry a completed report** — and relay its report byte-for-byte: your entire final output is the agent's report exactly as returned — no preamble, no summary, no reformatting, nothing before `## Review Summary` and nothing after the agent's last line.
