---
name: envoy-openssl-cve Review
description: Review open OSSM Envoy CVE PRs across all active branches, verify CI, approve and merge in the correct order, then transition Jira tickets to Release Pending.
command: /envoy-openssl-cve:review
---

# envoy-openssl-cve — Review

Seven-step CVE review process (R1–R7). If the user provided a CVE ID or PR number as an argument, start at Step R2 using that item rather than running the full PR discovery queries.

---

## Shared reference data

### Repo regimes

- **`release/v1.32` – `release/v1.36`**: PRs are in `envoyproxy/envoy-openssl`
- **`release/v1.38+`**: PRs are in `envoyproxy/envoy`
- **Proxy PRs**: `openshift-service-mesh/proxy` — only when the CVE is in proxy-specific vendored deps

Commands below use `envoyproxy/envoy-openssl`. **Substitute `envoyproxy/envoy` for v1.38+ PRs.**

### Jira API reference

- **Custom fields**:
  - `customfield_10873` = VEX Justification
  - `customfield_10875` = Git Pull Request
- **Transition IDs**: Release Pending=131; discover others at runtime via `jira_get_transitions`

### Supported branches / version mapping

| Branch | OSSM version | Upstream Envoy EOL | Proxy branch |
|---|---|---|---|
| `release/v1.32` | 3.0 | 2025-10-15 | `release-1.24` |
| `release/v1.34` | 3.1 | 2026-04-15 | `release-1.26` |
| `release/v1.35` | 3.2 | 2026-07-23 | `release-1.27` |
| `release/v1.36` | 3.3 | 2026-10-14 | `release-1.28` |
| `release/v1.38` | 3.4 | 2027-04-23 | `release-1.30` |

### Code freeze check

Before merging any backport PR, query GitLab `gitlab.cee.redhat.com/istio/konflux/ossm-fbc`. Read `renovate.json`, parse `packageRules` for `"automerge": false` matching the target branch. If frozen, hold the merge until freeze lifts.

---

## Step R1 — Find CVEs pending review

Search for open CVE PRs in all three repos in parallel:
```bash
gh pr list --repo envoyproxy/envoy-openssl --search "CVE in:title state:open" --limit 50
gh pr list --repo envoyproxy/envoy --search "CVE in:title state:open" --limit 50
gh pr list --repo openshift-service-mesh/proxy --search "CVE in:title state:open" --limit 50
```

Group PRs by CVE identifier. For each CVE, search Jira:
```
project = OSSM AND component = Envoy AND type = Vulnerability AND summary ~ "<CVE-id>"
```

If the user provides a specific CVE ID, PR number, or Jira issue key, start there.

---

## Step R2 — Gather PR details

For each PR in parallel:
- `gh pr view <number> --repo envoyproxy/envoy-openssl` — metadata, description, target branch
- `gh pr diff --name-only <number> --repo envoyproxy/envoy-openssl` — changed files
- `gh pr checks <number> --repo envoyproxy/envoy-openssl` — CI status
- `gh pr diff <number> --repo envoyproxy/envoy-openssl` — full diff

**Reading the diff by pathway:**
- **Pathway A** (Bazel dep bump): meaningful change is in `bazel/repository_locations.bzl` — `version`, `sha256`, `urls`, `release_date`
- **Pathway B** (patch-based): new `.patch` file in `bazel/`, `patches =` update in `bazel/repositories.bzl`, new entry in `tools/dependency/cve.yaml` `ignored_cves:`
- **Pathway D** (Envoy C++ cherry-pick): `.cc`/`.h` changes, no Bazel config changes; confirm the commit matches the upstream fix SHA
- **Pathway E** (manual backport to upstream-EOL branch): C++ source changes, potentially restructured; PR description must identify the source commit and explain any divergence
- **Proxy Pathway P-A** (vendored dep update): diff is in `ossm/vendor/<dep>/` and `ossm/bazelrc-vendor`
- **Proxy Pathway P-Go** (Go module update): diff is in `go.mod` and `go.sum` only

---

## Step R3 — Summarize fix

Produce a unified summary per CVE:
- CVE ID, affected library, vulnerability type
- Fix mechanism: A (Bazel version bump) / B (patch file) / D (C++ cherry-pick) / E (manual backport to upstream-EOL branch)
- Old version → new version (A), patch from commit `<SHA>` (B), commit `<SHA>` cherry-picked (D), manually ported from higher branch commit `<SHA>` (E)
- Files changed beyond the expected set
- OpenSSL-specific: whether `bssl-compat` build/test was also verified

---

## Step R4 — Cross-branch consistency check

Verify across all PRs for this CVE:

- Same target dep version on all branches (A), same patch (B), same upstream commit cherry-picked (D)
  - Exception: Pathway E branches will have a structurally different diff — verify fix intent is equivalent, not that the diff is identical
- Each PR targets the correct branch
- For Pathway E branches: confirm the branch is within OSSM support lifecycle
- All active non-EOL branches have a corresponding PR
- For proxy PRs: only present when the CVE is in proxy-specific vendored code; absence is expected for Envoy-only fixes
- No unexpected extra files changed
- Backport PRs reference the main PR number in the description
- For Pathway A: `version`, `sha256`, `urls`, `release_date` updated consistently
- For Pathway B: `tools/dependency/cve.yaml` `ignored_cves:` entry present on all branches
- For Pathway D: no Bazel config changes expected; upstream commit SHA documented in PR description
- For Pathway E: PR description must identify the source commit and explain any manual porting decisions

---

## Step R5 — CI status check

Run `gh pr checks <number> --repo <repo>` for each PR.

If any checks are pending, poll every 2 minutes up to 20 minutes. On failure, report the specific failing job and ask the user how to proceed.

Key CI jobs to confirm passing:
- Presubmit (Bazel build + full test suite via EngFlow RBE) — job is named `envoy-openssl` in `envoyproxy/envoy-openssl` and `envoy` in `envoyproxy/envoy`
- CVE scan: `bazel test --config=cves //tools/dependency:cve_test` — must report no hit for the fixed dep
- For proxy PRs: confirm the presubmit triggered by `ossm/ci/pre-submit.sh` passes (Bazel build + Bazel tests + Go tests all green)

---

## Step R6 — Approve and merge

**Pre-merge checklist:**
- [ ] Fix correctly addresses the CVE (right dep, right version or patch)
- [ ] All branch PRs are consistent (Step R4 passed)
- [ ] CI passes on all PRs (Step R5 passed)
- [ ] Code freeze not active on any target branch
- [ ] For OpenSSL updates: `bssl-compat` tests confirmed passing

**Merge order:**
1. Envoy PRs first: `main`, then backports from newest to oldest (`release/v1.36` → `release/v1.35` → `release/v1.34` → `release/v1.32`)
2. Proxy PR (if needed): after all Envoy PRs are merged, so the proxy PR can include the updated `ENVOY_SHA`

For each Envoy PR:
```bash
gh pr review <number> --repo envoyproxy/envoy-openssl --approve
gh pr merge <number> --repo envoyproxy/envoy-openssl --squash
```

For the proxy PR (if needed):
```bash
gh pr review <number> --repo openshift-service-mesh/proxy --approve
gh pr merge <number> --repo openshift-service-mesh/proxy --squash
```

After all PRs are merged: add `backport completed` label to the main PR.

---

## Step R7 — Update Jira

Get fix versions:
```
jira_get_project_versions(project="OSSM")
```

For each open Jira issue (should be in "Code Review" state):
- Set `fixVersions` to the matching OSSM release version(s)
- Discover the Release Pending transition ID via `jira_get_transitions`
- Transition all issues to Release Pending

Present a final summary table:

| CVE | Branch | PR | Merged | Jira issue | Fix version set |
|---|---|---|---|---|---|
| CVE-XXXX-YYYY | main | #NNN | yes | OSSM-NNN | OSSM 3.x |
| CVE-XXXX-YYYY | release/v1.35 | #NNN | yes | OSSM-NNN | OSSM 3.2 |
