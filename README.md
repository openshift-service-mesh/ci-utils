# ci-utils

Shared utilities to standardize and simplify build, test, and deployment pipelines for the OSSM team.

## Table of Contents

- [Claude Code Plugin](#claude-code-plugin)
  - [Installation](#installation)
    - [Step 1: Add the marketplace](#step-1-add-the-marketplace)
    - [Step 2: Install the plugin](#step-2-install-the-plugin)
    - [Step 3: Reload plugins](#step-3-reload-plugins)
  - [Commands](#commands)
- [Repository Structure](#repository-structure)
  - [report\_portal/](#report_portal)
  - [skip\_tests/](#skip_tests)
  - [scripts/](#scripts)
  - [ai-helpers/](#ai-helpers)
  - [plugins/](#plugins)
  - [images/](#images)

---

## Claude Code Plugin

This repository is a **Claude Code skills marketplace**. Team members can install plugins into any project to get AI-powered utilities as slash commands.

Available plugins:
- **`ossm-ci`** — CI utilities: release confidence scoring, E2E test generation, AWS resource inventory, and Prow CI metrics
- **`code-reviewer`** — Multi-phase code review with auto-maintained project conventions
- **`codebase-scribe`** — Generate, enrich, and maintain agentic development documentation for any codebase

### Installation

Plugins hosted on GitHub must be added as a marketplace first, then installed individually.

#### Step 1: Add the marketplace

```
/plugin marketplace add openshift-service-mesh/ci-utils
```

This registers the repo as a marketplace using the `name` field from its `.claude-plugin/marketplace.json`. The marketplace is registered as **`ci-utils`**.

#### Step 2: Install the plugin(s)

```
/plugin install ossm-ci@ci-utils
/plugin install code-reviewer@ci-utils
/plugin install codebase-scribe@ci-utils
```

#### Step 3: Reload plugins

```
/reload-plugins
```

> **What does NOT work**
>
> | Command | Why it fails |
> |---|---|
> | `/plugin install ossm-ci@openshift-service-mesh/ci-utils` | The `org/repo` format is not a registered marketplace name |
> | `/plugin install openshift-service-mesh/ci-utils` | Treated as a plugin name, not a marketplace |
>
> The target GitHub repo must contain `.claude-plugin/marketplace.json` with a `plugins` array listing available plugins.

### Commands — ossm-ci

#### `/ossm-ci:confidence`
Calculates a data-driven release confidence score (1–10) for an OSSM build by analyzing test results from Report Portal. Determines the required test scope (FULL/CORE/BASIC), validates test matrix coverage across platforms and environments, and provides a scored breakdown with a GO/NO-GO release recommendation.

**Requires:** Report Portal MCP server configured in Claude Code.

---

#### `/ossm-ci:generate-e2e-tests`
Generates production-ready Go E2E tests using BDD Ginkgo from a project's documentation. Validates documentation quality against a scoring threshold (7/10 minimum), extracts hidden tags for retry/timeout/validation logic, and produces organized test files with helpers.

Run from the **root of the target project**. Copy the config template to get started:
```bash
cp <ci-utils>/plugins/ossm-ci/skills/generate-e2e-tests/documentation-e2e-generator.yaml ./documentation-e2e-generator.yaml
```

---

#### `/ossm-ci:aws-scan`
Gives you the exact commands to download and run the audited inventory script yourself. The script outputs two tables directly in your terminal: potentially dangling resources and a complete inventory. Claude does not execute anything — you run the script, you see the results.

```bash
curl -O https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/scripts/aws-scan-audited.sh
bash aws-scan-audited.sh
```

**Requires:** AWS CLI configured with valid credentials. See [`scripts/aws-scan-audited.sh`](scripts/aws-scan-audited.sh) for the full read-only script.

---

#### `/ossm-ci:prow-metrics`
Collects and presents Prow CI execution data for OSSM repositories (istio, proxy, sail-operator, ztunnel). Shows summary statistics, median execution times by job type, infrastructure usage, failed/pending jobs, and exports a TSV file for Excel import. Fetches directly from the Prow API — works from any project.

**Requires:** `python3` available in PATH.

---

### Commands — code-reviewer

#### `/code-reviewer:setup`
Onboard a project for code review. Analyzes your codebase, discovers existing standards and patterns, and interactively generates reference docs (style guide, testing practices, etc.). Run this once before your first review.

---

#### `/code-reviewer:review`
Run a multi-phase code review pipeline on your current branch changes. Dispatches three specialized review subagents in parallel (adversarial, style, testing), consolidates findings with deduplication, and produces a verdict.

Supports phase-specific variants:
```
/code-reviewer:review                    # Full pipeline — all three phases
/code-reviewer:review:adversarial        # Adversarial phase only
/code-reviewer:review:style              # Style phase only
/code-reviewer:review:testing            # Testing phase only
```

---

#### `/code-reviewer:ci-review`
Fully autonomous code review for CI pipelines. Runs all three review phases without user interaction, auto-generates reference docs if they don't exist, and posts results directly to the PR as inline review comments and a summary comment.

Designed for GitHub Actions workflows. See [`plugins/code-reviewer/README.md`](plugins/code-reviewer/README.md) for setup instructions and example workflow.

**Requires:** Claude Code CLI, `ANTHROPIC_API_KEY`, `gh` CLI authenticated with PR read/write permissions.

Also available for **Cursor** via install script. See [`plugins/code-reviewer/README.md`](plugins/code-reviewer/README.md) for full details, Cursor installation, and CI workflow examples.

---

### Commands — codebase-scribe

#### `/codebase-scribe`
Generate, enrich, and maintain agentic development documentation. Auto-detects mode based on documentation state: **seed** (no docs — scans repo, proposes topics, creates stubs), **draft** (stubs exist — reads source code, fills content, extracts claims), or **maintain** (docs current — detects drift, auto-fixes references, flags changes for review).

Supports context and focus arguments:
```
/codebase-scribe                                    # Auto-detect mode
/codebase-scribe "we migrated from Webpack to Vite" # Context-biased topic selection
/codebase-scribe focus:"auth and RBAC system"       # SME-directed deep documentation
```

Every documentation change goes through an automated review gate that verifies content against source code before finalizing.

See [`plugins/codebase-scribe/README.md`](plugins/codebase-scribe/README.md) for configuration, output structure, and branching strategies.

---

## Security Guidelines for Skill Contributions

Skills in this repository run inside Claude Code sessions, which means they can potentially execute commands on a user's machine and interact with their credentials, cloud accounts, and production systems. Contributors must follow these rules when adding or modifying skills.

### What skills MUST NOT do

- **Avoid executing cloud CLI commands directly** (AWS, GCP, Azure, kubectl, etc.). Claude is not a trusted executor — use an audited script that the user runs themselves. If you need to run any kind of command ensure that your user has restricted priviledges to avoid any potential damage and you do it following security best practices. For example, if you need to run AWS CLI commands, use an IAM user with read-only permissions and no access to sensitive resources, or if you need to run kubectl commands, use a kubeconfig with read-only permissions unless the skill is specifically designed for cluster administration and the user understands the risks.
- **Access secrets, tokens, or credentials** beyond what is strictly needed to read public data. Avoid any skill that requires access to sensitive information unless it is designed with strict security controls and the user is fully aware of the implications.

### What skills SHOULD do instead

- **Use `allowedTools: []`** fill the allowed tools with the list of tools that the skill needs to run, and make sure to not include any tool that can cause harm if misused (e.g. AWS CLI, kubectl, oc, gcloud, az, etc.). This way you can ensure that the skill cannot execute any command that is not explicitly allowed.
- **Keep audited scripts in `scripts/`**, version-controlled and reviewable, rather than generating them on the fly. 
- **Be a reporter, not an actor.** The safest skills take data the user provides and format or analyze it — they do not reach out to external systems on their own. Only create skills that execute commands if there is a clear user need that cannot be met by a non-executing skill, and if you do,make sure that the user is the one pressing the button to run the command, not Claude automatically.
- **If you are going to add steps that interact with external systems, add a big warning banner in the skill documentation** so future maintainers understand the risks and guidelines.

### Executing commands against external systems

If a skill genuinely needs to run commands against external tools (AWS CLI, kubectl, oc, APIs, etc.), the recommended approach is to **run the skill inside the OSSM sandbox container** (to be created) rather than on the user's local machine.

The container will provide:
- A controlled, isolated environment — no access to the user's local credentials or filesystem beyond what is explicitly mounted
- Only the tools and binaries needed for the task (AWS CLI, kubectl, etc.)
- Environment variables and secrets passed in explicitly by the user at run time, scoped to the session

This means: **do not assume the user's local environment has the right tools or credentials.** Design skills that require external execution to target the container, and document clearly which tools and environment variables must be provided.

> **This container does not exist yet.** Until it is available, skills that require external command execution must follow the guide-don't-execute pattern: output the commands, let the user run them.

### The principle

> If a skill can cause harm without the user noticing, it should not exist.

When in doubt, ask: *could this skill delete something important or expose credentials if Claude misunderstood the task?* If yes, redesign it so the user is always the one pressing the button.

---

## Repository Structure

### `report_portal/`

A **centralized, generic script** used by CI jobs across all OSSM repositories to send JUnit XML test results to Report Portal via Data Router. Instead of each repository maintaining its own reporting logic, they all reference this single script, ensuring consistent test reporting across the team.

**Key features:**
- Works with any CI system (GitHub Actions, GitLab CI, Jenkins, Prow)
- Supports credentials via environment variables or mounted secret files
- Dry-run mode for safe configuration testing
- Credentials are never logged — always redacted in output

See [`report_portal/README.md`](report_portal/README.md) for full environment variable reference and CI examples.

---

### `skip_tests/`

Centralized YAML configuration that controls which Istio integration tests are skipped or run across different CI streams and branches. All test runners (midstream_sail, midstream_helm, downstream) consume these files to ensure consistent test execution across environments.

**Files:**
| File | Purpose |
|------|---------|
| `test-config-full.yaml` | Skip configuration for full test suite runs (nightly, release validation) |
| `test-config-smoke.yaml` | Skip configuration for smoke/quick validation runs |
| `parse-test-config.sh` | Parser that reads a config file and sets environment variables for `integ-suite-ocp.sh` |

**How it works:** CI jobs download the config and parser from this repo, run the parser for their stream and branch, and pass the resulting environment variables to the test runner:

```bash
curl -O https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/skip_tests/test-config-full.yaml
curl -O https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/skip_tests/parse-test-config.sh
chmod +x ./parse-test-config.sh

eval $(./parse-test-config.sh test-config-full.yaml security midstream_sail main)
integ-suite-ocp.sh "$SKIP_PARSER_SUITE" "$SKIP_PARSER_SKIP_TESTS" "$SKIP_PARSER_SKIP_SUBSUITES" "$SKIP_PARSER_RUN_TESTS_ONLY"
```

See [`skip_tests/README.md`](skip_tests/README.md) for full configuration reference.

---

### `scripts/`

Standalone scripts that can be run directly from the command line.

| Script | Description |
|--------|-------------|
| `scripts/aws-scan-audited.sh` | Read-only AWS inventory. Scans all regions for EC2, EBS, Elastic IPs, S3, RDS, and ELBs. Outputs two formatted tables directly to the terminal: potentially dangling resources and a complete inventory. No mutating commands anywhere in the file. |
| `scripts/prow-metrics/collect_ossm_data.py` | Collects Prow CI job data for OSSM repositories and exports a TSV file for Excel import. |

---

### `ai-helpers/`

Configuration and documentation supporting the `/ossm-ci:confidence` plugin command.

| File | Description |
|------|-------------|
| `ossm-config.json` | Confidence score weights, test scope matrix, OCP version mappings, and Report Portal project settings |
| `ossm-release-confidence.md` | Architecture documentation for the Next-Gen OSSM Release Process initiative (Jira Epic: OSSM-11131) |

---

### `plugins/`

The Claude Code skills marketplace structure. Contains plugins with commands and skills installable via `/plugin install`.

```
plugins/
├── ossm-ci/
│   ├── commands/         # Slash command definitions
│   │   ├── confidence.md
│   │   ├── generate-e2e-tests.md
│   │   ├── aws-scan.md
│   │   └── prow-metrics.md
│   └── skills/
│       └── generate-e2e-tests/
│           ├── SKILL.md                          # Full skill implementation
│           └── documentation-e2e-generator.yaml  # Config template
├── code-reviewer/
│   ├── commands/         # Slash command definitions
│   │   ├── ci-review.md  # Autonomous CI pipeline
│   │   ├── review.md     # Interactive review
│   │   └── setup.md      # Interactive project onboarding
│   ├── agents/           # Review subagent prompts
│   │   ├── adversarial-reviewer.md
│   │   ├── style-reviewer.md
│   │   └── testing-reviewer.md
│   ├── skills/           # Orchestration and phase skills
│   │   ├── triage/
│   │   ├── consolidation/
│   │   ├── doc-update/
│   │   ├── headless-setup/  # Non-interactive setup for CI
│   │   ├── adversarial-review/
│   │   ├── style-review/
│   │   └── testing-review/
│   ├── templates/        # Brief and report templates
│   ├── examples/         # Example project config
│   └── install-cursor.sh # Cursor IDE install script
└── codebase-scribe/
    ├── commands/
    │   └── codebase-scribe.md  # Main orchestrator command
    ├── hooks/
    │   ├── hooks.json          # PostToolUse doc validation
    │   └── doc-validate.sh
    └── skills/
        ├── scribe-discover/    # Stub creator for approved topics
        ├── scribe-draft/       # Source code reader and content generator
        ├── scribe-maintain/    # Drift detection and auto-fix
        ├── scribe-review/      # Two-pass documentation verification
        └── prompts/
            └── review-adversarial.md
```

---

### `images/`

A container image providing a safe, isolated environment for running Claude Code skills that interact with external systems. Skills that need to execute commands against AWS, Kubernetes, or other tools should run inside this container rather than on the user's local machine.

| Image | Base | Use case |
|-------|------|----------|
| `Dockerfile.local` | Debian Bookworm Slim | Local development, kind, and OpenShift clusters |

See [`images/README.md`](images/README.md) for build and run instructions. Currently there is no CI automation to generate and publish this images, it can be built locally using the make target and you can push to `sail-dev` repository on [quay.io](https://quay.io/repository/sail-dev/ossm-ai-local?tab=tags) or your own registry.
