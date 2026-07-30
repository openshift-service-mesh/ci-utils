---
name: scribe-maintain
description: Use when all documentation topics are current or lightly drifted. Detects mechanical and decision drift, auto-fixes broken references, flags stale content for review, validates cross-topic consistency, and recalculates scores. Semantic drift evaluation is handled by the review subagent.
---

# Scribe Maintain — Phase 3

You are running Phase 3 (Maintain) of the codebase-scribe documentation system. Your job is to detect drift between documentation and code, auto-fix mechanical issues, flag major drift and decision drift for review, check cross-topic consistency, and recalculate scores. Semantic drift evaluation belongs to the review subagent (scribe-review).

Shared definitions — **Repo root = cwd**, **scribe-lib**, **Threaded fields**, **Maturity test**, **No-HEAD rule**, **partial frontmatter updates** — live in `commands/codebase-scribe.md` § Definitions and apply here as written. **scribe-lib is a program you RUN, never a file you read:** `<python> <plugin-root>/scripts/scribe-lib.py <subcommand> ...` where `<python>` is the first working of `python3`/`python`/`py -3` and `<plugin-root>` is `$CLAUDE_PLUGIN_ROOT` when set, else this skill's own plugin directory (two levels up from this file). Every brief carries the Threaded fields: use the passed values, never re-derive them. The repo being maintained is ALWAYS the current working directory: every reference check and every frontmatter or STATUS.md write resolves against cwd — never against a plugin directory or any other project root visible in context.

## Safety Rules

1. **Mechanical drift:** auto-fix broken file paths and function names; always summarize what changed.
2. **Semantic drift:** not evaluated here — maintain only flags major churn for review.
3. **Deletions are always semantic:** a deleted referenced file or function is flagged, never silently removed.
4. Never modify AGENTS.md.
5. Never delete content from topic files — only update references and frontmatter.
6. **Every frontmatter write here is a partial update** — §3 and §4 add stale flags, §5 demotes them, §8 rewrites scores, §9 sets `completeness: 0`; each changes only the keys its own section names. draft §10's preservation clause is the canonical list.

## Inputs

From the orchestrator: all topics with current frontmatter; per-topic drift classification (one of Step 5's categories — only `current` scopes anything here, §§1–2; every other value behaves identically); topics with changed watch_paths; and the Threaded fields. Read `.scribe.yml` for drift sensitivity settings.

## Drift Sensitivity

`drift.sensitivity` → thresholds: `low`: minor = 20% of watched files changed, major = 50%; `medium` (default): 10% / 30%; `high`: 5% / 15%.

## Per-Topic Maintenance

Run for **every** topic the orchestrator passed, including topics classified `current`. Drift classification scopes §§1–2 and nothing else — this is load-bearing: `All current` (Step 8 row 9) is the only normal route into this skill, so skipping current topics would make §7, §8, and §10 unreachable on every ordinary maintain run.

### 1. Scope the Diff

Skipped for a topic classified `current` (its watch_paths haven't changed since `scan`, so there is no churn to scope; §3 still validates its references). Skipped entirely when `shallow` is true. If scribe-lib `validate-sha` fails for `scan_sha`, report full churn without running the diff.

Otherwise: `git diff --stat <scan_sha>..HEAD -- <watch_paths>`; churn = (files changed / total files in watch_paths) × 100.

### 2. Apply Drift Table

Skipped in a shallow clone and for `current` topics (no §1 input either way). `_meta.<topic>_extracted_at` needs no SHA guard — equality-only; mismatch → re-extract, the safe direction.

| Watch paths changed? | References valid? | Action |
|---|---|---|
| No | Yes | **Skip.** Stable and correct. Zero prompts. |
| No | No | Mechanical drift: auto-fix if possible, flag deletions. |
| Yes, minor (< minor threshold) | Yes | Light check: skim the diff summary; usually no action. |
| Yes, minor | No | Mechanical drift: auto-fix broken references. |
| Yes, major (> major threshold) | Either | Major drift: flag for review (semantic evaluation is the review subagent's). |

### 3. Reference Validation

For each topic file, extract all file path and function/type name references. Check:
- **File paths:** resolve first — a Markdown link destination (not a URL or bare `#anchor`) is relative to the topic file's directory (`<docs_dir>/<dest>`, `../` normalized); an inline path in backticks or prose is repository-relative. Then confirm the resolved path exists. Testing a link destination verbatim from the project root would auto-fix a correct link.
- **Function names:** search the bare symbol (`grep -rn "<name>" <watch_paths>`), never a Go-shaped declaration pattern alone — this plugin documents many languages, and `export function <name>()` matches no `func <name>` pattern. A hit is not yet valid: confirm the name is a *declaration* in that file's own language, per the rule in `agents/scribe-review.md` Pass 1 check 2. Absent entirely, or present only at call sites → broken reference. Both halves matter: a false "missing" auto-fixes a working reference; a false "valid" quietly subtracts from §9's 60% ratio.

For broken references:
- If `shallow`: skip the rename check — renames are indistinguishable from deletions in a shallow clone. Report the broken reference without a deletion flag (no `reason: "deleted"`); §9's escalation is skipped for these references.
- Otherwise `git log --diff-filter=R -- <old_path>`. Renamed → auto-fix the reference, add a stale flag with `reason: "renamed"` (draft's question-pass mode counts on that flag existing), note in summary. Deleted → add a stale flag:

```yaml
stale_flags:
  - id: <section-slug>
    heading: "<section heading>"
    flagged_at_sha: <current HEAD>
    reason: "<short category>"
    detail: "<specific explanation>"
```

Reasons: `"deleted"`, `"renamed"` (auto-fixed but flagged), `"semantic"`, `"escalated"` (60%+ broken references, needs full redraft).

### 4. Decision Drift Detection

Skipped in a shallow clone. If a topic's `scan_sha` fails validation, skip this diff-derived branch for its decision entries rather than flagging them.

For each frontmatter `decisions:` entry with `status: active` (no `status` = `active`):

0. **Base selection (guarded stored-SHA consumer):** the diff base is the entry's `resolved_at` when it is present, passes scribe-lib `validate-sha`, AND is a descendant of `scan` (`git merge-base --is-ancestor <scan_sha> <resolved_at>` — an ancestry test, not a max comparison). Otherwise the base is `scan_sha`; a failing `resolved_at` is ignored — fail toward re-detection.
1. `git diff --stat <base>..HEAD -- <source_file>`.
2. Changed by more than `drift.decision_lines_threshold` lines (default 5)? Then check the diff hunks for key terms from the claim text.
3. Both conditions met → the decision may be outdated; add a stale flag with `reason: "decision_drift"`, `id: decision-<claim-id>`, `heading: "<section where the claim appears>"`, `flagged_at_sha: <current HEAD>`, and a `detail` naming the claim, its recorded date, and the changed file.

**Deduplication:** multiple active entries referencing the same changed file within one topic get ONE flag listing all affected claims in `detail`. **Retired entries are never re-flagged.**

Summary line: "N decision drift flag(s) raised. These will be addressed in the next draft or focus run."

### 5. Stale Flag Lifecycle

Skipped in a shallow clone. If a flag's `flagged_at_sha` fails validation, leave the flag active without recalculating.

For existing flags: commit distance = `git rev-list --count <flagged_at_sha>..HEAD`; watch-path churn since the flag = `git diff --stat <flagged_at_sha>..HEAD -- <watch_paths>`. **Demote to known stale** when distance > `stale_commit_threshold` (default 50) AND watch_paths unchanged in those commits. **Keep active** while watch_paths are still changing. Surface active flags: "These sections may be outdated: [list]".

### 6. Cross-Topic Consistency

**Reference consistency:** when two topics reference the same file or function, check they describe it consistently; flag inconsistencies.

**Claim consistency:** read `.claims.yml`. Per topic: zero claims → extract them now (catches topics drafted before claim extraction existed). Topic file SHA differs from `_meta.<topic>_extracted_at` → re-extract. `.claims.yml` missing → re-extract all.

**Re-extraction** (up to 15–20 claims, proportional, five types): read existing `.claims.yml` first; preserve IDs for claims matching by exact `{type, topic}` + first-50-chars; new IDs skip `_retired_ids` and every id in that topic's `decisions:` (active and retired) — unguarded, a reworded decision claim could orphan its id, maintain could hand it to a new claim, and a later re-link would duplicate it. Preserve existing `provenance` — never overwrite user provenance with inferred.

**Re-linking, by content:** each re-extracted claim that did NOT match by ID stability (and would get a fresh ID, losing provenance) is checked against the topic's `status: active` `decisions:` entries on `{type, topic, first-50-chars}`. On a match: restore the entry's provenance onto the claim, and the claim takes the entry's `id`. Uniqueness, both guards: **many-to-one** — only the claim first in `.claims.yml` document order binds; **one-to-many** — binds none, reported in §13. Accepted residual: a claim reworded past this content match becomes a plain new inferred claim, no further fallback. After re-linking, report `active` decisions that matched no claim ("unmatched active decisions").

Claims missing `provenance` default to `{origin: inferred}`. Claims without an `id` get one on first read.

**Always run contradiction checking**, even with no re-extraction: compare ALL claims across ALL topics; contradictions go to `.claims.yml`:

```yaml
contradictions:
  - topic_a: architecture
    claim_a: {id: arch-grpc, claim: "gRPC for internal services"}
    topic_b: patterns
    claim_b: {id: pat-http, claim: "HTTP client wrapper for service calls"}
```

### 7. Quality Checks

On every maintain pass:

**Structural validation:** flag a missing TL;DR blockquote on any topic. On `stub`-tier topics (the brief's `tier`; fallback when absent: scribe-lib `tier`), additionally flag any missing skeleton section (`Key Entry Points`, `Patterns & Conventions`, `Gotchas`, `Dependencies & Context`, `Links`). On mature topics, an advisory note for a missing `## Links`. Flag only — maintain never adds content.

**Actionability:** a section over 5 prose lines with zero code references → "Section '[heading]' in [topic].md has no concrete code references. Consider enriching it with specific file paths and commands."

**Content length:** over 500 lines (or `content.split_threshold`) → propose a split.

**Structural diff:** a significant top-level directory covered by no topic's watch_paths → "Directory `X` exists but isn't covered by any documentation topic. Consider running `/codebase-scribe` to add a topic for it."

### 8. Recalculate Scores

- **Freshness:** skip the recalculation (leave the stored value) when: shallow clone; `scan_sha` fails validation; or HEAD cannot be read (No-HEAD rule — a full clone with a valid `scan` still has nothing to diff against without git). Otherwise: `git diff --stat <scan_sha>..HEAD -- <watch_paths>`; freshness = (unchanged files / total files in watch_paths) × 100; hold the prior value when watch_paths contain no files. Under `main-only` when `current_branch` != `default_branch`, do not update `freshness` or `scan`.
- **Human Input:** scribe-lib `human-input` — not diff-derived; always runs.
- **Completeness:** scribe-lib `completeness` — not diff-derived; always runs.

Update scores in frontmatter (freshness left at its prior value where skipped).

### 9. Escalation

Subject to §3's shallow-clone exclusion: references reported without a deletion flag are not evaluated against this threshold — §3's bullet owns that rule.

If a section has 60%+ of its referenced files no longer existing: "Section '[heading]' in [topic].md has 60%+ broken references. This section needs a full redraft. Recommend running `/codebase-scribe` again to regenerate it." Then, so the orchestrator routes the topic to Phase 2 next run:
1. Set `completeness: 0` (paired with the flag below, this triggers Step 5's `escalated` row)
2. Add a stale flag: `id: <topic-slug>`, `heading: "# <topic title>"`, `flagged_at_sha: <current HEAD>`, `reason: "escalated"`, `detail: "60%+ broken references in section '[heading]', needs full redraft"`
3. Session state: `phase_status: "needs_redraft"`

### 10. Regenerate STATUS.md

Full overwrite in docs_dir: topic table (Topic, Fresh, Human, Complete, Claims, File) from frontmatter, stale flags, contradictions (from `.claims.yml`), review notes.

### 11. Standard Files Maintenance

Once per maintain invocation, after all topic maintenance: check `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md` at the repo root. Missing → note in summary, do not create (creation is draft's).

**README.md / CONTRIBUTING.md** — mechanical drift only, never rewrite prose:
- **Broken links** to docs_dir files: renamed → auto-fix and note; deleted → flag.
- **Stale commands:** a shown command no longer in the build files → flag for human review, never auto-fix (intent may have changed).
- **Missing topic links:** new topic files not linked from README → note as candidates.

**ARCHITECTURE.md** (pure navigation index): auto-fix renamed links, flag deleted; auto-add missing topics (TL;DR as description); refresh a description line whose topic TL;DR changed.

Report in the §13 summary: checked / auto-fixed / flagged.

### 12. Review Gate

**After all maintenance checks, STATUS.md regeneration, and Standard Files Maintenance:** follow Step 9 (Review Orchestration) in `commands/codebase-scribe.md` for every topic modified in this pass; only after it completes for all of them, print the §13 summary and return to the orchestrator.

### 13. Summary

Print every line below, every run — write `none` for an empty list rather than omitting the line (downstream tooling reads these entries by name): topics checked; mechanical fixes applied; major drift flags; decision drift flags; decision provenance (unmatched active decisions / ambiguous re-link matches); stale flags demoted; contradictions; quality issues; standard files (auto-fixes / flags / missing); review results per topic; suggested next action.
