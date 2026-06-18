# ossm-ci Plugin

CI utilities plugin for the OpenShift Service Mesh (OSSM) team. Works natively with both **Claude Code** and **Cursor**.

## Installation

### Claude Code

```bash
/plugin install ossm-ci@ci-utils
```

### Cursor (local)

```bash
ln -s /path/to/ci-utils/plugins/ossm-ci ~/.cursor/plugins/ossm-ci
```

Then restart Cursor or run **Developer: Reload Window**.

## Commands

> **Note:** In Claude Code, commands are namespaced as `/ossm-ci:confidence`, `/ossm-ci:aws-scan`, etc. In Cursor, commands appear without a plugin prefix (e.g., `/confidence`, `/aws-scan`) because Cursor does not yet support `plugin:command` namespacing. This is a [known Cursor limitation](https://forum.cursor.com/t/workspace-skill-resolution-issue-with-identical-skill-names/162287) with an open feature request.

### `/ossm-ci:confidence`
Calculate a data-driven release confidence score (1-10) for an OSSM build using Report Portal test data.

Analyzes test results across FULL/CORE/BASIC scopes, validates test matrix coverage, and provides actionable release recommendations.

**Requirements:** Report Portal MCP server configured.

---

### `/ossm-ci:generate-e2e-tests`
Generate comprehensive Go E2E tests using BDD Ginkgo from project documentation.

Run from the **root of the target project**. Validates documentation quality (threshold: 7/10), applies hidden tags for retry/timeout logic, and produces organized test suites.

**Quick start:**
```bash
cp <ci-utils>/plugins/ossm-ci/skills/generate-e2e-tests/documentation-e2e-generator.yaml ./documentation-e2e-generator.yaml
# Customize, then:
/ossm-ci:generate-e2e-tests
```

See [`skills/generate-e2e-tests/SKILL.md`](skills/generate-e2e-tests/SKILL.md) for full implementation details.

---

### `/ossm-ci:aws-scan`
Gives you the exact commands to download and run the audited read-only inventory script yourself. The script outputs two tables directly in your terminal — Claude does not execute anything.

```bash
curl -O https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/scripts/aws-scan-audited.sh
bash aws-scan-audited.sh
```

**Requirements:** AWS CLI configured with valid credentials.

---

### `/ossm-ci:prow-metrics`
Collect and present Prow CI execution data for OSSM repositories (istio, proxy, sail-operator, ztunnel), with summary statistics and TSV export for Excel. Fetches directly from the Prow API using an inline Python script — no external scripts required.

**Requirements:** `python3` and `jq` available in PATH.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| `generate-e2e-tests` | `/ossm-ci:generate-e2e-tests` | Documentation to Go E2E test generator |

## Notes

All four commands are fully portable and work from any project after installation.

---

## Security Guidelines for Contributors

Skills run inside Claude Code sessions and can interact with a user's machine, credentials, and production systems. Read the general guidelines described in the main README and follow these specific principles when developing OSSM CI skills.

**If a skill needs to run commands against external systems** (AWS, kubectl, APIs, etc.), it must target the OSSM sandbox container (to be created) rather than the user's local machine. The container provides an isolated environment with only the tools and secrets explicitly passed in by the user. Until the container is available, follow the guide-don't-execute pattern.

> If a skill can cause harm without the user noticing, it should not exist. Avoid asking the AI to execute any command that can cause damage if misused, and if you have a strong use case for a skill that needs to execute commands, make sure to implement it in a way that the user is always in control of what is being executed and can review it before execution.
