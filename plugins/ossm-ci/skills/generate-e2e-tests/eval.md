---
skill: generate-e2e-tests
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: ec8259a2a682
execution_mode: batch
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - test_files_generated
  - ginkgo_structure_valid
  - helper_files_present
  - test_config_valid
  - documentation_accuracy
---

# generate-e2e-tests Analysis

## Purpose

`generate-e2e-tests` converts human-readable OSSM/Kubernetes documentation (markdown, AsciiDoc) into executable Go E2E test suites written for the Ginkgo BDD framework. It is designed to close the loop between documentation and testing by ensuring that every documented procedure has a corresponding test that validates it against a live cluster.

The skill operates in **batch mode**: it takes a top-level configuration specifying a documentation folder and target output directory, recursively scans all documentation files, applies a quality gate (threshold 1–10), and either produces a complete test suite or returns a structured quality assessment explaining why the threshold was not met.

## Inputs

The skill is invoked interactively with `AskUserQuestion` calls to gather:
- `documentation_path`: folder containing source documentation to convert
- `output_path`: target directory for generated test files (default: `tests/e2e`)
- `project_name`: Go package identifier
- `quality_settings.threshold`: minimum quality score (default: 7)
- `environment`: cluster type and auth method for proper test setup/teardown

Documentation files may contain optional HTML comment annotations (`<!-- TEST-TIMEOUT -->`, `<!-- TEST-RETRY -->`, `<!-- TEST-VALIDATION -->`) that provide hints to the generator for test boundary detection and retry configuration.

## Output Artifacts

When the quality threshold is met, the skill produces:

1. **`{output_path}/documentation/*.go`** — Ginkgo BDD test files, one per documentation topic, structured as:
   - `var _ = Describe("Feature", func() { ... })` outer blocks
   - `Context` blocks grouping related scenarios
   - `It` blocks for individual test cases
   - `By()` step annotations mapping to documented procedures
   - `Eventually()` assertions for async operations
   - `Expect()` validations for synchronous checks

2. **`{output_path}/helpers/*.go`** — Utility files:
   - `validation.go`: reusable validation helpers
   - `retry.go`: retry logic with configurable backoff
   - `setup.go`: cluster setup/teardown helpers

3. **`test-config.yaml`** — Test runtime configuration with sections: `timeouts`, `retries`, `validation`, `environment`

When the quality threshold is **not** met, no test files are generated and instead a quality assessment report is returned with the score, blocking issues, and suggestions for improving the documentation before retrying.

## Sub-skills and Pipeline

This skill executes as a standalone batch operation — no sub-skills are invoked. The processing pipeline is internal:
1. Documentation scan and parsing
2. Quality scoring (thoroughness, clarity, completeness, testability)
3. Test boundary detection (section headers, HTML annotations)
4. Go code generation with Ginkgo patterns
5. Helper file synthesis
6. Configuration file generation

## Key Constraints

- The `--headless` flag suppresses all `AskUserQuestion` calls; when passed, input must be provided via environment/config rather than interactively.
- Quality gate is strictly enforced: a score below threshold produces zero test files.
- All generated Go code must compile and follow Ginkgo v2 conventions.
- The `project_name` drives Go package declarations across all generated files.

## Evaluation Notes

Evaluating this skill requires real documentation input files. The dataset schema should include a `docs/` subdirectory with markdown/adoc files of varying quality to test the quality gate behavior. Cases should cover:
1. High-quality documentation → test files generated (quality ≥ threshold)
2. Low-quality documentation → quality gate blocks generation
3. Documentation with HTML annotations → annotations honored in test structure

The key quality signals are: Ginkgo structure validity, accuracy of `By()` step text relative to documented procedures, helper file completeness, and test-config.yaml structure.
