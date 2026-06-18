---
# Base branch to diff against (auto-detected if omitted)
base_branch: main

# Languages in this project (helps triage grouping)
languages: []

# Paths the model should be aware of for context
# key_paths:
#   auth: "src/auth/"
#   api: "src/api/"
#   frontend: "frontend/src/"

# Any phases to skip by default (can still be run explicitly)
skip_phases: []
---

# Project Context

Describe your project here. This markdown body is free-form context that the
review pipeline reads before analyzing your code. Include anything unusual
about the project that isn't captured in the reference docs:

- Architecture overview
- Key conventions or patterns
- Areas that require special attention
- Any known technical debt or migration in progress

## Setup

1. Copy this file to `.code-reviewer/config.md` in your project root
2. Run `/code-reviewer:setup` to analyze your codebase and generate reference docs
3. Adjust the generated reference docs in `.code-reviewer/reference/`
4. Run `/code-reviewer:review` to start reviewing your changes
