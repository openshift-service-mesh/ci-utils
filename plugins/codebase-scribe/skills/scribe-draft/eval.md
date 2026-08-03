---
skill: scribe-draft
analyzed_at: 2026-07-27T00:00:00Z
skill_hash: regenerated-wave-6
execution_mode: case
headless: false
dry_run: false
suggested_judges:
  - cost_budget
  - two_tier_structure
  - human_sections_attribution
  - claims_and_decisions
  - safety_rules_respected
  - mode_stamping_and_scope
  - draft_quality
---

# scribe-draft Analysis

## Purpose

`scribe-draft` is Phase 2 of the `codebase-scribe` pipeline. It reads source
code within per-topic file budgets, writes topic file content, asks at most one
design-decision question per topic (plus focus-mode questioning), extracts
factual claims, calculates scores, and dispatches the review gate. It also runs
two narrower pipelines on the same skill: **rework mode** (targeted correction
from review findings) and **question-pass mode** (a single retry ask for
`unverified` topics).

## Inputs

Draft receives a batch of topics with their current frontmatter, plus
`default_branch`, `branching_strategy`, `current_branch`, `shallow`,
`watch_paths` (Step-3-repaired), and `docs_dir` — all threaded from the
orchestrator, never re-detected. A `question_pass: true` or `rework: {...}`
flag switches to the corresponding narrower pipeline.

## Output Artifacts

`<docs_dir>/<name>.md` per topic, `<docs_dir>/.claims.yml` appended with
extracted claims, and a regenerated `<docs_dir>/STATUS.md`.

## Spec Sections Exercised

- **§1 two-tier structure** — case-001 (stub draft) verifies the exact 5-section
  skeleton plus TL;DR; case-002 (mature-topic enrichment) verifies a TL;DR is
  kept while free-form domain headings are preserved, and that human_sections
  prose is preserved verbatim (Safety Rule 2) while still being extendable.
- **Cross-cutting attribution** — case-001, case-002, and case-003 all exercise
  the `human_sections`/`inferred_sections` update via
  `human_sections_attribution` (credited slugs present, and none of them left
  behind in `inferred_sections`). The numeric
  `human_input = (credited slugs whose headings exist / total ## sections) x 100`
  assertion is **not** exercised by all three: case-002 sets
  `check_human_input_exact: false`, which disables that branch of the judge, so
  the formula itself is carried by case-001 and case-003 only.
- **§4 knowledge persistence** — case-001 checks claim extraction with
  block-YAML provenance and the immediate `decisions:` frontmatter write for a
  user-answered question; case-004 exercises Decision Drift Resolution's three
  outcomes (case seeds the "no longer relevant" path: tombstone `status:
  retired`, `resolved_at` stamped, claim removed to `_retired_ids`); case-005
  (rework mode) exercises claim re-extraction scoped to changed sections only.
- **Mode scoping** — case-003 (question-pass mode) verifies the single-question,
  no-source-read, `question_passes` increment, single-claim-extraction pipeline;
  case-005 (rework mode) verifies targeted-edit-only scope, `freshness: 100`
  stamped with `human_input`/`completeness` left untouched, and that no §6/§7
  questions are asked.
- **Present-state prose** — every case's `safety_rules_respected` judge scans
  for forbidden changelog language ("was added", "now supports", "previously",
  etc.) per the content standards.

## Deliberately Uncovered

- The **Standard Files block** (README/CONTRIBUTING/ARCHITECTURE/CLAUDE/GEMINI
  generation) is not exercised by any case here — it runs once per draft
  invocation across the whole batch, not per topic, and is better suited to a
  dedicated fixture than folding into the topic-level cases above. Tracked as a
  gap, not silently dropped.
- The **wrap-up pass** (queued non-critical questions from §5) is not covered —
  none of the cases produce a non-critical gap during drafting.
- **Structure Revision proposals** (splitting/merging topics) are not covered.
- **Multiple focus areas with independent budgets** (§7's parallel-budget rule)
  is not covered — case-003's question-pass mode explicitly does not read
  source files, so it can't exercise budget tracking either.
- The **Review Gate** at the end of SKILL.md is not covered: it follows the
  orchestrator's Step 9, which dispatches the `codebase-scribe:scribe-review`
  agent, and this suite's permission allowlist grants neither `Agent` nor
  `Skill`. Every case ships a `.scribe.yml` with `review.enabled: false` so
  Step 9 is skipped outright and the run terminates cleanly at the skill's own
  boundary rather than on an instruction it cannot carry out. Review behavior
  is covered by the scribe-review suite. Note the one side effect this config
  has inside the skill: §10's `review.enabled: false` branch resets
  `question_passes` on a full redraft (Question-Pass Mode → Settling), which is
  the intended behavior for that config and is not asserted against by any case
  here — case-003 is a question pass, which the reset rule excludes by name.

## Evaluation Notes

Files are written to disk, so judges use `outputs["files"]`, the full working
tree after the run. `annotations.yaml`'s `topic_name` and `docs_dir` fields let
judges locate the single topic file each case cares about without re-deriving
it from `input.yaml`. The `inputs.tools` hook answers `AskUserQuestion` calls
from `answers.yaml`, matching the convention from the pre-wave-6 suite.
