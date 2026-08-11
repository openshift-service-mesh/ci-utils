---
name: envoy-openssl-cve Triage
description: Find new OSSM Envoy CVE issues, classify dependencies, select the correct fix pathway (A/B/D/E/P-A), create PRs across all active branches, and transition Jira tickets through the CVE lifecycle.
command: /envoy-openssl-cve:triage
---

# envoy-openssl-cve — Triage

Ten-step CVE triage process. If the user provided a CVE ID or Jira issue key as an argument, start at Step 1 using that issue rather than running JQL discovery.

---

## Shared reference data

### Repo regimes

- **`< 1.38`**: `envoyproxy/envoy-openssl` — BoringSSL-to-OpenSSL fork; auto-syncs from `envoyproxy/envoy` every 6 hours via `.github/workflows/envoy-sync-scheduled.yaml`.
- **`>= 1.38`**: `envoyproxy/envoy` — upstream repo; OpenSSL selected at build time. No separate fork or sync workflow.
- **Proxy**: `openshift-service-mesh/proxy` — ships Envoy as the `proxyv2` binary; pins Envoy via `ENVOY_SHA` in `WORKSPACE`. A manual proxy PR is only needed when the CVE is in proxy-specific code (`ossm/vendor/<dep>/`).

Throughout this skill, commands show `envoyproxy/envoy-openssl`. **For v1.38+ branches substitute `envoyproxy/envoy`.**

### Tool access check

Run in parallel before proceeding:
- Jira MCP: `jira_search` with `project = OSSM AND component = Envoy AND type = Vulnerability AND summary ~ CVE` (limit 1)
- GitHub CLI: `gh auth status`

### Jira API reference

- **Transition IDs**: New=11, In Progress=41, Closed=61, Release Pending=131; "Code Review" discovered at runtime via `jira_get_transitions`
- **CVE lifecycle**: New → In Progress → (create PRs) → Code Review → (merge PRs) → Release Pending
- **Custom fields**:
  - `customfield_10873` = VEX Justification (select)
  - `customfield_10875` = Git Pull Request (textarea)
- **VEX values**: "Component not Present", "Vulnerable Code not Present", "Vulnerable Code not in Execute Path"
- **API quirks**: `jira_transition_issue` fields is an object; comments must be added separately; VEX set via `jira_update_issue` after transition

**Closure sequences:**
- "Not a Bug": transition (Closed=61) → add comment → set VEX justification
- "Won't Do": transition (Closed=61) → add comment (no VEX)

### Image / issue classification

| Category | Image string | Action |
|---|---|---|
| Proxy binary | `proxyv2-rhel9`, `proxyv2-rhel8` | Main C++ Envoy binary — fix |
| Konflux | `redhat-user-workloads/[envoy-FBC-pattern]` | Confirm from actual Jira issues |
| Bundle / metadata | (confirm from Jira) | OLM or FBC metadata only — close as "Not a Bug", VEX "Component not Present" |

### Dependency categories

| Type | Source of truth | Notes |
|---|---|---|
| **C++ / Bazel** | `bazel/repository_locations.bzl` — `version:` and `cpe:` fields | abseil, grpc, protobuf, re2, c-ares, quiche, jwt_verify_lib, etc. |
| **OpenSSL** | Same file, dep name `openssl` | Core dependency; version 3.0.x |
| **Python / pip** | `tools/base/requirements.txt` | CI/build tooling only — does not ship in the binary; close as "Not a Bug", VEX "Component not Present" |

### Supported branches / version mapping

| Branch | OSSM version | Upstream Envoy EOL | Proxy branch |
|---|---|---|---|
| `release/v1.32` | 3.0 | 2025-10-15 | `release-1.24` |
| `release/v1.34` | 3.1 | 2026-04-15 | `release-1.26` |
| `release/v1.35` | 3.2 | 2026-07-23 | `release-1.27` |
| `release/v1.36` | 3.3 | 2026-10-14 | `release-1.28` |
| `release/v1.38` | 3.4 | 2027-04-23 | `release-1.30` |

`main` = next unreleased version.

**Important**: EOL that governs triage is **OSSM EOL** (Red Hat lifecycle), not upstream Envoy EOL. Always verify at the [Red Hat OpenShift Operator Life Cycles page](https://access.redhat.com/support/policy/updates/openshift_operators) before closing as "Won't Do".

### Build environment

Full local builds are long-running. **Only run locally for Pathway E** (manual backport to upstream-EOL branches). For Pathways A, B, D — rely on CI.

All commands run inside the builder container:

**`release/v1.32` (OSSM 3.0):**
```bash
export ENVOY_DOCKER_BUILD_DIR=./build
export ENVOY_BUILD_IMAGE=quay.io/jwendell/envoy-build-ubuntu:openssl-f94a38f62220a2b017878b790b6ea98a0f6c5f9c
export ENVOY_STDLIB=libstdc++
./ci/run_envoy_docker.sh './ci/do_ci.sh dev //test/...'
```

**`release/v1.34` (OSSM 3.1):**
```bash
export ENVOY_DOCKER_BUILD_DIR=./build
export ENVOY_BUILD_IMAGE=quay.io/jwendell/envoy-build-ubuntu:openssl-cb86d91cf406995012e330ab58830e6ee10240cb
export ENVOY_STDLIB=libstdc++
./ci/run_envoy_docker.sh './ci/do_ci.sh dev //test/...'
```

**`release/v1.35`, `release/v1.36` (OSSM 3.2, 3.3):**
```bash
export ENVOY_DOCKER_BUILD_DIR=./build
export ENVOY_BUILD_IMAGE=quay.io/jwendell/envoy-build-ubuntu:openssl-f4a881a1205e8e6db1a57162faf3df7aed88eae8
./ci/run_envoy_docker.sh './ci/do_ci.sh gcc //test/...'
```

**`release/v1.38+`, `main` (OSSM 3.4+):**
```bash
./ci/run_envoy_docker.sh './ci/do_ci.sh openssl'
```

### PR conventions

- No OSSM Jira keys in PR bodies (public repo)
- `main`-branch PRs get `backport needed` label after merge
- Backport PRs reference the main PR number in the description
- Squash merge only
- Select reviewer once before the first PR; apply the same reviewer to all PRs for this CVE

### Code freeze check

Before creating any backport PR, query GitLab:
```
gitlab.cee.redhat.com/istio/konflux/ossm-fbc
```
Read `renovate.json`, parse `packageRules` for `"automerge": false` matching the target branch. If frozen, hold the backport PR until freeze lifts.

### CVE scan command

```bash
./ci/run_envoy_docker.sh 'bazel test --config=ci --config=cves //tools/dependency:cve_test'
```

---

## Step 1 — Identify new CVE issues

Run this primary JQL query to find all New Envoy issues (broader search to avoid missing CVEs):

```
project = OSSM AND component = Envoy AND type = Vulnerability AND status = New ORDER BY created DESC
```

Client-side filter the results for CVE-related issues by checking any of:
- Labels containing "CVE-"
- Summary containing "CVE"
- Labels containing pscomponent patterns: "proxyv2", "envoy-openssl", "istio-proxyv2"

This broader approach ensures no CVE issues are missed regardless of whether the CVE ID appears in the summary, labels, or pscomponent fields.

If the user provided specific issue keys as arguments, fetch them directly via `jira_get_issue` instead of running discovery queries.

### Presenting Results

Summarize grouped by CVE:
- CVE identifier, affected library, description
- Table of issue keys by image and OSSM version
- Total count
- Whether any are already assigned

### Handling Duplicates

**If you find multiple issues for the same CVE and OSSM version:**
1. Keep the earliest created issue as the primary issue
2. Close all later issues with Resolution = "Duplicate"
3. Add a comment to each duplicate: `Duplicate of <PRIMARY-ISSUE-KEY>. Closing as duplicate.` (include the same rationale as the primary issue if already closed)

**Example:** For CVE-2026-41178 OSSM 3.0, if OSSM-15326 (created first) and OSSM-15351 (created later) both exist, close OSSM-15351 as "Duplicate" with comment "Duplicate of OSSM-15326."

---

## Step 2 — Classify dependency type

Extract the library name and affected version range from the Jira description.

- For **C++/Bazel**: look up the dep by name or CPE in `bazel/repository_locations.bzl`
- For **Python packages** (`tools/base/requirements.txt`): CI/build tooling only, does not ship in the binary — close as "Not a Bug", VEX "Component not Present"
- For **deps in proxy's own vendor** (`ossm/vendor/<dep>/`): independently managed C++ Bazel deps — see Step 7b-proxy and Proxy Pathway P-A
- For **Go modules in the proxy repo** (`go.mod`): CI/test tooling only, not shipped in binary — close as "Not a Bug", VEX "Component not Present" if the issue is about the binary

---

## Step 3 — Handle image-specific and lifecycle cases

**3a. Bundle / OLM metadata images only**: close all issues as "Not a Bug", VEX "Component not Present". No further action.

**3b. EOL branches**: distinguish between two cases:
- **Past OSSM EOL**: close as "Won't Do" with a comment explaining EOL status.
- **Past upstream Envoy EOL but within OSSM support**: do NOT close. The branch is no longer auto-synced from upstream; fixes must be manually backported using **Pathway E**. Continue to Steps 4–9.

**3c. Check `tools/dependency/cve.yaml` ignored list**:
```bash
git show origin/main:tools/dependency/cve.yaml
```
Inspect `ignored_cves:`. If the CVE ID appears with a comment referencing an applied patch or upstream fix, present the finding to the user. Candidate closure: "Not a Bug", VEX "Vulnerable Code not Present".

**3d. Active branches / normal images**: continue to Steps 4–9.

---

## Step 4 — Assign remaining open issues

Ask the user who to assign. Use `jira_update_issue` with `{"assignee": "<email>"}` for all remaining open issues.

---

## Step 5 — Move to In Progress

`jira_transition_issue` with ID "41" for all remaining open issues.

---

## Step 6 — Check upstream sync (< 1.38 branches only)

**For `release/v1.38+`**: no sync workflow — skip 6a–6c and go directly to Step 7.

**For `release/v1.32` – `release/v1.36`**: check whether the fix is already arriving via the automated upstream merge before creating anything manually.

**6a.** Search for a merged upstream fix:
```bash
gh pr list --repo envoyproxy/envoy --search "CVE-<id> is:merged" --limit 10
```

**6b.** Check for an in-flight auto-merge PR in envoy-openssl:
```bash
gh pr list --repo envoyproxy/envoy-openssl --search "auto-merge state:open" --limit 20
```

**6c.** If a relevant upstream PR is merged and the sync has not yet run: note the sync runs every 6 hours. Ask the user whether to wait or trigger manually. Once the sync PR lands, run the CVE scan to confirm resolution, then skip to Step 9.

**6d.** If no upstream fix exists yet, continue to Step 7.

---

## Step 7 — Qualify the vulnerability

**7a.** Extract: library name, affected version range, fixed version (from Jira description or NVD).

**7b.** Check the current version across all active branches:
```bash
git show origin/<branch>:bazel/repository_locations.bzl | grep -A 10 'name = "<dep_name>"'
```
For Python/pip:
```bash
git show origin/<branch>:tools/base/requirements.txt | grep "<package>"
```

Present a table: branch → current version → in affected range? → fixed version available?

**7b-proxy.** If the Jira issue includes `proxyv2` images, check whether the dep is independently vendored in the proxy repo:
```bash
ls ~/PROXY-<ossm-version>/proxy/ossm/vendor/ | grep '<dep>'
grep -A 5 '"<dep_name>"' ~/PROXY-<ossm-version>/proxy/ossm/bazelrc-vendor
```
Extend the version table to include: Proxy branch → dep origin (own `ossm/vendor/` vs. inherited via Envoy SHA) → in affected range?

If the dep is not in `ossm/vendor/`, it is inherited from Envoy — no separate proxy PR needed; CI handles the SHA bump automatically.

**7c.** Early closure conditions:
- Current version outside the affected range → "Not a Bug", VEX "Vulnerable Code not Present"
- Vulnerable code path not compiled into the binary → "Not a Bug", VEX "Vulnerable Code not in Execute Path"
- CVE only affects a platform/arch not used in OSSM builds → "Won't Do" with explanation

---

## Step 8 — Fix the vulnerability

Ask the user to select a reviewer:
```bash
# < 1.38 branches
gh api repos/envoyproxy/envoy-openssl/collaborators --jq '.[].login'
# >= 1.38 branches
gh api repos/envoyproxy/envoy/collaborators --jq '.[].login'
```
Exclude the assignee. The same reviewer applies to all PRs for this CVE.

---

### Pathway A — Standard Bazel dep update

Use when a fixed version of the dep has been released upstream.

```bash
./ci/run_envoy_docker.sh 'bazel run //bazel:update <dep_name> <fixed_version>'
```

This updates `version`, `sha256`, `urls`, and `release_date` in `bazel/repository_locations.bzl` automatically. Run the CVE scan locally to confirm before pushing. Full build verified by CI.

---

### Pathway A (OpenSSL special case)

Same as Pathway A but dep name is `openssl`. After updating, additionally verify the `bssl-compat` layer:
```bash
./ci/run_envoy_docker.sh 'bazel build //bssl-compat/...'
./ci/run_envoy_docker.sh 'bazel test //bssl-compat/...'
```

OpenSSL updates are the highest-risk change — the entire `bssl-compat` shim depends on the OpenSSL ABI. Verify carefully before creating the PR.

---

### Pathway B — Patch-based fix

Use when no fixed upstream release exists yet, but an upstream commit contains the fix.

1. Obtain the fix as a `.patch` file
2. Place in `bazel/` (e.g., `bazel/<dep>-CVE-<id>.patch`)
3. Add to the dep's `patches =` list in `bazel/repositories.bzl`
4. Run the CVE scan locally to confirm
5. Add the CVE ID to `tools/dependency/cve.yaml` under `ignored_cves:` with a comment referencing the patch

---

### Pathway D — Envoy C++ cherry-pick from upstream

Use when the CVE is in Envoy's own C++ code and a fix commit exists in `envoyproxy/envoy`.

1. Find the upstream fix commit SHA:
   ```bash
   gh pr list --repo envoyproxy/envoy --search "CVE-<id> is:merged" --limit 10
   gh pr list --repo envoyproxy/envoy --search "<library-or-component> is:merged" --limit 20
   gh search commits --repo envoyproxy/envoy "<function-or-symbol>" --limit 20
   ```

2. For `main` (< 1.38): check whether the auto-sync is already bringing the fix; if so, wait.

3. For each active release branch:
   ```bash
   git checkout -b fix/CVE-<id>-<branch> origin/<branch>
   git cherry-pick <upstream-SHA>
   ```
   If conflicts required manual resolution, document this in the PR description.

4. No `tools/dependency/cve.yaml` entry required.

---

### Pathway E — Backport to upstream-EOL branch still covered by OSSM

Use when a branch is past its **upstream** Envoy EOL but the OSSM version is still within Red Hat support. Eligible branches today: `release/v1.32`, `release/v1.34` (both in `envoyproxy/envoy-openssl`).

1. Confirm the fix is present in the higher envoy-openssl branch:
   ```bash
   git log origin/release/v1.35 --oneline --grep="CVE-<id>" --all-match
   git log origin/release/v1.35 --oneline -- <affected-file.cc>
   ```

2. Attempt a cherry-pick from the higher envoy-openssl branch:
   ```bash
   git checkout -b fix/CVE-<id>-<branch> origin/<branch>
   git cherry-pick <commit-SHA-from-higher-branch>
   ```

3. If cherry-pick fails: manually port the fix. Document the source commit, why cherry-pick failed, and how the port preserves fix intent.

4. Verify using the release-specific build command (see Build environment section above).

---

### Proxy pathway (openshift-service-mesh/proxy)

Apply only when Step 7b-proxy confirms the CVE requires a fix in proxy-specific code (`ossm/vendor/<dep>/`). All Envoy fix PRs must be merged first.

Select a reviewer:
```bash
gh api repos/openshift-service-mesh/proxy/collaborators --jq '.[].login'
```

**Proxy Pathway P-A — Proxy-specific code fix:**
1. Update `ENVOY_SHA` and `ENVOY_SHA256` in `WORKSPACE`
2. Update the dep source in `ossm/vendor/<dep>/`
3. Refresh `ossm/bazelrc-vendor`: `ossm/scripts/update-deps.sh`
4. Open one PR per active proxy branch; rely on CI to verify

**Proxy Pathway P-Go — Go module update (CI tooling only):**
```bash
go get <package>@<fixed-version>
go mod tidy
```
If the Jira issue is about the binary, close as "Not a Bug", VEX "Component not Present".

---

### After the main-branch PR

- Add `backport needed` label
- Request the selected reviewer
- Ask user whether to add the PR to the GitHub Project

### Backporting

One PR per active OSSM-supported branch. For each branch:
1. Check code freeze
2. Determine if the branch is within upstream EOL (Pathway A/B/D) or past upstream EOL within OSSM support (Pathway E)
3. Create branch: `git checkout -b fix/CVE-<id>-<branch> origin/<branch>`
4. Run CVE scan (Pathway A/B) or full release-specific build (Pathway E)
5. PR description: `Backport of #<main-PR-number>: fix CVE-<id> in <dep>`
6. Assign + request the same reviewer

---

## Step 9 — Transition to Code Review

**9a.** Set `customfield_10875` (Git Pull Request) on each Jira issue to the matching PR URL.

**9b.** Discover the "Code Review" transition ID via `jira_get_transitions`. Transition all open issues.

**9c.** Send a handoff message to the reviewer with a summary table:

| Branch | PR URL | CI status |
|---|---|---|
| main | ... | pending / passing |
| release/vX.Y | ... | ... |

---

## Step 10 — Review existing In Progress CVEs

Query in-progress CVEs:
```
project = OSSM AND component = Envoy AND type = Vulnerability AND status = "In Progress" ORDER BY created DESC
```

Group by CVE identifier. For each, identify blockers:
- Upstream fix not yet merged
- Auto-merge sync PR blocked by a conflict
- Bazel dep update failed CVE verification or build
- Missing backport PRs for active branches
- Jira `customfield_10875` not updated with PR URLs

Present findings and act on any unblocked CVEs.
