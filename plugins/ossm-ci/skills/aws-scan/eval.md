---
skill: aws-scan
analyzed_at: 2026-06-15T00:00:00Z
skill_hash: a1b2c3d4e5f6
execution_mode: batch
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - commands_provided
  - no_self_execution
  - flag_handling
  - no_fabricated_data
---

# aws-scan Analysis

## Purpose

`aws-scan` is a minimal delivery skill: its sole responsibility is to hand the user a `curl` + `bash` command pair that downloads and runs an audited AWS inventory script. It surfaces dangling and active resources across an AWS account without requiring the AI to have AWS credentials or interpret any output.

The skill is strictly read-only from Claude's perspective — it never executes the script, never reads its output, and never fabricates resource counts.

## Inputs

The skill accepts two optional inputs provided via `AskUserQuestion` when not running headless:
- `regions`: comma-separated AWS region identifiers (optional; omit for all regions)
- `resources`: comma-separated resource type identifiers (optional; omit for all types)

In headless mode these are supplied via `input.yaml`.

## Output Artifacts

The skill produces **no files**. Its output is a formatted message to the user containing:
1. The `curl` download command for `aws-scan-audited.sh`
2. The `bash` run command, with optional `--regions` / `--resources` flags when requested
3. A brief description of the two output tables the script produces

## Sub-skills and Pipeline

No sub-skills. Single-turn response.

## Key Constraints

- The skill must never execute the script itself.
- The skill must never parse or summarize actual AWS resource output.
- The script URL is fixed: `https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/scripts/aws-scan-audited.sh`
- When no filters are requested, no flags should be added to the command.

## Evaluation Notes

Test cases should exercise:
1. Default invocation — both commands provided, no flags
2. Region-filtered invocation — `--regions` flag correct
3. Resource-filtered invocation — `--resources` flag correct

The critical judges are: commands are present, the script is never self-executed, and no resource data is fabricated.
