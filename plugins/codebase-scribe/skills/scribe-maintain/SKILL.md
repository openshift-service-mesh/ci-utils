---
name: scribe-maintain
description: Use when all documentation topics are current or lightly drifted. Detects mechanical and decision drift, auto-fixes broken references, flags stale content for review, validates cross-topic consistency, and recalculates scores. Semantic drift evaluation is handled by the review subagent.
---

# Scribe Maintain — Phase 3

You are running Phase 3 (Maintain) of the codebase-scribe documentation system. Your job is to detect drift between documentation and code, auto-fix mechanical issues, flag major drift and decision drift for review, check cross-topic consistency, and recalculate scores. Semantic drift evaluation is handled by the review subagent (scribe-review).

## Safety Rules

1. **Mechanical drift:** Auto-fix broken file paths and function names. Always produce a summary of what you changed.
2. **Semantic drift:** Maintain does not evaluate semantic drift — that is handled by the review subagent (scribe-review). Maintain only flags major churn for review.
3. **Deletions are always semantic:** If a referenced file or function was deleted, flag it — never silently remove the reference.
4. Never modify AGENTS.md
5. Never delete content from topic files — only update references and frontmatter

## Inputs

You receive from the orchestrator:
- List of all topics with their current frontmatter
- Per-topic drift classification (current / drifted / undercooked)
- List of topics with changed watch_paths (from Phase 0's git diff)

Read `.scribe.yml` if it exists for drift sensitivity settings.

## Drift Sensitivity

Map the `drift.sensitivity` setting to thresholds:
- `low`: minor = 20% of watched files changed, major = 50%
- `medium` (default): minor = 10%, major = 30%
- `high`: minor = 5%, major = 15%

## Per-Topic Maintenance

For each topic that isn't completely current:

### 1. Scope the Diff

Run: `git diff --stat <scan_sha>..HEAD -- <watch_paths>`

Calculate churn: (files changed / total files in watch_paths) x 100

### 2. Apply Drift Table

| Watch paths changed? | References valid? | Action |
|---|---|---|
| No | Yes | **Skip.** Stable and correct. Zero prompts. |
| No | No | Mechanical drift. Auto-fix if possible, flag deletions. |
| Yes, minor (< minor threshold) | Yes | Light check. Skim the diff summary. Usually no action needed. |
| Yes, minor | No | Mechanical drift. Auto-fix broken references. |
| Yes, major (> major threshold) | Either | Major drift. Flag for review — semantic evaluation handled by review subagent. |

### 3. Reference Validation

For each topic file, extract all file path references and function/type name references. Check:
- **File paths:** Does `grep -r` or `ls` confirm the file exists?
- **Function names:** Does `grep -r "func <name>" <watch_paths>` find the function?

For broken references:
- Check `git log --diff-filter=R -- <old_path>` to find if the file was renamed
- If renamed: auto-fix the reference in the doc, note the change in your summary
- If deleted: add a stale flag to frontmatter:

```yaml
stale_flags:
  - id: <section-slug>
    heading: "<section heading>"
    flagged_at_sha: <current HEAD>
    reason: "<short category>"
    detail: "<specific explanation>"
```

Reason categories: `"deleted"` (file/function removed), `"renamed"` (auto-fixed but flagged), `"semantic"` (code behavior changed), `"escalated"` (60%+ broken references, needs full redraft).

### 4. Decision Drift Detection

For claims in `.claims.yml` with `provenance.origin: user`, check whether the claim's `source` file changed since the claim was recorded:

1. Run `git diff --stat <scan_sha>..HEAD -- <source_file>` for each user-sourced claim
2. If the source file changed by more than `drift.decision_lines_threshold` lines (default: 5, configurable in `.scribe.yml`), check the diff hunks for key terms from the claim text
3. If both conditions are met (threshold exceeded AND claim terms appear in diff), the decision may be outdated

Add a stale flag:

```yaml
stale_flags:
  - id: decision-<claim-id>
    heading: "<section where the claim appears>"
    flagged_at_sha: <current HEAD>
    reason: "decision_drift"
    detail: "Claim '<claim text>' (recorded <date>) may be outdated — <file> changed since it was recorded."
```

**Deduplication:** If multiple user-sourced claims reference the same changed file within one topic, create ONE stale flag per topic listing all affected claims in the `detail` field.

**Claims missing `provenance`** or with `provenance.origin: inferred` are skipped entirely — decision drift only applies to user-sourced knowledge.

Report in the summary: "N decision drift flag(s) raised. These will be addressed in the next draft or focus run."

### 5. Stale Flag Lifecycle

For existing stale flags in frontmatter:
- Calculate commit distance: `git rev-list --count <flagged_at_sha>..HEAD`
- Check if watch_paths have changed since the flag was raised: `git diff --stat <flagged_at_sha>..HEAD -- <watch_paths>`
- **Demote to known stale** when: commit distance > `stale_commit_threshold` (default 50) AND watch_paths haven't changed in those commits
- **Keep active** when: watch_paths are still changing (code is actively evolving, stale docs are a real problem)
- Surface active flags to the user: "These sections may be outdated: [list]"

### 6. Cross-Topic Consistency

#### Reference Consistency
When two topic files reference the same file path or function, check they describe it consistently (same purpose, same behavior). Flag inconsistencies.

#### Claim Consistency
Read `docs/agents/.claims.yml`. For each topic:
- Check if the topic has claims in `.claims.yml`. **If a topic has zero claims, extract them now** — this catches topics that were drafted by subagents or in earlier versions that didn't extract claims.
- Check if the topic file's git SHA matches `_meta.<topic>_extracted_at`
- If they differ (topic was updated), re-extract claims for that topic
- If `.claims.yml` is missing, re-extract claims for all topics

Re-extraction: read the topic file content and extract up to 15-20 factual claims using the five claim types (technology, pattern, data_flow, boundary, constraint).

**When re-extracting claims**, read existing `.claims.yml` first and preserve IDs for claims that match by exact match on `{type, topic}` and first 50 characters of the claim text. Only assign new IDs for genuinely new claims. Preserve `provenance` fields from existing claims — do not overwrite user-provided provenance with inferred.

Claims missing a `provenance` field default to `{ origin: inferred }` for all purposes including drift detection.

For existing claims without an `id` field, assign IDs on first read using the `<topic-slug>-<N>` scheme.

**Always run contradiction checking** even if no claims were re-extracted. Compare ALL claims across ALL topics. If two claims from different topics contradict each other, add to the `contradictions` section in `.claims.yml`:
```yaml
contradictions:
  - topic_a: architecture
    claim_a: {id: arch-grpc, claim: "gRPC for internal services"}
    topic_b: patterns
    claim_b: {id: pat-http, claim: "HTTP client wrapper for service calls"}
```

### 7. Quality Checks

Run these on every maintain pass:

**Structural validation:** Verify each topic file has these 5 `##` headings: `Key Entry Points`, `Patterns & Conventions`, `Gotchas`, `Dependencies & Context`, `Links`. Also verify the TL;DR blockquote exists. If any are missing, flag for the user (do not auto-add — maintain never adds content).

**Actionability check:** Scan each section. If a section is more than 5 lines of prose with zero code references (file paths, commands, function names), flag it:
> "Section '[heading]' in [topic].md has no concrete code references. Consider enriching it with specific file paths and commands."

**Content length check:** If any topic file exceeds 500 lines (or `content.split_threshold`), propose a split.

**Structural diff:** Compare the repo's top-level directory structure against documented topics. If a significant directory exists that isn't covered by any topic's watch_paths, note it:
> "Directory `pkg/newmodule/` exists but isn't covered by any documentation topic. Consider running `/codebase-scribe` to add a topic for it."

### 8. Recalculate Scores

For each topic:

**Freshness:** `git diff --stat <scan_sha>..HEAD -- <watch_paths>`. Freshness = (unchanged files / total files in watch_paths) x 100.

**Human Input:** (sections NOT in `inferred_sections` / total sections) x 100.

**Completeness:** List depth-1 subdirectories of each watch_path. Completeness = (directories with at least one file referenced in the doc / total directories) x 100.

Update scores in the topic file's frontmatter. Update `scan` SHA to current HEAD if changes were made.

### 9. Escalation

If a section has 60%+ of its referenced files no longer existing, escalate:
> "Section '[heading]' in [topic].md has 60%+ broken references. This section needs a full redraft. Recommend running `/codebase-scribe` again to regenerate it."

To ensure the orchestrator routes this topic to Phase 2 on the next run:
1. Set `completeness: 0` in the topic's frontmatter (this triggers the `undercooked` classification in the orchestrator's Step 5)
2. Add a stale flag with `reason: "escalated"`:
```yaml
stale_flags:
  - id: <topic-slug>
    heading: "# <topic title>"
    flagged_at_sha: <current HEAD>
    reason: "escalated"
    detail: "60%+ broken references in section '[heading]', needs full redraft"
```
3. Update session state with `phase_status: "needs_redraft"` for this topic

### 10. Regenerate STATUS.md

After all maintenance checks, regenerate `docs/agents/STATUS.md` (full overwrite):
1. Read all topic files' frontmatter for current scores
2. Read `.claims.yml` for claim counts and any contradictions
3. Write STATUS.md with: topic table (Topic, Fresh, Human, Complete, Claims, File), stale flags section, contradictions section

### 11. Standard Files Maintenance

After all topic maintenance is complete, check the three human-facing root files for drift. Run this block once per maintain invocation.

#### A. Check each standard file

For each of `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md` at the repo root:

1. Check if the file exists. If it doesn't, note it as missing in the summary — do not create it (creation belongs to draft mode).
2. If it exists, read it.

#### B. Per-file drift checks

**README.md and CONTRIBUTING.md:**

Check for mechanical drift only — do not rewrite prose:
- **Broken links:** For every link to a `docs/agents/` file, check it resolves. If a linked topic file was renamed, auto-fix the link and note it. If it was deleted, flag it.
- **Stale commands:** For any command shown (build, test, run), check it still appears in the build files (Makefile, package.json, etc.). If a command is no longer present, flag it for human review — do not auto-fix commands since the intent may have changed.
- **Missing topic links:** If new topic files exist in `docs/agents/` that aren't linked from README.md, note them in the summary as candidates to add.

**ARCHITECTURE.md:**

Since this file is a pure navigation index, maintenance is straightforward:
- For every `docs/agents/` link it contains, check it resolves. Auto-fix renamed files, flag deleted ones.
- If new topic files exist in `docs/agents/` that aren't listed, auto-add them using the topic's blockquote TL;DR as the description.
- If a topic's TL;DR blockquote changed since ARCHITECTURE.md was last written, update the description line.

#### C. Report outcome

Include in the Step 13 summary: which files were checked, what was auto-fixed, and what was flagged for human review.

### 12. Review Gate

**After all maintenance checks, STATUS.md regeneration, and Standard Files Maintenance, you MUST run the review orchestration** for any topics that were modified (mechanical fixes, re-extracted claims, etc.). This is not optional.

Follow Step 9 (Review Orchestration) from the orchestrator command (`commands/codebase-scribe.md`). For each topic modified during this maintain pass:

1. Classify the change using the rules in Step 9a
2. Check the review trigger (Step 9b)
3. If triggered: invoke the `codebase-scribe:scribe-review` skill using the `Skill` tool (NOT the `Agent` tool, NOT code-reviewer or any other plugin) (Step 9c)
4. Process the verdict (Step 9d), check human gate (Step 9e), finalize (Step 9f)
5. If not triggered: present the opt-in prompt to the user

Only after the review gate completes should you print the summary.

### 13. Summary

Print a summary:
- Topics checked: N
- Mechanical fixes applied: [list]
- Major drift flags raised: [list]
- Decision drift flags raised: [list]
- Stale flags demoted: [list]
- Contradictions found: [list]
- Quality issues: [list]
- Standard files: [auto-fixes applied] / [flags raised] / [missing files noted]
- Review results: [pass/rework/skipped per topic]
- Suggested next action
