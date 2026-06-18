---
skill: headless-setup
analyzed_at: 2026-06-08T00:00:00Z
skill_hash: 5c815f38b858
execution_mode: case
headless: true
dry_run: false
suggested_judges:
  - cost_budget
  - reference_docs_exist
  - config_md_valid
  - no_user_prompts
  - convention_accuracy
---

# headless-setup Analysis

## Purpose

`headless-setup` is the **non-interactive** variant of the code-reviewer setup skill. It discovers project conventions by reading the codebase (source files, test files, existing documentation like README, CONTRIBUTING.md, AGENTS.md) and generates the reference documentation suite without prompting the user for any input.

This is the correct setup path for CI/CD environments, automated onboarding, and cases where the engineer wants convention documentation auto-generated from the existing codebase rather than defined interactively.

## Inputs

The skill takes no arguments — it operates entirely on the current working directory. It:
1. Detects languages from file extensions in the workspace
2. Reads existing documentation (README, CONTRIBUTING, STYLE_GUIDE, AGENTS.md) if present
3. Inspects source files and test files for actual patterns
4. Determines the project's `base_branch` from git config or defaults to `main`

## Output Artifacts

The skill generates files in `.code-reviewer/`:

### Reference Docs (`reference/` subdirectory)

Always generated:
- **`style-guide.md`**: naming conventions, import patterns, formatting rules, file organization
- **`testing-practices.md`**: test framework, test file naming, test coverage expectations

Conditionally generated (only if relevant patterns found):
- **`security-posture.md`**: security constraints if auth/crypto/input handling code is present
- **`api-conventions.md`**: API design conventions if route definitions or API schemas are found

Each file structure:
```
---
format_version: 1
---
## Conventions
[subsections per category]

## Changelog
| Date | Change | Trigger |
|------|--------|---------|
| YYYY-MM-DD | Initial generation | headless-setup |
```

### Configuration

- **`config.md`**: YAML frontmatter + markdown body
  - Frontmatter: `base_branch`, `languages` (list), `key_paths` (optional), `skip_phases` (list)
  - Body: 2-3 sentence project context summary

## Key Behavioral Constraints

- **Absolutely no user prompts**: `AskUserQuestion` must never be called in headless mode. The skill must make all decisions autonomously.
- **Convention specificity**: conventions must be derived from actual code patterns, not generic best practices. "Functions use camelCase" is derived; "follow Go conventions" is not.
- **Trigger in changelog**: every generated file must record "headless-setup" as the trigger in the first changelog entry.
- **Conditional generation**: security and API docs must not be generated if no relevant code is found — generating them with empty conventions is worse than omitting them.

## Evaluation Notes

Since files are written to disk (not stdout), judges use `outputs["files"]` to access generated content. The key quality signals are:

1. **Required files created**: style-guide.md and testing-practices.md are always required
2. **YAML frontmatter valid**: `format_version: 1` present, parseable YAML delimiters
3. **Section structure**: `## Conventions` and `## Changelog` sections present
4. **No prompts**: any detected `AskUserQuestion` call is a failure
5. **Convention specificity**: conventions should reference specific patterns from the sample code

The evaluation dataset should include workspaces of different project types (Go, Python, TypeScript, mixed) to verify language-specific convention detection. Cases with and without existing documentation verify that existing docs are referenced rather than duplicated.
