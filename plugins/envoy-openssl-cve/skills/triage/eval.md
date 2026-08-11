---
skill: triage
analyzed_at: 2026-08-11T00:00:00Z
skill_hash: a1b2c3d4e5f6
execution_mode: batch
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - pathway_determined
  - jira_action_correct
  - vex_when_closing
  - proxy_classified
---

# triage Analysis

## Purpose

`triage` manages the end-to-end lifecycle of a new OSSM Envoy CVE issue by:
1. Identifying the affected dependency type (C++/Bazel, OpenSSL, Python/pip, Envoy C++ code, proxy-specific vendor)
2. Selecting the appropriate fix pathway (A: dep bump, B: patch-based, D: cherry-pick, E: backport to upstream-EOL branch, P-A: proxy vendor fix, or close as Not a Bug / Won't Do)
3. Managing Jira transitions and field updates throughout the CVE lifecycle
4. Creating fix PRs and coordinating backports across all active OSSM-supported branches
5. Checking upstream sync status (< 1.38 regime) before creating any manual fix PR

## Inputs

The skill gathers via `AskUserQuestion` (or headless `input.yaml`):
- `cve_id`: CVE identifier (e.g., "CVE-2025-12345")
- `dep_name`: affected dependency name
- `dep_type`: category — `bazel_cpp`, `openssl`, `python_pip`, `envoy_cpp`, `proxy_vendor`, `proxy_go`
- `affected_version_range`: version range that is vulnerable
- `current_version`: version currently pinned in `bazel/repository_locations.bzl` (or `requirements.txt`)
- `fixed_version`: available fixed version (null if only a patch-based fix exists)
- `branch`: primary target Envoy branch (e.g., "release/v1.35")
- `ossm_version`: corresponding OSSM version (e.g., "3.2")
- `upstream_eol`: whether the upstream Envoy branch is past its EOL date (true/false)
- `ossm_supported`: whether the OSSM version is still within Red Hat support (true/false)
- `sync_pr_open`: whether an auto-merge sync PR is already open in envoy-openssl (true/false/null for >=1.38)
- `proxy_vendor_present`: whether the dep appears independently in `ossm/vendor/` (true/false/null if not checked)

## Output Artifacts

The skill produces:
1. Dependency type classification with justification
2. Fix pathway selection with rationale
3. Jira transition sequence (transition IDs and VEX if applicable)
4. PR creation commands or closure decision
5. Branch coverage table: branch → current version → in affected range → action

## Key Constraints

- Python/pip deps must always be classified as "Not a Bug" (CI tooling only, VEX "Component not Present")
- Past OSSM EOL branches must be closed as "Won't Do"
- Past upstream Envoy EOL but within OSSM support → Pathway E (no Pathway A/B/D)
- Never create a manual fix PR if an auto-sync PR is already incoming
- VEX justification is required when closing as "Not a Bug"
- Proxy PR is only needed when the dep is independently in `ossm/vendor/`; inherited deps need no proxy PR

## Evaluation Notes

Cases should exercise:
1. Standard Bazel dep bump with a released fixed version (Pathway A) — happy path
2. Branch past upstream Envoy EOL but within OSSM support — requires Pathway E manual backport
3. Python pip dependency → immediate Not a Bug closure with VEX
4. Auto-sync PR already open in envoy-openssl — wait, do not create parallel manual PR
5. Dep independently vendored in the proxy repo — requires Proxy Pathway P-A
