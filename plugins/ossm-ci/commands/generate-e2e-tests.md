---
name: generate-e2e-tests
description: Generate comprehensive Go E2E tests using BDD Ginkgo from project documentation.
---

## Name
ossm-ci:generate-e2e-tests

## Synopsis
```
/ossm-ci:generate-e2e-tests
```

## Description

Analyzes a project's documentation folder and generates production-ready Go E2E test suites using BDD Ginkgo. Validates documentation quality, applies retry logic, and produces organized test files with helpers.

Run this command from the **root directory** of the target project.

**Quick start with config file (recommended):**
```bash
cp <path-to-ci-utils>/plugins/ossm-ci/skills/generate-e2e-tests/documentation-e2e-generator.yaml ./documentation-e2e-generator.yaml
# Customize for your project, then run:
/ossm-ci:generate-e2e-tests
```

## Implementation

Load and follow the full implementation guide in the `skills/generate-e2e-tests/SKILL.md` file from the ossm-ci plugin. That file contains:

- Pre-execution validation steps (directory, config, path verification)
- Documentation quality requirements and scoring matrix (threshold: 7/10)
- Hidden tag support (`<!-- TEST-TIMEOUT -->`, `<!-- TEST-RETRY -->`, etc.)
- BDD Ginkgo test generation patterns with retry and validation logic
- Output structure: `tests/e2e/documentation/` + `tests/e2e/helpers/`
- Error handling and actionable improvement guidance
