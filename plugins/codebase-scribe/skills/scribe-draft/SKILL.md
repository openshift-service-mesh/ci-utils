---
name: scribe-draft
description: Use when generating or enriching documentation content for approved topics. Reads source code within budgets, generates topic file content with interleaved SME questions, extracts claims, and calculates scores.
---

# Scribe Draft -- Phase 2

You are running Phase 2 (Draft & Enrich) of the codebase-scribe documentation system. Your job is to read source code, generate documentation content for topic files, ask the user about design decisions, and produce high-quality agentic docs.

Shared definitions — **Repo root = cwd**, **scribe-lib**, **Threaded fields**, **Maturity test**, **Option-count rule**, **No-HEAD rule**, **partial frontmatter updates** — live in `commands/codebase-scribe.md` § Definitions and apply here as written. **scribe-lib is a program you RUN, never a file you read:** `<python> <plugin-root>/scripts/scribe-lib.py <subcommand> ...` where `<python>` is the first working of `python3`/`python`/`py -3` and `<plugin-root>` is `$CLAUDE_PLUGIN_ROOT` when set, else this skill's own plugin directory (two levels up from this file). Every rule below that names a scribe-lib verb (`fm ...`, `claims ...`, `sections`, `human-input`, …) is executed by invoking it; each verb's `--help` is its contract. Every brief carries the Threaded fields: use the passed values, never re-detect or re-derive them. The repo being documented is ALWAYS the current working directory: every read of watch_paths and every write of topic files, `.claims.yml`, STATUS.md, and session state resolves against cwd — never against a plugin directory or any other project root visible in context.

## Safety Rules

1. Never modify AGENTS.md (topic-link appending is the command's job, not this skill's)
2. Never delete existing verified content in topic files -- only add to or update inferred sections. Sections listed in `human_sections` may be extended, but their existing prose must be preserved verbatim.
3. Always mark auto-generated sections in frontmatter `inferred_sections`
4. Respect file budgets: 30 files per topic (configurable via `.scribe.yml`)
5. When the session file count approaches 150, warn the user -- do not stop automatically

## Inputs

You receive from the orchestrator: the list of topics to work on (with current frontmatter state), whether this is SME/focus mode (with focus description and confirmed paths), any user-provided context string, current session progress, and the Threaded fields. Read `.scribe.yml` if it exists for budget and content settings.

## Rework Mode

When the brief contains `rework: true`, follow this targeted-edit pipeline instead of the Per-Topic Workflow. The brief carries: `iteration` (1 or 2), the current topic content, the critical findings (tag, location, evidence, suggestion), the source files cited in findings, and the Threaded fields.

1. **Parse findings.** Identify the section and content each finding requires correcting.
2. **Read cited source files only.** Not the full watch_paths — rework is scoped to the flagged issues.
3. **Apply targeted edits.** `MISSING_REF`: find the correct path (`git log --diff-filter=R` for renames, `find` for relocations) and update. `CONTRADICTION`: read the cited source, rewrite the statement to match the code. `INCONSISTENCY`: resolve toward the section that matches source. `WRONG_FILE`: correct the attribution. `DEPRECATED`: remove or replace with the current pattern.
4. **Preserve unaffected content.** Change only what the findings require.
5. **Skip all questions** (§5, §6, §7). Rework is mechanical correction.
6. **Freshness only.** `fm update <topic> --json '{"freshness": 100}'` — rework never advances `scan` (that is 9f's stamp, after re-review) and does NOT recalculate `human_input` or `completeness`. Under `main-only` when `current_branch` != `default_branch`, or under the No-HEAD rule, skip the call entirely. Rework never reaches §10, and the verb only touches what it names, so every other frontmatter key survives verbatim.
7. **Re-extract claims for changed sections** per §11's ID stability rules; preserve claims for unmodified sections.
8. **Validate output** per §12 — except `human_input` and `completeness`, which rework preserves (step 6); the `freshness` check still applies.
9. **Save session progress:** mark the topic `rework_pass_<iteration>` in session.json.

Rework does NOT: read full watch_paths, ask questions, recalculate human_input/completeness, propose splits, or run the wrap-up pass.

## Question-Pass Mode

When the brief contains `question_pass: true` (topics Step 5 classified `unverified`), follow this pipeline per topic:

1. **Ask the §6 question** — including its fallback — unless §6's zero-question rule fires.
2. **On an answer:** incorporate it per §6/§7's incorporation-target rule and credit it (HARD RULE 4's `fm credit-section` call). Extract the claim and write the `decisions:` entry at §11 timing.
3. **Run scribe-lib `fm question-pass <topic>` on every question pass over the topic** — answered, skipped, or zero-question (otherwise a conventional topic would classify `unverified` and invoke a no-op pass forever). The verb increments and persists the counter; content changes, if any, are written per §10.
4. Output flows through Step 9 (typically `claim_change`).

A stub's *first draft* asking the §6 question does NOT increment `question_passes` — the counter tracks question passes only, so a never-answering user sees up to **three** asks (one at draft, two passes).

Question-pass mode does NOT: read source files; regenerate sections; ask §5/§7 questions; process Standard Files; run HARD RULE 2's full extraction (single-claim only — HARD RULE 1's batch duty still applies, or the rest of the batch strands `unverified`); stamp `freshness`/`scan` (a question pass is neither draft nor rework — §8/§10's exclusion); recalculate `completeness` (nothing feeding the formula changed; `human_input` is the one score it recomputes, per step 2); clear `stale_flags` (§10's empty-`stale_flags` write is full-drafts-only — an `unverified` topic can hold a live `deleted`/`renamed`/`semantic` flag, and erasing it would drop a broken reference on the floor).

### Settling: Draft-Side Reset Fallback

9f normally settles `question_passes` on draft/rework. Two paths bypass 9f, so a normal draft or rework — never a question pass — runs scribe-lib `fm settle <topic>` directly: **`review.enabled: false`** (at §10's write) and **the 9b-skip path** (after Step 9 returns, for the skipped topic). The verb enforces 9f's condition (b): `question_passes == 2` with `human_input == 0` stays settled; anything else resets to 0.

## File Skipping Rules

Skip these files -- never read them, they don't count against your budget:
- **Vendored/dependency directories:** `vendor/`, `node_modules/`, `_output/`, `.build/`, `dist/`, `__pycache__/`
- **Lock files:** `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `go.sum`, `Gemfile.lock`, `poetry.lock`, `Cargo.lock`, `composer.lock`
- **Known boilerplate output:** files with headers from `protoc`, `swagger-codegen`, `openapi-generator`, `wire`, `mockgen`, `stringer`, `go generate`, gRPC codegen
- **Explicitly machine-maintained:** files marked `DO NOT EDIT`

Files generated by AI coding agents (Claude Code, Copilot, etc.) are NOT skipped -- they are real application code.

## HARD RULES

1. **Process all topics in your batch.** Do not stop after one topic; continue until all are done or the session budget is reached. The one exception: a topic whose decision-drift prompt the user skipped is passed over undrafted (see Decision Drift Resolution) — continue to the next.
2. **ALWAYS extract claims.** Immediately after writing each topic file (per-topic, never deferred to a batch step), extract up to 15–20 claims, proportional — do not pad small topics.
3. **Propose splits for long topics.** Over 500 lines (or `content.split_threshold`): "This topic is [N] lines. I recommend splitting into [topic-overview.md] and [topic-detail.md]. Proceed?" Never silently generate past the threshold.
4. **ALWAYS credit incorporated user answers — via scribe-lib `fm credit-section <topic> <slug>`, never by hand.** One call adds the receiving section's top-level slug to `human_sections`, removes it from `inferred_sections`, and recomputes `human_input`. Top-level parent only, never subsection slugs; the verb has set semantics, so repeat credits cannot inflate the score.
5. **Finish within this invocation.** The skill is done only when every mandated write is on disk — topic content, frontmatter verbs, claims, session state. NEVER end after planning: a task list may mirror progress, but it is never a substitute for executing the steps before your final message. There is no later turn; whatever is not done when you stop was not done.

## Decision Drift Resolution

If the orchestrator flags a topic with `decision_drift` stale flags, present each flagged decision before drafting:

> "A previous decision was flagged: '[claim]'. The code has changed since ([file] modified). Is this decision still valid?"

Options via AskUserQuestion: 1. "Still valid — refresh the recorded date" 2. "No longer relevant — retire this decision" (plus "Other" for updated reasoning).

Each outcome runs one scribe-lib verb (which updates the frontmatter entry and `.claims.yml` together, atomically), then handles topic content, then removes the stale flag via `fm remove-stale-flag`. Every outcome passes `--resolved-at <current HEAD>` — what lets maintain §4 stop re-flagging a resolved decision — **except** when HEAD cannot be read (this section is reachable then; a flag from an earlier git-available run survives): omit the flag entirely, and the verb writes no `resolved_at` — maintain §4's base selection falls back to `scan`, failing toward re-detection.

- **Option 1 (still valid):** `fm refresh-decision <topic> <id> --claims <docs_dir>/.claims.yml --recorded <today> --resolved-at <HEAD>` (updates the entry and the claim's provenance in one call); remove the stale flag.
- **"Other" (updated reasoning):** the same `refresh-decision` call plus `--context "<the user's reasoning>"`; update the topic content; the updated reasoning is an incorporated user answer, so HARD RULE 4's `fm credit-section` call applies — under `questions: false` this is the only path that can raise `human_input`; remove the stale flag.
- **Option 2 (retire):** `fm retire-decision <topic> <id> --claims <docs_dir>/.claims.yml --resolved-at <HEAD>` — one call sets the tombstone (`status: retired`, skipped by maintain §6 re-linking and §4 drift detection), removes the claim, and reserves the ID in `_retired_ids`. Then remove related topic content — **except prose in a `human_sections` section, which is preserved per Safety Rule 2: the claim removal already happened; leave the prose untouched** — and remove the stale flag. The tombstone survives on every path; no outcome deletes a `decisions:` entry; no path deletes credited human prose, so `human_sections` and `human_input` are untouched by this outcome.

**If the user skips a prompt** (dismisses without choosing and without "Other" text), the flag stays exactly as it is — a skip is "ask me again", never "resolved". For that topic:
- **Do not draft it this run.** None of §8/§10/§11/§12 runs for it; `scan` and `freshness` keep their stored values. This is HARD RULE 1's exception: move to the next topic.
- **Outcomes already recorded for its other flags stand** — none of them stamps `scan`/`freshness`, so skipping the draft costs them nothing. The surviving flag keeps the topic classified `decision_drift` next run; only it is re-asked.
- **Record `phase_status: pending`** in session.json (§13) and report it in the Step 13 summary: not drafted because a prompt was left unanswered; it will be asked again.

After resolving all of a topic's flags, proceed with the Per-Topic Workflow for it.

## Per-Topic Workflow

Process ALL pending topics sequentially. For each topic:

### 1. Identify Relevant Files

Using the topic's `watch_paths` (from the brief):
- List all source files in those paths (excluding skipped files)
- Prioritize: entry points → files with most cross-references → most recently changed
- Select up to 30 files (or `budgets.files_per_topic`)
- **Minimum read requirement:** at least 8 source files, or ALL if fewer exist. Even with migration content available, source files are the ground truth.

Track `total_files_read` in session.json after each topic. Approaching 150 (or `budgets.files_per_session`): "I've read [N] files so far this session across [M] topics. [K] topics remain. Continue?"

**Multiple focus areas:** each area gets its own independent 30-file budget, tracked separately. Files read for a previous area are available context (don't re-read) and do NOT count against the current area's budget. The session budget (150) is the outer soft limit.

### 2. Read and Analyze Code

Read each selected file fully. For files over 500 lines, index exported symbols and doc comments first -- generated docs must reference specific functions and types, not vague descriptions.

Also read: existing documentation covering this area (READMEs, guides, existing CLAUDE.md sections) and the existing topic file content (if enriching).

### 3. Generate Topic File Content

**When updating a drifted topic (not a stub):** you are rewriting sections to match current code — not writing a changelog. Read the diff to understand what changed, then write the section as a description of the current state. A reader should have no idea whether a section was written fresh or updated.

**Handling migrated topics** (frontmatter has `migration_source` and `migration_sections`):
1. Read the `migration_source` file and the listed sections
2. Use that human-written content as context alongside your code analysis — it does NOT count against the file budget, and the 8-file minimum still applies
3. **Independently verify migration claims:** check each concrete reference (paths, functions, commands, technology choices) against current code; flag mismatches: "Migration content references [X] but the current code shows [Y]. Using current code."
4. Write the topic per the tier rules below, integrating verified migration knowledge
5. After writing, consume the migration keys: scribe-lib `fm update <topic> --json '{}' --unset migration_source,migration_sections`
6. If >20% of the referenced migration content (by line count) wasn't incorporated, flag it: "Some content from the original AGENTS.md was not incorporated. Review the original at `[migration_source]` — sections: [list]."

**Redraft vs. stub draft:** when the brief's `tier` is `mature`, preserve the existing top-level heading set and rewrite section bodies in place — `human_sections` sections may be extended but their prose is preserved verbatim (Safety Rule 2) — adding a TL;DR and a `## Links` section only if absent. The 5-section skeleton applies to stub drafts only.

When the brief's `tier` is `stub`, write:

```markdown
# [Topic Name]

> [Relevance routing -- 1-2 sentences: what this doc covers and what it doesn't.
> Direct agents elsewhere if this isn't what they need.]

## Key Entry Points
- [file path]: [what it does]
- [command]: [what it does]
- [config file]: [what it configures]

## Patterns & Conventions
[What to follow when writing new code in this area. Reference specific
files, functions, patterns. Be concrete: "error handling wraps with
fmt.Errorf in pkg/business/" not "standard error handling."]

## Gotchas
[What will bite you if you don't know: implicit ordering dependencies,
required environment variables, files that must not be modified,
common mistakes and how to avoid them]

## Dependencies & Context
[Deeper understanding: frameworks, design choices, history. Why things
are the way they are, what constraints exist, what alternatives were
considered.]

## Links
- [Related topic file](other-topic.md) -- [why it's relevant]
- [External doc](URL) -- [what it covers]
- [Source file](path) -- [key file for this area]
```

**Content standards:**
- **Every topic MUST start with a blockquote TL;DR** (first content after the `#` heading) for relevance routing.
- **Stub drafts have exactly these 5 sections** — a floor and a ceiling, matching §12. A section with nothing to say gets one line explaining why ("No known gotchas for this area yet."), never omitted.
- **Concrete over abstract:** actual file paths, function names, commands.
- **Citations: `symbol in file`, never bare line numbers** — line numbers drift; symbol names are stable anchors.
- **Volatile inventories: describe where they live; never enumerate** — unless review mechanically re-verifies the enumeration every run. Routes, CLI flags, config keys: point to where the current list lives.
- **Present state only — no changelog language.** Forbidden: "was updated", "now supports", "was added", "formerly", "previously", "changed from X to Y", "gained a", "was renamed", "is now". Rewrite changed sections as if the current state had always been true; git history is the changelog.
- **Target 200-400 lines.** Over 500 (or `content.split_threshold`): propose a split. Over 800: hard split — propose overview + deep-dive subtopics.

### 4. Track Inferred Sections

Every section you generate gets added to `inferred_sections` — **except a top-level section whose slug is currently in `human_sections`**: regenerating or extending it does not revoke human credit, so leave that top-level entry out (re-adding it would undo HARD RULE 4's removal). Subsection entries beneath it are added normally. Replacing a credited section's human prose is a Safety Rule 2 violation, never a branch: restore the prior prose and leave `human_sections` as it was — do not strip the credit to normalize the violation. Incorporating a *new* answer into the section is HARD RULE 4's business, not this exception's.

Slugs come from scribe-lib (`slug`, or `sections --level all` for the whole file); subsection slugs are parent-scoped (`patterns--conventions/error-handling`). Store entries as `{id, heading}`:

```yaml
inferred_sections:
  - id: key-entry-points
    heading: "## Key Entry Points"
  - id: patterns--conventions/error-handling
    heading: "### Error Handling"
```

### 5. Critical Gap Check (Interleaved Questions)

**Skipped entirely when `questions: false`.**

After drafting each topic: are there gaps where the answer would materially change content in OTHER topic files? **Critical gap** (affects multiple topics): ask now, 1-2 questions max — "While documenting [area], I found [observation]. This affects how I document [other topics]. Can you clarify: [question]?" **Non-critical gap** (affects only this topic): queue for the wrap-up pass.

### 6. Design Decision Prompt

**Skipped entirely when `questions: false`.**

**Ask exactly one question per topic, unless the zero-question rule applies.** Pick the most significant architectural choice whose "why" is least obvious from the code. **Fallback:** the most significant technology or dependency choice ("Why gorilla/mux over chi?"). **Zero-question rule:** if even the fallback turns up only a conventional choice — a standard pattern, an obvious idiom, a routine dependency — ask nothing and skip this step.

Otherwise, via AskUserQuestion: "While documenting [topic], I noticed [specific observation]. Why this approach?" Options: 1. "No special reason / convention" 2. "I'll explain later in focus mode" (plus "Other" for free text).

**On an explanation:** incorporate it, appending to `Dependencies & Context` or `Gotchas`; if neither exists, the last `##` section; if none, create `## Dependencies & Context`. Apply HARD RULE 4. This step records the answer only — the `decisions:` entry is written at §11, after the claim gets its id. The claim (at §11) carries `provenance: {origin: user, context: "<answer>", recorded: "<today>"}`.

**On a skip:** move on, no friction.

**Ask about** choices, constraints, boundaries, absences ("Why no retry logic here?"). **Never about** standard patterns, conventional picks, obvious idioms — and never "what does X do" (the code answers that).

This first-draft question does not increment `question_passes` (see Question-Pass Mode — the ask ceiling for a never-answering user is three).

### 7. Observation-Driven Questioning (Focus Mode)

**Skipped entirely when `questions: false`.**

In focus/SME mode, identify 3-5 non-obvious patterns in the code just read. **Ask them sequentially** — one AskUserQuestion at a time, never batched or parallel. Question types: technology choices, unusual patterns ("breaks the convention used in [other area] — intentional?"), constraints (hardcoded values), boundaries, absences. **Follow-up cap:** max 1 per answered question. **Budget:** at most 10 interactions per topic (5 questions + 5 follow-ups); typical is 6-8.

Incorporate answers exactly as §6 does (same incorporation target, HARD RULE 4, claim provenance at §11).

### 8. Calculate Scores

- **Freshness:** always `100` — content was just generated from current code. Exclusions, exhaustive: under `main-only` when `current_branch` != `default_branch`; in a question pass; under the No-HEAD rule (which also governs `scan`). Where excluded, carry the stored value through.
- **Human Input:** scribe-lib `human-input` — (`human_sections` slugs whose `##` heading exists / total fence-aware `##` sections) × 100, 0 with zero sections. No special zero-rule: an empty list yields 0.
- **Completeness:** scribe-lib `completeness` — (depth-1 watch_path subdirectories with ≥1 file referenced in the doc / total) × 100, 0 with no subdirectories. In a question pass, carry the existing value through.

### 10. Write Topic File

Write the markdown content per §3, leaving the existing frontmatter block byte-identical in the same write. Then apply the frontmatter changes through scribe-lib, never by editing the YAML:
- `fm update <topic> --json '{"human_input": <§8>, "completeness": <§8>, "inferred_sections": [<§4>], "watch_paths": [<the brief's repaired value — never narrowed by draft>], "stale_flags": []}'` — the empty `stale_flags` on full drafts only; a question pass omits that key and carries existing flags through
- `fm stamp <topic> --scan <HEAD> --freshness 100` — only on the default branch under `main-only`, never in a question pass, and subject to the No-HEAD rule (skip the call entirely when excluded; §8's exclusions list is exhaustive)

**Preservation clause (canonical list):** `fm update` touches only the keys its `--json`/`--unset` name — so every other key survives verbatim by construction: `decisions`, `question_passes`, `human_sections`, `review_notes`, and any other keys present (HARD RULE 4's `credit-section` is `human_sections`' named writer).

If `review.enabled: false` **and this is a full draft — never a question pass**, apply the Settling reset here. A question pass reaches §10 too (its counter already persisted by `fm question-pass`); resetting would undo that increment and re-open the same question forever.

### 11. Extract Claims

Immediately after writing each topic file, extract factual claims (up to 15–20, proportional) while the content is fresh — never deferred — and write them with scribe-lib:

```
claims add --claims <docs_dir>/.claims.yml --topic <topic-slug> --json '[<claim objects, no ids>]' --reserved <every id in this topic's frontmatter decisions:, active and retired>
claims set-meta --claims <docs_dir>/.claims.yml --topic <topic-slug> --sha <current HEAD>
```

The verb creates the file when absent (extraction is never conditional on the file existing — the first drafted topic in a repo creates it), enforces ID stability (exact `{type, topic}` + first-50-chars match keeps the existing ID), and assigns new sequential `<topic-slug>-<N>` ids skipping `_retired_ids` and everything in `--reserved` — never reusing a retired ID.

Types (only these five): `technology`, `pattern`, `data_flow`, `boundary`, `constraint`.

**Provenance** (block YAML, never inline): code-inferred claims get `origin: inferred`; claims from user answers (§6/§7) get `origin: user` with `context` and `recorded`. Claims missing `provenance` default to `origin: inferred` for all purposes.

```yaml
claims:
  - id: backend-architecture-12
    type: technology
    topic: backend-architecture
    claim: "PostgreSQL chosen over MongoDB for ACID support"
    source: "internal/store/postgres.go"
    provenance:
      origin: user
      context: "MongoDB rejected for lack of ACID; SQLite rejected for no vector search"
      recorded: "2026-05-04"
```

**Write the `decisions:` entry:** immediately after a `origin: user` claim is extracted and assigned its id (from `claims add`'s output), read the current list with `fm read <topic>`, append/update the entry whose `id` equals the claim's — a `status: retired` entry is never updated or reactivated — and write it back with `fm update <topic> --json '{"decisions": [<full list>]}'`. This is where the entry is written; §6/§7 only record the answer. The entry mirrors the claim's `id`/`type`/`claim`/`source` and the provenance's `context`/`recorded`, with `status: active`.

(Claim deletion and ID retirement happen only through `fm retire-decision` — see Decision Drift Resolution.)

### 12. Validate Output

After writing each topic and extracting claims:
- [ ] Structure check, branched on the brief's `tier` — what the topic was **at the start of this draft**, never re-derived now (§10 already wrote the file, so a just-drafted stub no longer carries its marker and would wrongly take the mature branch): entered-as-stub → exactly the 5 skeleton `##` headings plus TL;DR; entered-mature → TL;DR present, free-form domain headings legitimate
- [ ] `freshness: 100` unless a §8 exclusion applied — then the carried-through value is correct as-is, not a defect to "fix"
- [ ] `human_input` and `completeness` are calculated (scribe-lib), not estimated — both carried through unchanged in a question pass
- [ ] Claims written to `.claims.yml` for this topic
- [ ] TL;DR blockquote is the first content after the `#` heading
- [ ] If a design decision was answered: answer incorporated, HARD RULE 4 applied

Fix any failure before moving to the next topic.

### 13. Save Session Progress

Update `.scribe/session.json`: this topic `complete`, files-read count. A topic passed over for an unanswered decision-drift prompt is recorded `pending` instead.

## After All Topics

### Wrap-Up Pass

**Skipped entirely when `questions: false`** (nothing was queued — §5 was skipped).

Present all queued non-critical questions. Document answers into the relevant topics using §6's incorporation-target rule, then credit each answered section with `fm credit-section <topic> <slug>` — one call per section, doing the slug add, the `inferred_sections` removal, and the `human_input` recompute (named here because this pass reaches the file after §10, not through it).

### Regenerate STATUS.md

Full overwrite of `STATUS.md` in docs_dir: read all topic frontmatter and `.claims.yml`; write the topic table (Topic, Fresh, Human, Complete, Claims, File), stale flags, contradictions, review notes.

### Structure Revision

If analysis showed the topic structure was wrong (e.g., a `services/` directory isn't independent services), propose: "During analysis I found [observation]. I recommend merging `services.md` into `architecture.md`. Proceed?"

## Standard Files

After all topics are processed and STATUS.md is regenerated — once per draft invocation, not per topic; skipped entirely in a question pass — check the repo's standard files: read `references/standard-files.md` (relative to this skill's directory) with the Read tool and follow it exactly — do not act on this block from memory. It defines the per-file classification (Step A), the generation prompts per the Option-count rule (Step B), the five file templates (Step C), and outcome recording for the orchestrator's Step 13 summary (Step D).


### Review Gate

Skip this section in rework mode (the orchestrator handles scoped re-review via 9d). Otherwise, **after all topics in this batch are drafted, STATUS.md regenerated, and Standard Files processed (Standard Files skipped entirely in a question pass)**: follow Step 9 (Review Orchestration) in `commands/codebase-scribe.md` for every topic modified in this pass, and return to the orchestrator only after it completes for all of them.

For any topic where the user chose 9b-skip, apply the Settling reset (Question-Pass Mode).
