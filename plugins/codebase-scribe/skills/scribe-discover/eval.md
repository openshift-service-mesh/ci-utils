---
skill: scribe-discover
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: d1d64ff3a1d6
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - inventory_yaml_valid
  - languages_detected
  - components_enumerated
  - discovery_accuracy
---

# scribe-discover Analysis

## Purpose

`scribe-discover` is the first skill in the `codebase-scribe` pipeline. It performs a systematic inventory of the current codebase and writes the results to `.claude/scribe/inventory.yaml`. The inventory is the shared data artifact that all other scribe skills (`scribe-draft`, `scribe-maintain`, `scribe-review`) read to understand the project structure without re-reading the full codebase.

The discovery is **non-interactive** — it reads the workspace and infers everything without asking the user for input.

## Inputs

The skill takes no arguments. It reads from the current working directory:
- All source files (filtered by extension to detect languages and frameworks)
- Configuration files (`go.mod`, `package.json`, `pyproject.toml`, `Makefile`, `Cargo.toml`, etc.) for build system and dependency detection
- Existing documentation (README.md, CONTRIBUTING.md, AGENTS.md, CLAUDE.md) for enriched context
- Test files to detect testing frameworks and patterns

## Output Artifacts

The skill writes **`.claude/scribe/inventory.yaml`** with the following structure:

```yaml
project:
  name: <detected from config or directory name>
  description: <one-paragraph description>
  type: service | library | tool | monorepo

languages:
  primary: go
  secondary: [bash, yaml]

frameworks:
  - name: gin
    purpose: HTTP router
    version: v1.9.1

architecture:
  pattern: REST microservice | ML pipeline | CLI tool | monorepo | ...
  description: <2-3 sentences>
  components:
    - name: <component name>
      path: <relative path>
      type: handler | model | service | repository | utility | test
      description: <one sentence>

entry_points: [main.go, cmd/server/main.go]
build_system: {name: go, config_file: go.mod, commands: {build: go build ./..., test: go test ./...}}
test_framework: {name: testing, test_dir: ., config: null}
key_directories: [{path: handlers/, purpose: HTTP request handlers}]
dependencies: [{name: gin, version: v1.9.1, purpose: HTTP routing}]
```

## Key Behavioral Constraints

- **No user prompts**: `scribe-discover` is fully headless.
- **Component specificity**: components must be named from actual directories/packages, not generic placeholders.
- **Framework detection from files**: frameworks must be detected from actual config files or import statements, not guessed from directory names.
- **Existing docs as enrichment**: if README or AGENTS.md exist, use them to improve description quality — don't duplicate or ignore them.

## Relationship to Other Skills

- `scribe-draft` reads inventory.yaml as its primary input for generating AGENT.md
- `scribe-maintain` re-runs scribe-discover to detect drift (stale inventory → drift detected)
- `scribe-review` reads inventory.yaml to check if AGENT.md is consistent with current project state

## Evaluation Notes

Files are written to disk, so judges use `outputs["files"]` to access inventory.yaml. Key quality signals:

1. **YAML validity**: inventory.yaml must be parseable with all required top-level keys
2. **Language accuracy**: detected languages match the workspace file extensions
3. **Component completeness**: architecture.components count matches workspace structure
4. **Build system accuracy**: correct config file cited, correct commands

The evaluation dataset uses sample workspace directories with different project types to verify detection accuracy across languages and frameworks.
