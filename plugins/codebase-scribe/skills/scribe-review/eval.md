---
skill: scribe-review
analyzed_at: 2026-07-27T00:00:00Z
skill_hash: regenerated-wave-6
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - dispatched_via_agent_not_handwritten
  - report_format_valid
  - verdict_correct
  - findings_tag_and_evidence
  - recommendation_actionable
  - review_quality
---

# scribe-review Analysis

## Purpose

`skills/scribe-review/SKILL.md` is now an 8-line **dispatching stub**
(spec §3). It is superseded by the `codebase-scribe:scribe-review` agent,
which holds the actual review protocol (two-pass mechanical + semantic
verification, finding classification, the report format). The skill's entire
job — and the entire surface this eval suite can test at the skill level — is:
construct the Step 9c brief from whatever inputs it's given, dispatch the
`codebase-scribe:scribe-review` agent via the Agent tool, and return the
agent's report **verbatim**.

This suite therefore evaluates the review pipeline **indirectly through the
dispatching stub**, exactly as the brief requires — every case invokes the
`scribe-review` skill (not the agent directly). Judges assert that the
relayed report is correct (format, verdict, findings, recommendation), and
`dispatched_via_agent_not_handwritten` proves the dispatch itself
mechanically from the enabled event trace — see Evaluation Notes for exactly
what it reads and how it behaves when the trace cannot answer.

## Inputs

Each case supplies the Step 9c brief directly: `topic_name`, `topic_content`,
`watch_paths`, `docs_dir`, `source_files`, `claims`, `change_classification`,
`change_summary` — the same shape `commands/codebase-scribe.md` Step 9c
constructs for a real orchestrator run. The dispatched agent has real
Read/Bash/Grep/Glob access, so the source tree at each case root (`internal/`,
`cache/`, or `orders/`) is real source, not just described in the brief — the agent's mandate is "do not trust the brief alone
— verify claims directly against the codebase."

## Output Artifacts

Stdout-only — the relayed report. No files are written.

## Spec Sections Exercised

- **§3 review pipeline via the dispatching stub** — every case confirms
  (`report_format_valid`) that the relayed report keeps the agent's exact
  section structure, including a parseable `## Verdict:` line, and
  (`dispatched_via_agent_not_handwritten`) that the event trace holds exactly
  one Agent/Task call with `subagent_type: codebase-scribe:scribe-review`
  whose child report carries the verdict that came back to the caller — plus
  the same internal-consistency check on the relay, using the agent's own tag
  vocabulary and verdict rule (`Any critical finding -> REWORK_NEEDED`).
  A bare mention of the agent's name in prose has never been evidence of a
  dispatch; now nothing short of the trace is (see Evaluation Notes).
- **Seeded documentation errors named in the task brief**:
  - case-002 seeds a **wrong-file attribution** (doc cites the wrong file for
    a real function) → `WRONG_FILE`.
  - case-003 seeds **deprecated-as-current** documentation (`EvaluateFlag` in
    `internal/flags/evaluator.go` — a live, compiling function carrying a
    `// Deprecated:` doc comment that names `EvaluateFlagV2` as its
    replacement, documented as the active path) → `DEPRECATED`. The seeded
    signal is the doc comment, not commented-out code: the agent has to read
    the comment rather than notice absent code.
  - case-004 seeds **changelog language** ("was added", "now supports") →
    `CONTRADICTION`, per the agent's "Common LLM Documentation Errors" #6.
  - case-001 is a clean topic (no seeded errors) → `PASS` **or**
    `PASS_WITH_ANNOTATIONS` (see Evaluation Notes for why both are accepted).
  - case-005 combines multiple critical findings across most of the topic →
    `REWORK_NEEDED`, with either the targeted or the full-redraft
    recommendation (see Evaluation Notes for why both are accepted).

## De-P3 Carve-Out

The pre-wave-6 suite's `recommendation_actionable` judge, the `outputs.schema`
recommendation lines, and `review_quality`'s prompt all referenced the retired
per-skill-name vocabulary ("Run scribe-maintain to update: <sections>" / "Run
scribe-draft for a full redraft"). All three are rewritten here for the
post-wave-6 strings the agent's Report Format section actually specifies:

- `"No action needed — the documentation is up to date."`
- `` "Run `/codebase-scribe` again — targeted correction of sections: <list>." ``
- `` "Run `/codebase-scribe` again — full redraft recommended." ``

`recommendation_actionable` asserts both the presence of the correct new
string for each case's `expected_recommendation_kind` **and** the absence of
the retired phrasing, so a regression toward the old per-skill-name wording
fails loudly rather than silently passing a looser check.

It reads the **last** `## Recommendation` section in the transcript, bounded at
the next `##` heading or end-of-string — the same shape the maintain suite's
structural judge uses. Anchoring on the first occurrence and spanning to the
end swallowed everything after it, so a run that correctly relayed the
dispatched agent's report verbatim held two `## Recommendation` headings and
failed the exactly-one-line check *because* it was compliant.

## Deliberately Uncovered

- **Scoped re-review** (`previous_findings`/`rework_iteration`/
  `changed_sections` in the brief, for a rework pass) is not covered — every
  case here is a first-pass review. A scoped re-review is better tested at the
  orchestrator level (Step 9d item 3), where the previous report is a real
  input, not a hand-authored fixture.
- **`INCONSISTENCY`, `COVERAGE_GAP`, `THIN_SECTION`, `MISSING_XREF`,
  `NAME_MISMATCH`, and `UNVERIFIABLE`** tags are not individually seeded — the
  brief's named error categories (wrong-file, deprecated-as-current,
  changelog language) take priority for this batch of 5; the agent's own tag
  vocabulary is broader than this suite exercises. (`MISSING_REF` IS seeded —
  case-005's fabricated `CapturePayment` reference — so it is not listed
  here.)

## Evaluation Notes

**case-001 accepts two verdicts, and that is a deliberate limit, not slack.**
`PASS` requires literally zero findings of any severity. The agent's Pass 2
includes the heuristic "flag sections with significantly fewer concrete
references than the topic average", which is live on any fixture realistic
enough to be worth reviewing — on this one, `## Gotchas` carries two concrete
references against `## Overview`'s five. A minor finding is exactly what the
agent's verdict rules map to `PASS_WITH_ANNOTATIONS`, so both verdicts are
contract-correct here and `verdict_correct` accepts either (its
`expected_verdict` annotation is a list). Flattening the fixture until no
heuristic can fire was tried in the other direction the round before — the
repair for one derivability problem surfaced the next — and chasing every
possible finding out of a fixture designed to be realistic is not a winnable
game. Nothing discriminating is lost: the assertion that actually separates a
clean topic from a defective one is an **empty Critical Findings section**,
which `findings_tag_and_evidence` enforces from this case's empty
`expected_critical_tags`, and `recommendation_actionable` still requires the
`no_action` recommendation line (which the agent's rules permit under both
verdicts). Do not re-tune this fixture to force `PASS`.

**case-005 accepts two recommendation lines, for the same reason case-001
accepts two verdicts.** The agent's Recommendation rules put the choice on a
severity judgment — "targeted" when the structure is sound and only specific
sections need correction, "full redraft" when repair would leave gaps — and
this fixture is three structurally sound sections carrying one mechanical error
each (wrong file attribution, fabricated reference, deprecated symbol). That
reading legitimately supports "targeted", so pinning the single `full_redraft`
line failed a protocol-compliant report at `min_pass_rate: 1.0`.
`expected_recommendation_kind` therefore accepts a list, exactly as
`expected_verdict` does. Nothing discriminating is lost: what separates this
case from a healthy topic is `REWORK_NEEDED` plus all three critical tags with
evidence, asserted by `verdict_correct` and `findings_tag_and_evidence`, and
`recommendation_actionable` still requires exactly one line, matching one of
the three exact protocol forms, with the retired vocabulary absent. Do not
re-seed the fixture to force `full_redraft`.

`findings_tag_and_evidence` searches for expected critical tags inside the
**Critical Findings section only**, not the whole transcript — a tag under
Minor Findings, or quoted in the agent's own tag-vocabulary table, used to
satisfy a *critical* expectation. Its evidence check was already scoped that
way; both halves now read the same window.

Judges read `{{ conversation }}`, the full transcript including the dispatched
agent's report — there is no `outputs["files"]` for this skill.
`dispatched_via_agent_not_handwritten` deliberately does NOT grep the
transcript for the literal string "codebase-scribe:scribe-review" — that name
appears in the stub's own instructions and in any prose narration of what
happened, so a match there is not evidence of anything. Its evidence that
dispatch actually occurred comes from the `traces.events` trace instead; the
"Dispatch is now proven, not inferred" paragraph below states the judge's
requirement set in full. On top of that trace evidence it requires the agent's
full five-section report shape AND checks that the parsed verdict is internally
consistent with the Critical Findings section's tag vocabulary (any tagged
critical finding implies `REWORK_NEEDED`). The reverse direction is
deliberately **not** asserted: the agent's verdict rules end with "If in doubt
→ REWORK_NEEDED (fail-safe)", so `REWORK_NEEDED` with an empty Critical
Findings section is contract-sanctioned, and asserting the converse would fail
a protocol-compliant report. Whether `REWORK_NEEDED` was the *right* verdict
for a given case is `verdict_correct`'s job.

**Dispatch is now proven, not inferred.** The shape and consistency checks
above establish only that *something* produced a protocol-shaped report; a
sufficiently careful hand-written review copying the agent's exact format and
obeying its verdict rule passed all of them, and the judge used to say so in
its own description. Since the suite's central §3 requirement is precisely
"fresh-context review through the dedicated agent", that left the requirement
with no deterministic judge that could fail on it. The judge therefore reads
the `traces.events` trace this suite already enables and requires, in addition
to the two report-side checks above, all three of:
exactly one `Agent`/`Task` tool call carrying
`subagent_type: codebase-scribe:scribe-review`; a subagent *result* in the
trace containing the agent's report; and that report's verdict matching the
one relayed to the caller. Structure is walked generically (dict/list
recursion, several spellings of the tool-name and tool-input keys, JSON or
JSONL) so it does not hard-code one runner's event schema.

**It fails rather than skips.** If the trace is absent, records no tool
inputs, or carries no subagent result, the judge returns FAIL with a message
naming the missing piece. That is deliberate and follows the same rule as
`stub_frontmatter_valid` in the discover suite: an assertion that cannot be
made must not be reported as an assertion that passed. If it fires, fix the
runner's event surfacing — do not soften this back into a shape check.
`review_quality`'s LLM judgment remains a useful second signal, but it is no
longer the closest thing to a dispatch check.
