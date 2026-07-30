---
skill: scribe-discover
analyzed_at: 2026-07-27T00:00:00Z
skill_hash: regenerated-wave-6
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - stub_frontmatter_valid
  - stub_skeleton_complete
  - no_codebase_leakage
  - collision_refusal
  - agents_and_status
  - no_output_outside_docs_dir
  - stub_contract_quality
---

# scribe-discover Analysis

## Purpose

`scribe-discover` is the mechanical stub creator in the `codebase-scribe` pipeline
(spec §5). It does not scan the codebase, does not propose topics, and does not
make decisions — the orchestrator (`commands/codebase-scribe.md` Step 2) already
scanned the repo and got user approval for the topic list. Discover's entire job
is: given an approved topic list and a resolved `docs_dir`, create one stub file
per topic with a fixed frontmatter shape and a fixed five-section skeleton, then
regenerate `STATUS.md`.

## Inputs

Discover receives a brief from the orchestrator (never re-detected):
- `docs_dir` — resolved once in Phase 0 (default `docs/agents`)
- `topics` — list of `{name, title, watch_paths, migration_source?, migration_sections?}`

It does not read `.scribe.yml`, does not scan the distractor source tree
(`internal/`), and does not read `AGENTS.md` even when present.

## Output Artifacts

One `<docs_dir>/<name>.md` per topic (see eval.yaml's outputs schema for the exact
frontmatter and skeleton shape) plus a regenerated `<docs_dir>/STATUS.md`.

## Key Behavioral Constraints (HARD RULES)

1. Stubs only — zero real content beyond the fixed template.
2. Never touch `AGENTS.md`.
3. Never scan the codebase — topics and watch_paths come from the orchestrator.
4. Never propose topics.
5. Never overwrite an existing topic file — refuse, create the rest, report the
   colliding names back.

## Spec Sections Exercised

- **§5 stub contract** — every case's `stub_frontmatter_valid` and
  `stub_skeleton_complete` judges check the exact frontmatter (scan null, all
  scores 0, empty inferred_sections/stale_flags) and the exact five-section
  skeleton, each section carrying the placeholder marker. The skeleton judge
  asserts the complete literal `*Stub — will be populated by the draft skill.*`
  (em dash, U+2014) in every required section, so an altered instruction after
  the prefix fails rather than passing unasserted.
- **§5 collision refusal** — case-004 seeds a pre-existing topic file; the
  `collision_refusal` judge compares the post-run file against
  `annotations.preexisting_content` for identity (line endings normalized), and
  separately requires its `annotations.preexisting_markers` substring to survive
  and the fresh-stub placeholder marker to be absent, with every non-colliding
  topic in the batch still created. Identity is what catches an append or a
  rewrite that keeps the marker; a collision named without a
  `preexisting_content` entry fails the judge rather than skipping it.
- **§5 docs_dir threading, both halves** — case-003 uses a non-default
  `docs_dir`, and the `stub_frontmatter_valid`/`stub_skeleton_complete`/
  `agents_and_status` path lookups key off `annotations.expected_docs_dir`, so
  they only pass if discover wrote the stubs under that directory. The negative
  half is `no_output_outside_docs_dir`: every created topic file, STATUS.md, and
  any file carrying the fresh-stub marker must sit beneath that directory, so a
  run that writes correctly under `docs/ai` and *also* drops stubs at the default
  `docs/agents` fails instead of staying green.
- **HARD RULE 3 (no scanning)** — cases 001, 002, 003 and 005 include a distractor
  `internal/` source tree with a distinctive identifier; `no_codebase_leakage`
  fails if that identifier appears in a stub body. Case-004 (collision refusal)
  ships no `internal/` tree but still contributes: its `forbidden_leakage_strings` names
  `OrbitalCacheWarmer`, the identifier from the *pre-existing* topic file it
  collides on, so the rule additionally proves that a refused topic's content
  does not bleed into the stubs discover does create.
- **HARD RULE 2 (AGENTS.md untouched)** — `agents_and_status` compares the
  post-run `AGENTS.md` against `annotations.preexisting_agents_content` for
  byte identity (line endings normalized), and separately requires the file to
  still be present and to still carry
  `annotations.preexisting_agents_marker`. An identity comparison catches an
  append and a deletion, not only an overwrite — the two weaker forms it
  replaced each passed a regression: the marker check ran only `if agents_key`,
  so deleting the file satisfied it silently, and marker survival permitted
  arbitrary content appended below it.

## Deliberately Uncovered

- Two **separate** orchestrator routes call discover, and only one of them is
  anywhere near this suite. The **focus-mode route** is Step 6d: focus discovery
  confirms an area no topic covers, and calls discover for the new topic —
  that is the call shape case-005's single-topic batch exercises at the
  discover-call boundary, though Step 6's focus-matching logic upstream of it is
  out of scope for a skill-level suite. The **uncovered-modules route** is a
  different one — Step 8 row 7 re-enters Step 2, which proposes topics, takes
  AskUserQuestion approval, and calls discover at 2d — and nothing here
  exercises it; from discover's side it arrives as an ordinary approved topic
  list. Both routes belong to a command-level eval, which does not exist yet.
- `.scribe.yml`-driven config (e.g. a custom stub template) is out of scope:
  discover has no config-reading behavior to test — it is intentionally
  config-blind per HARD RULE 3's "the orchestrator already did that."
## Evaluation Notes

Files are written to disk, so judges use `outputs["files"]`, which reflects the
full working tree after the run (both newly created and untouched pre-existing
files) — this is what lets `collision_refusal` check a colliding file's
post-run content against the marker its fixture seeded. The dataset
intentionally includes a distractor source tree in every case except case-004
so the "never scan" rule has something concrete to violate if the skill
regresses toward the old discovery-based architecture.
