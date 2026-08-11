---
skill: review
analyzed_at: 2026-08-11T00:00:00Z
skill_hash: b3c4d5e6f7a8
execution_mode: batch
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - consistency_checked
  - ci_verified
  - merge_order_correct
  - jira_updated
---

# review Analysis

## Purpose

`review` verifies the correctness and completeness of open CVE PRs for the Envoy component across all active branches. It:
1. Discovers open CVE PRs across `envoyproxy/envoy-openssl`, `envoyproxy/envoy`, and `openshift-service-mesh/proxy`
2. Reads each PR's diff and classifies the fix pathway (A, B, D, E, P-A, P-Go)
3. Checks cross-branch consistency (same dep version, same patch, or same cherry-pick SHA)
4. Verifies CI status on all PRs
5. Approves and merges in the correct order (main first, then backports newest-to-oldest; proxy last)
6. Transitions Jira tickets from Code Review to Release Pending and sets fix versions

## Inputs

The skill gathers via `AskUserQuestion` (or headless `input.yaml`):
- `cve_id`: CVE identifier
- `prs`: list of PR descriptors — each with `repo`, `number`, `branch`, `pathway`, `ci_status`, and optional `diff_notes`
- `jira_issues`: list of Jira issue keys for this CVE
- `missing_backports`: list of branch names that are missing a PR
- `code_freeze_active`: whether any target branch is currently in code freeze

## Output Artifacts

The skill produces:
1. Per-PR summary (pathway, files changed, consistency verdict)
2. Cross-branch consistency report
3. CI status per PR (pass/fail/pending)
4. Merge actions executed or blocked
5. Jira update confirmation (fix versions set, transition to Release Pending)

## Key Constraints

- Merge order: `main` first, then backports newest to oldest, proxy PR last
- Never merge if CI is failing on any PR
- Never merge if code freeze is active on the target branch
- Always set `fixVersions` on Jira issues before transitioning to Release Pending
- For Pathway E PRs: structural diff differences are expected — verify fix intent, not diff identity

## Evaluation Notes

Cases should exercise:
1. Pathway A — all PRs consistent and CI green — full happy-path approve+merge+Jira flow
2. Pathway B — patch-based fix — verify cve.yaml entries consistent across branches
3. CI failing on one PR — halt merge for that branch, report failure
4. Pathway E on an upstream-EOL branch — structurally different diff is acceptable; verify fix intent
5. Missing backport PR for an active branch — flag it, do not merge the others until resolved
