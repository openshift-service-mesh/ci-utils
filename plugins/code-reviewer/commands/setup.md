---
name: setup
description: Onboard a project for code review — analyzes codebase and generates reference docs
argument-hint:
---

# Review Setup — Project Onboarding

You are onboarding a project for code review. This is a hybrid process: automated analysis followed by interactive confirmation with the engineer.

## Step 0: Check for Existing Setup

Check if `.code-reviewer/reference/` already exists with reference docs. If not, also check the legacy path `.claude/code-reviewer/reference/`.

If found (in either location), ask:
> "Found existing reference docs. Would you like to:"
> 1. **Refresh** — analyze the current codebase and merge updates into existing docs (preserves changelog)
> 2. **Start fresh** — delete existing docs and regenerate from scratch

If found at the legacy path only, also offer to migrate:
> 3. **Migrate** — move `.claude/code-reviewer/` to `.code-reviewer/` and refresh

New setups always write to `.code-reviewer/`.

Wait for the user's response before proceeding.

## Step 1: Discovery

Scan the project for existing standards and patterns:

### Existing Documentation
Search for and read (if found):
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` — AI assistant instructions
- `STYLE_GUIDE.*`, `CODING_STANDARDS.*` — style documentation
- `CONTRIBUTING.md`, `CONTRIBUTING.*` — contribution guidelines
- `.editorconfig`, `.prettierrc`, `.eslintrc.*`, `.golangci.yml` — linter/formatter configs
- `Makefile`, `package.json`, `go.mod` — build/dependency context
- CI config (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`)

### Code Patterns
Sample representative files across the project:
- Pick 3-5 files per language detected
- Analyze: naming conventions, import ordering, code structure, comment patterns
- Look for consistent patterns that aren't documented

### Test Patterns
Find and analyze test files:
- Test frameworks used
- Test file naming conventions (e.g., `*_test.go`, `*.test.ts`, `*.spec.ts`)
- Test structure (describe/it, table-driven, arrange-act-assert)
- Test location conventions (co-located, separate `tests/` directory)
- Mocking patterns

### Security Patterns (if applicable)
- Auth/authz code locations
- Input validation patterns
- Secrets management approach

### API Patterns (if applicable)
- API definition approach (REST, gRPC, GraphQL)
- Endpoint naming and versioning conventions
- Request/response patterns

## Step 2: Draft Generation

Generate draft reference docs based on discovery. For each doc:

### Style Guide
- If the project already has a comprehensive style guide, reference it (e.g., "See AGENTS.md §Code Standards") rather than duplicating
- Add patterns detected in code that aren't documented
- Organize by category (naming, imports, formatting, file organization, language-specific)

### Testing Practices
- Test frameworks and their usage patterns
- Naming conventions for test files and test functions
- Structural patterns (table-driven, BDD, etc.)
- Coverage expectations (explicit or inferred)

### Security Posture (skip if not applicable)
- Sensitive code paths and their locations
- Auth patterns and conventions
- Input validation approach
- Secrets handling

### API Conventions (skip if not applicable)
- Naming and versioning patterns
- Request/response conventions
- Error handling patterns

Each doc must follow the reference doc structure:
```
---
format_version: 1
---

# [Topic] — [Project Name]

## Conventions
[organized by category]

## Changelog
| Date | Change | Trigger |
|------|--------|---------|
| {today} | Initial generation | /code-reviewer:setup |
```

## Step 3: Interactive Confirmation

Present each draft doc's key findings to the engineer **one section at a time**:

For each convention or pattern you found:
- State what you found and where
- Ask if it should be enforced, documented, or skipped
- Incorporate the engineer's feedback

Examples:
- "I found that you use table-driven tests in Go (see `pkg/auth/auth_test.go:15`). Should I enforce this pattern?"
- "Your AGENTS.md says to sort struct fields alphabetically. I'll reference that directly rather than duplicating."
- "I didn't find API versioning documentation. Should I skip the API conventions doc, or do you have conventions I should capture?"

If the engineer says to skip a doc entirely, don't create it.

## Step 4: Write & Store

1. Create `.code-reviewer/reference/` directory (if it doesn't exist)
2. Write each confirmed reference doc
3. Create or update `.code-reviewer/config.md` config:
   - Auto-detect `base_branch` from git
   - Set `languages` based on what was discovered
   - Set `key_paths` based on discovered project structure
   - Markdown body: brief project context summary
4. Ask the user whether to commit or gitignore the generated files:
   > "Would you like to commit these files to the repo? Committing means `/code-reviewer:setup` only needs to be run once and all team members share the same conventions. Alternatively, I can add them to `.gitignore` so each developer maintains their own local copy."

   - **If committing:** check `.gitignore` for any existing entries that would block the files and offer to remove them.
   - **If gitignoring:** add `.code-reviewer/` to `.gitignore` if not already present.
5. Confirm to the user:
   > "Setup complete. Generated reference docs:"
   > - `.code-reviewer/reference/style-guide.md`
   > - `.code-reviewer/reference/testing-practices.md`
   > - [etc.]
   >
   > "You can now run `/code-reviewer:review` to review your changes. To re-generate or update these docs later, run `/code-reviewer:setup` again."

## Important Notes

- Do NOT skip the interactive confirmation step — the engineer must validate every convention
- Do NOT duplicate content from existing docs — reference them instead
- Do NOT create docs the engineer says to skip
- If in refresh mode, preserve existing changelog entries and merge new findings
