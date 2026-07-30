---
skill: scribe-maintain
analyzed_at: 2026-07-28T00:00:00Z
skill_hash: regenerated-wave-6-r2
execution_mode: case
headless: false
dry_run: false
suggested_judges:
  - cost_budget
  - scan_validation_handling
  - shallow_gate_respected
  - drift_table_and_mechanical_fixes
  - escalation_flagged
  - quality_checks_flagged
  - maintain_quality
---

# scribe-maintain Analysis

## Purpose

`scribe-maintain` is Phase 3 of the `codebase-scribe` pipeline. It detects
mechanical and decision drift between topic files and the current codebase,
auto-fixes broken references it can resolve (renames), flags what it can't
(deletions, major churn), validates cross-topic consistency, and recalculates
scores. Semantic drift evaluation is explicitly out of scope — that is the
review subagent's job.

## Inputs

Maintain receives every topic's current frontmatter plus `default_branch`,
`branching_strategy`, `current_branch`, `shallow`, `watch_paths` (Step-3
repaired), and `docs_dir` — all threaded from the orchestrator.

## Output Artifacts

Topic files updated in place, `<docs_dir>/.claims.yml` updated, and
`<docs_dir>/STATUS.md` regenerated.

## A hard constraint on this suite: no case can provision a real git history

A git commit SHA is a hash of its own content (tree, parent, message,
timestamps) — no fixture can name one in advance, and no eval harness can
force a specific arbitrary hex string to become a real, resolvable commit.
That means **any behavior gated on `git diff --stat <scan>..HEAD`,
`git log --diff-filter=R`, or `git merge-base --is-ancestor` actually
resolving is not testable with a static case directory**, no matter how
carefully the fixture's source tree (`internal/`) and `diff.txt` narrate an intended history.
An earlier revision of this suite got this wrong (three cases asserted
outcomes that require exactly this kind of resolution); this revision fixes
it by re-scoping those three cases to behaviors that are genuinely reachable
without git history, and by naming the unreachable behaviors explicitly below
rather than pretending to cover them.

## Spec Sections Exercised

- **§2 scan-SHA validation** — case-001 seeds a topic whose `scan` fails the
  shape test (`^[0-9a-f]{7,40}$`); `scan_validation_handling` checks that
  maintain reports full churn (§1) rather than crashing, and leaves
  `freshness` at its prior value (§8) instead of guessing a diff-derived
  number. This is reachable without git: the shape test is a plain regex,
  evaluated before any git command runs.
- **§2 shallow-clone gate** — case-002 sets `shallow: true` in the brief (the
  skill trusts this boolean directly, per its documented inputs — it never
  probes `git rev-parse --is-shallow-repository` or `.git/shallow` itself)
  and verifies every stored-SHA-diff consumer (§1/§2 churn, §3 rename
  resolution, §4, §5, §8) is skipped for every topic, a shallow warning
  appears **exactly once** — counted as warning-marker-near-`shallow`
  occurrences, so one warning and a per-topic repetition no longer score
  identically the way a bare `shallow` search made them; the known cost is
  that a run narrating "I will warn about the shallow clone" before warning
  counts two — and a broken reference is reported without a `"deleted"`
  reason (renames are indistinguishable from deletions at this clone depth)
  — and that nothing is escalated (below). §6 (cross-topic consistency) and
  §7 (quality checks) are outside the gate by contract, but **no judge in this
  case asserts they ran**: the case carries no `quality_checks` block, so
  `quality_checks_flagged` short-circuits to True, and nothing here reads §6's
  output. That coverage lives in cases 005/006, not in this one. Also reachable
  without git: `shallow` is a passed boolean, not something the skill detects
  itself.

  **The case's sharpest shallow discriminator is `expect_no_escalation`.**
  `billing.md`'s `## Charging` section cites exactly one file,
  `internal/billing/legacy_charge.go`, which is absent from the source tree — a 100%
  broken-reference ratio, well clear of §9's 60% threshold. §9 escalation is
  downstream of §3's rename resolution, which the gate skips (a rename is
  indistinguishable from a deletion at this clone depth), so a gate-respecting
  run reports the broken reference and escalates nothing; a run that ignores
  the gate escalates `billing` and fails. `escalation_flagged` cannot see this
  — the case names no `escalation_topic`, so that judge short-circuits to True
  — which is why `shallow_gate_respected` carries the assertion instead. Do not
  add a second reference to `## Charging`: the 100% ratio is what makes a
  missing escalation meaningful rather than merely unsurprising.
- **§3 Reference Validation — deletion path** — case-004 seeds a topic file
  referencing a function whose file is genuinely absent from the current
  source tree, with no rename narrative anywhere in the fixture. Whatever a
  rename-lookup would return against whatever (or no) git history the
  harness happens to provision, there is no candidate new location for this
  reference to resolve to, so it must be flagged `reason: "deleted"` and its
  prose preserved (Safety Rule 3), regardless of clone depth. **Deliberately
  isolated from §9 Escalation:** the same section also cites a second, intact
  reference, so the section's broken-reference ratio is 1-of-2 = 50% — below
  §9's 60% threshold. Without that second reference, a single broken
  reference in a one-reference section is 100% broken and a spec-correct run
  would ALSO escalate the topic on top of flagging the deletion, which would
  make the deletion-only assertion ambiguous (is completeness reset to 0
  because escalation fired correctly, or is that itself the bug?). Do not
  "simplify" this section back down to one reference — that reintroduces the
  ambiguity this shape exists to remove.

  **This case's `internal/` tree also carries two deliberately-shaped depth-1
  subdirectories under its watch path, and they are load-bearing.** §8
  recalculates completeness on every maintain pass unconditionally — unlike
  freshness, it has no "leave it unchanged" rule for an invalid or shallow
  scan — as *(depth-1 subdirectories of `watch_paths` containing at least one
  file referenced in the doc / total depth-1 subdirectories) x 100*. An
  earlier revision of this fixture had **zero** depth-1 subdirectories under
  `internal/profile/`, and §8 answers that case explicitly — completeness is
  `0` when the watch_paths have no depth-1 subdirectories, the same shape as
  the sibling Human Input rule in the same section. The problem was not an
  undefined denominator but an undiscriminating one: `0` is also what §9's
  escalation writes, so a fixture producing `0` could not distinguish a correct
  §8 recomputation from an escalation that should not have fired. The two
  subdirectories exist to make the expected value differ from both the
  fixture's stored prior and §9's escalation value.

  The repair is `internal/profile/thumbnail/` (whose `resize.go` /
  `ResizeThumbnail` **is** cited, from `## Media Handling`) and
  `internal/profile/audit/` (whose `audit_log.go` is cited nowhere). The
  denominator is now 2, the numerator 1, and §8 determines exactly one answer:
  `completeness: 50`, which the `drift_table_and_mechanical_fixes` judge
  asserts via `expected_completeness_recalculated`. That single number is
  triply discriminating — it differs from the fixture's stored prior (75), so
  a run that skips the §8 recalculation fails; it differs from §9's escalation
  value (0), so a run that escalates fails; and it is derived, not chosen, so
  a spec-correct run cannot fail it. Both subdirectories are also
  escalation-neutral: `thumbnail/resize.go` exists, so `## Media Handling` is
  0-of-2 broken, and `audit/` is referenced by no section at all, leaving
  `## Export`'s 50% the only nonzero broken ratio in the case. **Do not delete
  either subdirectory, and do not drop the `ResizeThumbnail` citation** —
  either change puts the denominator back to an undefined state and makes the
  completeness assertion unwritable again.
- **§9 Escalation** — case-003 seeds a topic where 3 of 4 references in one
  section (75%) are genuinely absent from the current source tree.
  Deliberately NOT the boundary case (3-of-5 = exactly 60%, which an
  implementation reading the threshold as a strict `>` rather than `>=`
  would fail): 75% clears the 60% threshold with margin regardless of that
  ambiguity. §9's 60%-broken-references rule is driven entirely by §3's
  plain existence check (`ls`/`grep`), not by a resolved diff, so it is
  fully reachable: `completeness` should be reset to 0 and a stale_flag with
  `reason: "escalated"` added, recommending a full redraft. Do not move this
  case back toward the 3-of-5 boundary.
- **§7 Quality Checks** — split across **two** cases, one per tier, because the
  split is what makes the judge work (see below). Neither has a git dependency;
  §7 is purely textual.

  - **case-005** holds a single **stub** topic, `release-process.md`. It has
    four of the five skeleton sections and no `## Links`, a TL;DR blockquote,
    and placeholder one-line sections well under §7's 5-line actionability
    threshold — so the missing `Links` section is the only quality finding the
    case legitimately seeds. Asserted: it is reported, and it is *not* added to
    the file (§7 flags, it never auto-adds).
  - **case-006** holds a single **mature** topic, `deployment-guide.md`: no
    TL;DR blockquote, a `## Rollout Philosophy` of **6** prose lines with zero
    code references — one line above §7's "more than 5 lines of prose"
    threshold, so **do not trim it**: at 5 lines the actionability check stops
    firing and the case's positive assertion silently stops testing anything —
    a contrasting `## Overview` that cites
    `internal/deploy/rollout.go` and `RolloutManager`, and a `## Links` (so
    §7's mature-topic Links advisory does not fire). Asserted: both findings
    are reported, neither gap is auto-filled, and — the assertion that
    discriminates the post-wave-1 architecture from the pre-improvement one —
    **no skeleton heading is named in the findings at all**. §1's two-tier
    structure makes the 5-section skeleton stub-only, so a mature topic using
    free-form headings is exempt; a pre-improvement implementation, which
    demanded all five on every topic, reports all four and fails here. A
    positive-only check cannot tell the architectures apart, since both pass it.

  ### How the judge reads a run, and why it was rebuilt

  `quality_checks_flagged` reads exactly two things: the topic file on disk,
  and the **"Quality issues" entry of the run's §13 summary** — the run's own
  findings list. Planning narration, tool chatter and the other summary entries
  are outside its window by construction. Within that entry the assertions are
  plain containment: an anchor string unique to each seeded finding must be
  present (`Links`; `Rollout Philosophy`; one of `TL;DR`/`TLDR`/`TL:DR`/
  `blockquote`), and in case-006 the four skeleton headings must be absent.
  There is no keyword vocabulary, no adjacency or ordering rule, no proximity
  window and no concession carve-out anywhere in it.

  The entry's extent is Markdown block structure, not a heuristic: when the
  `Quality issues` label is a list item or table row, the entry is its inline
  remainder plus the lines indented under it, and the next line at the same
  indent — whatever it says — ends it; when the label is a heading, the entry
  runs to the next heading. The next §13 label ends it either way. The **last**
  such label in the run's output is the one read, since §13's summary is
  printed after all the narration.

  This replaces a keyword-to-heading adjacency matcher run over the whole
  conversation. That matcher was frozen after five successive rounds — character
  windows, bullet segmentation, ambiguity skipping, attribution removal, regex
  adjacency — which each fixed the named failure shapes and opened a new family
  in the other direction; the final measurement was 21/28 against the previous
  22/28 on the reviewer's own matrix, i.e. the rounds were trading errors, not
  reducing them. The freeze ruling's own escape hatches were to split the case
  per topic or to assert against the run's result rather than its prose. Both
  are taken here, and each does a distinct job:

  - **Splitting per tier** removes the collision the matcher could never
    survive. The pathological shape was a legitimate finding that names the
    sections which are *present* — "missing `Links`; Key Entry Points,
    Patterns & Conventions, Gotchas and Dependencies & Context are all there".
    Any containment or proximity rule reads that as four false flags. It cannot
    arise in case-006, because that case seeds no missing-skeleton finding for
    such an enumeration to hang off; and case-005, which does seed one,
    deliberately carries **no** forbidden-heading assertion. **Merging the two
    cases back reintroduces the collision** — that is what the split is for.
  - **Anchoring to the §13 entry** removes the false PASS. Verified by
    execution, before and after: the transcript "I will check whether anything
    is missing: Links, TL;DR blockquote, Rollout Philosophy" followed by
    "Quality issues: No quality issues found." passed the old matcher's three
    positives off its own preamble; it fails both new cases. The reverse
    failure is gone with the binding rule that caused it: a line reading
    "Gotchas — no concrete code references", which the old matcher bound
    backwards through a clause break into a false flag, fails nothing now —
    both because there is no binding rule left, and because a per-section
    actionability aside is not inside the findings entry.

  ### Fixture guard

  Every anchor the two cases depend on is now asserted against the output file,
  and each assertion is deliberately double-duty: maintain never adds content,
  so a heading present in the output was either always in the fixture or was
  added by the run, and both are failures worth reporting.

  - case-005: `Links` absent; `Key Entry Points`, `Patterns & Conventions`,
    `Gotchas`, `Dependencies & Context` present; TL;DR blockquote present.
  - case-006: the four skeleton headings absent; `Overview`,
    `Rollout Philosophy`, `Links` present; TL;DR blockquote absent.

  This closes a hole the previous judge had: it guarded five headings but not
  the TL;DR anchor or `Rollout Philosophy`, so deleting the blockquote or
  renaming that section **silently voided** the positive built on it and the
  case still passed. Both now fail loudly — verified by execution.

  ### Honest limits of the new mechanism

  - **Window-bound.** Only the §13 "Quality issues" entry is read. A run that
    finds the seeded defect and reports it somewhere else — mid-run, or under a
    different summary label — fails. §13 prescribes the entry, so this is a
    defensible demand, but it is partly a lint on summary discipline rather
    than purely a test of §7.
  - **Containment, not comprehension.** A positive is satisfied by its anchor
    appearing anywhere in the entry. A run that writes "`Links` is present, no
    issue" inside its findings list passes the positive. The window is
    drastically narrower than the whole transcript, but it is still prose, and
    this judge does not read meaning.
  - **The negative has no concession carve-out, by design.** If a run names a
    skeleton heading inside case-006's findings entry for *any* reason —
    including explaining that it is deliberately not flagging them — the case
    fails. The previous concession guard was removed rather than ported: it was
    paragraph-wide and one incidental "correctly" disabled the negative for
    every finding in that paragraph. A run that keeps its explanations outside
    its findings list is unaffected.
  - **Extent depends on the run's Markdown.** Extra prose placed *inside* the
    entry's block pollutes the window; findings placed outside it empty the
    window. List, nested-list, heading and table renderings are all handled and
    were verified by execution, but the rule is structural, not semantic.
  - **Two §7 sub-checks remain unasserted** anywhere in this suite: the
    content-length split proposal (>500 lines) and the structural diff against
    the repo's top-level directories. Both were uncovered before this rework as
    well; neither case seeds an oversized topic or an uncovered directory.

  As before, `maintain_quality` — the LLM judge — is what assesses the run's
  reasoning in the round. The deterministic judge above is now a much narrower
  instrument than the matcher it replaces, and that narrowness is the point: it
  asserts things that are true or false about a structured region, rather than
  guessing which topic a sentence of free-form prose was about.

## Deliberately Uncovered

The following behaviors are **not exercised anywhere in this suite**, because
they are gated on a `git diff`, `git log --diff-filter=R`, or
`git merge-base --is-ancestor` call actually resolving against real history,
which no static fixture can provision (see the constraint section above):

- **§2's real churn-threshold drift-table rows** (`minor`/`major` computed
  from `git diff --stat <scan>..HEAD -- <watch_paths>`, per
  `drift.sensitivity`'s configured percentages) — a case can only ever
  exercise the "scan validation failed, report full churn" fallback (case-001
  covers that), never a genuinely computed churn percentage.
- **§3's rename auto-fix** (`git log --diff-filter=R -- <old_path>` actually
  finding a rename and updating the reference in place) — case-004
  deliberately avoids claiming a rename occurred, since there is no way to
  provision git history that would make such a lookup succeed.
- **§4 decision drift detection in its entirety** — every step (base
  selection, `git diff --stat <base>..HEAD -- <source_file>`, the
  line-count threshold, the diff-hunk term search) is diff-dependent; there
  is no non-git-dependent path through §4 to test.
- **§5 Stale Flag Lifecycle's demotion rule** (`git rev-list --count` commit
  distance) — same reason.
- **Standard Files Maintenance** (§11 — README/CONTRIBUTING/ARCHITECTURE drift
  checks) is not covered, matching the same gap noted in scribe-draft's suite
  for its Standard Files block; it runs once per invocation, not per topic.
- The **Review Gate** at the end of SKILL.md is not covered — for a different
  reason than the git-dependent items above: it follows the orchestrator's
  Step 9, which dispatches the `codebase-scribe:scribe-review` agent, and this
  suite's permission allowlist grants neither `Agent` nor `Skill`. Every case
  ships a `.scribe.yml` with `review.enabled: false` so Step 9 is skipped
  outright and the run terminates cleanly at the skill's own boundary rather
  than on an instruction it cannot carry out. Review behavior is covered by the
  scribe-review suite.

A follow-up that wants real coverage of the four git-dependent items above
would need either a documented harness capability to provision an actual git
repository with a known, harness-reported `scan` SHA (not available today),
or to move that testing to an integration level that runs against a real
repository rather than a static case directory.

## The fixtures are not orchestrator-realizable, deliberately

Each case's `input.yaml` now carries the per-topic `classification` its schema
declares, derived from that topic's own seeded state per Step 5's rows (the
derivation is written out beside each value). Five of the six cases land on rows
the orchestrator's Step 8 routes to **draft**, not maintain — `drifted`,
`undercooked`, `stub`, `unverified` — and only case-002's `billing` classifies
`current`. Maintain's one normal route in is Step 8 row 9, "All current", so
these briefs are not briefs a real run would ever hand this skill.

The assertions survive that anyway, because maintain's contract is stated
per-topic against the brief it receives, and §§1–2 are the only sections the
classification scopes: §§3–13 run for every topic the orchestrator passes,
whatever it was classified. Each case's expectations are derived from that
contract plus the seeded files, never from a claim about how the run got here.

Two consequences worth stating plainly, since both have cost time before: this
suite is **not** end-to-end coverage of the pipeline — nothing here exercises
Step 5's classification or Step 8's routing, and a routing bug would pass every
case — and "fixing" the fixtures into orchestrator-realizable shape by
reclassifying every topic `current` would delete the seeded defects the
assertions are derived from and silently gut the suite. A real
classification/routing test belongs to a command-level eval, which does not
exist yet.

## Evaluation Notes

Judges read `outputs["files"]` for frontmatter/content state and
`{{ conversation }}` for behavior only visible in the Step 13 summary (e.g. the
shallow-clone warning, or escalation language). `quality_checks_flagged` is the
one judge that does not read the transcript at all: it reads a single labelled
entry of the Step 13 summary, "Quality issues", and the topic file.

No case depends on a SHA resolving, but they do not all get there the same way:
case-001's `scan` fails the shape test outright, cases 003–006 use `scan: null`,
and case-002's two topics **do** carry realistic-looking — and entirely
fabricated — 40-hex SHAs. That is harmless there only because `shallow: true`
means the skill never inspects them. Read a well-shaped SHA in these fixtures as
decoration, never as something a case rests on; if a future case removes the
shallow flag from case-002, those two values become live and the case's
assertions stop being derivable.
