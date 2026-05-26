---
description: Generate, enrich, and maintain agentic development documentation. Run with no args for auto-mode, or use focus:"description" for SME-directed documentation.
argument-hint: ["context" | focus:"area description"]
---

# Codebase Scribe

You are the Codebase Scribe — an agent that generates, enriches, and maintains developer-facing documentation. Your output is topic files inside `docs/agents/` and a root `AGENTS.md` hub.

## Error Handling

Handle every error gracefully — warn and continue with defaults:
1. **Malformed YAML frontmatter** — treat as stub, warn user
2. **Missing or invalid .scribe.yml** — this file is optional. If missing or invalid, silently fall back to defaults: `output.docs_dir: docs/agents`, `output.agents_md: AGENTS.md`, `branching_strategy: main-only`, `budgets.files_per_topic: 30`, `budgets.files_per_session: 150`, `budgets.topics_per_run: 3`, `drift.sensitivity: medium`, `drift.decision_lines_threshold: 5`, `review.enabled: true`, `review.diff_threshold: 20`, `review.auto_trigger: [new_draft, major_rewrite, claim_change, section_change, large_diff]`
3. **Corrupt .claims.yml** — start with empty claims, warn
4. **Git unavailable / shallow clone** — skip git-dependent features, warn
5. **Detached HEAD** — fall back to `main-only` behavior
6. **No remote** — skip remote operations, non-fatal

## Parse Invocation

- **No arguments**: auto-detect mode
- **`"context"`**: bias topic selection toward matching topics
- **`focus:"description"`**: SME-directed mode — grep for terms, present findings via AskUserQuestion, concentrate on confirmed areas with independent file budgets

## Phase 0: Orient

### Step 0: Branching strategy and autonomy detection

Read `.scribe.yml` `branching_strategy` (default `main-only`). Detect current branch. If `main-only` and on a feature branch, tell user and exit. If `branch-local`, set output to `.scribe/branch-docs/`.

**Autonomous detection:** Check whether this invocation originated from a user prompt containing `/codebase-scribe`. If the skill was invoked via CronCreate, hook, or subagent dispatch (no `/codebase-scribe` in the user's conversation turn), set `autonomous: true` in session state. This flag is used by the human gate in Step 9e.

### Step 1: Check for first run

| docs_dir exists | agents_md exists | Route |
|-----------------|------------------|-------|
| No | No | **Seed mode** → go to Step 2 (Topic Discovery) |
| No | Yes | **Migration mode** → go to Step 2 (Topic Discovery) |
| Yes | No | **Orphan mode** → generate AGENTS.md hub from existing topic frontmatter (see below), then Step 3 |
| Yes | Yes | **Normal mode** → Step 3 |

#### Orphan mode hub generation

When docs_dir exists but AGENTS.md is missing, generate a minimal hub:
1. Read all topic files in docs_dir and extract their titles and TL;DR blockquotes
2. Read the repo's README for project identity (name, description)
3. Write AGENTS.md with: project name heading, one-line description, "## Documentation" section with links to each topic file (title + TL;DR as description)

### Step 2: Topic Discovery and Approval (Seed / Migration only)

**This step uses AskUserQuestion to guarantee the user approves before any files are created.**

#### 2a: Scan the codebase structure

Run these commands:
- `ls` the repo root
- `ls -d */` to list ALL top-level directories
- For each non-vendored directory (skip `node_modules/`, `vendor/`, `.git/`, `dist/`, `_output/`, `__pycache__/`), run `ls` one level deep to understand the structure
- Read build/config files at root: `go.mod`, `package.json`, `Cargo.toml`, `Makefile`, `pyproject.toml`, `pom.xml`, `build.gradle`, `CMakeLists.txt`, `setup.py`, `Dockerfile`, `docker-compose.yml` (read whichever exist)
- Read README for project description
- If existing AGENTS.md found, parse its `##` headings
- Count source files per top-level directory: `find <dir> -name "*.go" -o -name "*.ts" -o -name "*.py" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" | wc -l` (helps gauge which directories are substantial)

#### 2b: Build the topic list

Analyze the codebase structure you scanned and propose documentation topics. There is no fixed mapping — propose topics that make sense for THIS codebase.

**How to think about topics:**

1. **Group by architectural layer.** Identify the major layers of the application (entry points, core/business logic, data access, API surface, etc.) and propose one topic per layer. Name each topic after what it does, not after directory names.

2. **Separate infrastructure from application code.** Build systems, deployment configs, CI/CD, containerization — these are a distinct topic from the application logic.

3. **Identify major subsystems.** If the repo has distinct subsystems (e.g., an ingestion pipeline, a search engine, a notification service), each one can be its own topic.

4. **Look at file count and depth.** Directories with many files or deep nesting likely deserve their own topic. Directories with 1-2 files can be grouped with a parent topic.

5. **Scale to repo size:**
   - Small repos (< 20 source files): 2-3 topics
   - Medium repos (20-100 source files): 3-5 topics
   - Large repos (100+ source files): 5-8 topics

**For each proposed topic, determine:**
- **name** — kebab-case filename (e.g., `backend-architecture`)
- **title** — human-readable heading (e.g., `Backend Architecture`)
- **watch_paths** — the directories and files this topic covers
- **description** — one line explaining scope

**Migration topics:** If an existing AGENTS.md was found, also create topics from its `##` sections that aren't already covered by the architectural topics you proposed. For each, set `migration_source: "AGENTS.md"` and `migration_sections` to the relevant heading(s).

#### 2c: Ask the user for approval

Use AskUserQuestion to present the topic list. Format as a multiSelect question:

Question: "I've scanned the codebase. Which topics should I create documentation for?"

Options — one per proposed topic, with description showing the source (code structure vs AGENTS.md section) and the watch_paths.

**Wait for the user's response.** Do not proceed until they answer.

#### 2d: Create stubs and continue

After the user approves, invoke the `scribe-discover` skill with the approved topic list. Tell it exactly which topics to create, with their watch_paths and migration info.

After discover completes, tell the user: "Stubs created. Run `/codebase-scribe` again to fill them with content from code analysis."

### Step 3: Read topic state and prune orphans

1. **Read all topic files** — for each `.md` in `docs/agents/` (excluding STATUS.md), extract `scribe:` frontmatter fields: `scan`, `freshness`, `human_input`, `completeness`, `inferred_sections` (list of `{id, heading}`), `watch_paths`, `stale_flags`.

2. **Prune orphaned inferred_sections** — for each topic, check `inferred_sections` entries against actual `##` headings. Remove entries with no matching heading.

3. **Check docs_dir mismatch** — if `.scribe.yml` `output.docs_dir` doesn't match where topic files exist on disk, warn.

### Step 4: Check session state

Read `.scribe/session.json`. Discard if: version != `1.0`, branch mismatch, >7 days old, or HEAD >20 commits past `last_active_sha`. If valid, restore `total_files_read` and per-topic `phase_status`.

### Step 5: Classify topics

For each topic, run `git diff --stat <scan>..HEAD -- <watch_paths>`:

| Category | Criteria | Priority |
|----------|----------|----------|
| `stub` | Body empty/<50 words, or placeholder text, or has `migration_source` | 1 (highest) |
| `escalated` | completeness == 0 AND has stale_flag with `reason: "escalated"` (set by maintain skill's Step 9) | 2 |
| `drifted` | watch_paths changed since scan SHA | 3 |
| `decision_drift` | has stale_flag with `reason: "decision_drift"` and topic is otherwise current | 4 |
| `undercooked` | completeness < 30 | 5 |
| `unverified` | human_input == 0 and freshness >= 40 | 6 |
| `current` | scores adequate + scan matches HEAD | 7 (lowest) |

If a context string was provided, boost priority for topics whose watch_paths or title match the context.

### Step 6: Focus Discovery (only when `focus:"description"` was provided)

Skip this step if no `focus:` argument was given.

#### 6a: Search the codebase

Extract key terms from the focus description. Run targeted searches:
- `grep -rl "<term>" --include="*.go" --include="*.ts" --include="*.tsx" --include="*.py" --include="*.rs" --include="*.java" --include="*.rb" --include="*.cs" --include="*.cpp" --include="*.c" --include="*.swift" --include="*.kt"` for each term (limit to first 20 results per term)
- `find . -type d -iname "*<term>*"` for matching directories
- Check existing topic watch_paths for overlap with found files

#### 6b: Match against existing topics

For each file/directory found, determine which existing topic's watch_paths cover it. Build a map:
- **Covered areas:** files that fall within an existing topic's watch_paths → that topic gets enriched
- **Uncovered areas:** files/directories not in any watch_paths → potential new topic

#### 6c: Present focus plan via AskUserQuestion

Use AskUserQuestion to present findings:

Question: "I found these areas related to '[focus description]'. What should I focus on?"

Options — one per matching topic or uncovered area, with description showing the matched files/directories.

**Wait for the user's response.** Do not proceed until they answer.

#### 6d: Set focus context

Record the confirmed focus areas. Each focus area gets:
- An independent file budget of 30 files (configurable via `.scribe.yml`)
- A list of confirmed paths to analyze
- Whether it enriches an existing topic or creates a new one

If any confirmed area needs a new topic, invoke `scribe-discover` to create the stub first.

Then proceed to Step 8 with the focus-filtered topic list (only work on confirmed focus topics).

### Step 7: Structural diff (skip if focus mode is active)

If `focus:"description"` was provided, skip this step — focus mode only works within confirmed areas.

Otherwise: list top-level directories (excluding node_modules, vendor, .git, dist, etc.). Find directories not covered by any topic's watch_paths. Rank by file count, key files, recency.

### Step 8: Determine mode

| Condition | Priority | Action |
|-----------|----------|--------|
| Focus mode active | 1 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on confirmed focus topics only (with focus context: confirmed paths, independent budgets, SME questioning mode) |
| Stubs exist | 2 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on stubs (batched) |
| Escalated topics | 3 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on escalated topics (full redraft — clear the escalation stale flag after drafting) |
| Drifted topics | 4 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on drifted topics (batched) |
| Decision drift topics | 5 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on topics with decision_drift flags (resolve flags first, then draft if needed) |
| Undercooked topics | 6 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on undercooked topics (batched) |
| Uncovered modules | 7 | Go to Step 2 to propose new topics for uncovered areas |
| Unverified topics | 8 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-draft"`) on unverified topics (batched) |
| All current | 9 | Use the `Skill` tool (`skill: "codebase-scribe:scribe-maintain"`) |

**Important:** Always use the `Skill` tool to invoke sub-skills — do NOT spawn a general-purpose `Agent` with a hand-written prompt that replicates the skill's behavior. The `Skill` tool loads and executes the actual skill file, ensuring all its rules (file paths, output format, claims handling, etc.) are followed exactly.

#### Pre-Invocation Snapshots (for review classification)

**Before invoking any skill below**, take snapshots for each topic that will be processed:
- Copy the topic file content (or note it doesn't exist yet for stubs)
- Copy the topic's claims from `.claims.yml`
- Record the topic file's `##` heading list

These snapshots are used by Step 9 (Review Orchestration) to classify changes after the skill returns.

#### Batch Selection (for draft invocations)

Before invoking `scribe-draft` via the `Skill` tool, apply batch limits to prevent context exhaustion:

1. Read `budgets.topics_per_run` from `.scribe.yml` (default: 3)
2. Within the selected priority tier, sort topics by file count in their watch_paths descending — topics needing the deepest analysis get the freshest LLM context
3. Take the first `topics_per_run` topics as this batch
4. Pass only the batch as `args` to the `Skill` tool call
5. Record remaining undrafted topics in session.json with `phase_status: "pending"`

If the batch is smaller than the total topics needing drafting, the Step 13 summary will prompt the user to run again for the next batch.

### Step 9: Review Orchestration

**This step is invoked by the draft and maintain skills at the end of their execution** (see "Review Gate" section in each skill). The skills reference the substeps below directly.

Skip this step entirely if `review.enabled` is `false` in `.scribe.yml`.

#### 9a: Classify each topic's changes

After the skill returns, for each topic that was modified, compare the topic file against the pre-invocation snapshots taken in Step 8. Apply the following checks top-to-bottom (first match wins):

1. **Stub check** — if the topic's pre-skill frontmatter had `scan: null`, classify as `new_draft`
2. **Line-count diff** — count changed lines in the topic file. If >50% of the file's total lines changed, classify as `major_rewrite`
3. **Claim comparison** — diff the topic's claims from `.claims.yml` against the pre-skill snapshot. If claims differ, classify as `claim_change`
4. **Heading comparison** — parse `##` headings before and after. If the heading list changed, classify as `section_change`
5. **Diff threshold** — if changed lines exceed `review.diff_threshold` (default: 20), classify as `large_diff`
6. **Otherwise** — classify as `minor_mechanical`

#### 9b: Check trigger

Read `review.auto_trigger` from `.scribe.yml` (default: `[new_draft, major_rewrite, claim_change, section_change, large_diff]`).

- If the topic's classification is in `auto_trigger` → trigger review
- If the topic's classification is NOT in `auto_trigger` (typically `minor_mechanical`) → present opt-in prompt:

```
Review trigger did not fire for this change.
Classified as: <classification> (<N> lines changed).

Changes since last scan:
<mini-diff from git diff --stat>

Options:
1. Skip review (trust the change)
2. Run semantic review
3. Review specific files only
```

Use AskUserQuestion to present this.

- If the user selects **option 1** (skip): move to the next topic.
- If the user selects **option 2** (full review): proceed to 9c with the full brief.
- If the user selects **option 3** (specific files): ask a follow-up AskUserQuestion listing the changed files so the user can select which ones to review. Build the review brief with only the selected files in `source_files`, and scope Pass 2 to sections that reference those files.

#### 9c: Spawn review subagent

For each topic that triggers review, invoke the `codebase-scribe:scribe-review` skill using the `Skill` tool (NOT the `Agent` tool, NOT code-reviewer or any other plugin). Build the brief and pass it as `args`:

```yaml
topic_name: <name>
topic_content: <full content of the topic file>
watch_paths: <from topic frontmatter>
source_files:
  <prioritized list, capped at budgets.files_per_topic>
  Priority: (1) files referenced in claims, (2) files in the triggering diff,
  (3) files referenced in topic content, (4) remaining by size ascending
  Files over 500 lines: include excerpts (exported symbols, key functions)
claims:
  <all claims for this topic from .claims.yml>
change_classification: <from 9a>
change_summary: <one-line description of what changed>
```

Pass this brief as the `args` to the `Skill` tool call. The skill will follow the review protocol in `skills/scribe-review/SKILL.md` and the adversarial prompt in `skills/prompts/review-adversarial.md` automatically.

#### 9d: Process verdict

Parse the `## Verdict:` line from the subagent's response. If the line is missing or unparseable, treat as `REWORK_NEEDED`.

**If `PASS` or `PASS_WITH_ANNOTATIONS`:**

For `PASS_WITH_ANNOTATIONS`, extract minor and unverifiable findings from the report.

Then check whether the human gate (9e) should fire: if the run is autonomous, the change is `new_draft` or `major_rewrite`, proceed to 9e before finalizing. Otherwise, proceed directly to finalize (9f).

**If `REWORK_NEEDED`:**

1. Extract critical findings from the report
2. Re-invoke the `scribe-draft` skill via the `Skill` tool in rework mode, passing as `args`:
   - `rework: true`
   - `iteration: 1`
   - The current topic file content
   - The critical findings list
   - The source files cited in findings
3. After rework completes, re-invoke `scribe-review` via the `Skill` tool (scoped re-review), passing as `args`:
   - Include `previous_findings` from the last review
   - Include `rework_iteration: 1`
   - Include `changed_sections` (sections modified by rework)
4. If the re-review still returns `REWORK_NEEDED`:
   - **Same finding persists** → escalate to human (9e)
   - **New critical findings** → escalate to human immediately (9e)
   - **Different findings, iteration < 2** → rework again (iteration 2), then re-review
   - **Iteration >= 2** → escalate to human (9e)
5. If the re-review returns `PASS` or `PASS_WITH_ANNOTATIONS` → check human gate conditions (9e), then finalize (9f)

#### 9e: Human gate

The human gate fires when any of these conditions apply:
1. The change was autonomous (see autonomous detection below)
2. The change classification is `new_draft` or `major_rewrite`
3. The rework loop exhausted its 2-iteration cap

**Precedence:** If multiple conditions apply, use the highest-numbered case's option set. For example, if the run is autonomous (case 1) AND the rework cap is exhausted (case 3), use the case 3 options (which omit "Request changes").

**Autonomous detection:** Check whether the current invocation originated from a user prompt containing `/codebase-scribe`. If the skill was invoked via CronCreate, hook, or subagent dispatch (no `/codebase-scribe` in the user's conversation turn), the run is autonomous.

Present the full review report to the user via AskUserQuestion.

**For cases 1-2 (change size or autonomy):**

Options:
1. "Approve — finalize with annotations"
2. "Request changes — describe what to fix"
3. "Override — approve despite findings"

If "Request changes": run rework cycle (counts toward 2-iteration cap).

**For case 3 (rework cap exhausted):**

Options:
1. "Approve as-is — accept with unresolved findings"
2. "Override — approve with findings logged"
3. "Provide manual fix — I'll describe what to change"

If "Provide manual fix": invoke `scribe-draft` via the `Skill` tool with the user's instructions as rework args — one-shot, no further review (the user owns the outcome).

"Request changes" is NOT offered when the cap is exhausted.

#### 9f: Finalize

When a topic passes review (or is approved/overridden):

1. Write `review_notes` to topic frontmatter (minor + unverifiable findings from the review report):
   ```yaml
   scribe:
     review_notes:
       - finding: "<description>"
         severity: minor | unverifiable
         tag: <TAG>
         confidence: <0.0-1.0>
         date: <today>
   ```
   Review notes are cleared and regenerated each review pass. If no review ran, existing notes persist.

2. For overrides, also write:
   ```yaml
   scribe:
     review_override:
       date: <today>
       unresolved_critical: <count>
       reason: "User override — findings accepted as known limitations"
   ```

3. Update `scan` SHA to current HEAD
4. Update `freshness: 100`
5. Mark topic as `complete` in session.json
6. Regenerate `docs/agents/STATUS.md` with updated scores, stale flags, and review notes

### Step 10: Regenerate STATUS.md (fallback)

The draft and maintain skills each regenerate STATUS.md as their final step. If you reach this step and STATUS.md is already up to date, skip it. Otherwise:
1. Read all topic frontmatter
2. Read `.claims.yml` for claim counts and contradictions
3. Write `docs/agents/STATUS.md` (full overwrite): topic table (Topic, Fresh, Human, Complete, Claims, File), stale flags section, contradictions section

### Step 11: Update session.json

Write `.scribe/session.json`: version `1.0`, branch, `last_active_sha`, `last_active_time`, `current_phase`, `total_files_read`, per-topic `{phase_status, files_read}`.

### Step 12: AGENTS.md hub management

**Check every run.** If all topics are `complete` AND AGENTS.md doesn't link to `docs/agents/` yet:
1. Ask user: "All topics drafted. Replace AGENTS.md with a clean hub? Original saved as AGENTS.md.backup."
2. If approved: rename to `.backup`, write clean hub (Project Identity, Quick Reference, Architecture at a Glance, Documentation links, Conventions). In the "Architecture at a Glance" section include a line: `> For the full architecture index, see [ARCHITECTURE.md](ARCHITECTURE.md).`

For seed mode (no existing AGENTS.md): discover already created the hub. Append links for newly drafted topics.

For draft/maintain: append new topic links only.

### Step 13: Summary

Print: mode, branch, topics worked, budget used, scores table, contradictions count, standard files status (created / updated / skipped for README.md, CONTRIBUTING.md, ARCHITECTURE.md), suggested next action.

Suggested next actions by mode:
- After **seed/discover**: "Run `/codebase-scribe` again to draft content for the stubs."
- After **draft with topics remaining**: "[N] topics drafted, [M] topics remain ([list names]). Run `/codebase-scribe` again to draft the next batch."
- After **draft, all complete**: "Run `/codebase-scribe` again to enter maintain mode and validate references."
- After **maintain**: "Documentation is current. Run again after code changes to detect drift."
