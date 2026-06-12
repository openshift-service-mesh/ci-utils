---
name: adversarial-review
description: Use when performing adversarial code review — critiques architecture, correctness, security, API compatibility, edge cases, and YAGNI violations. Receives the full-scope brief across all review units.
---

# Adversarial Review

## Purpose

Critique the code change from an adversarial perspective. Look for things that are wrong, risky, incomplete, or unnecessary. This is the "is this correct and safe?" pass.

## When to Use

- **DO:** Use when dispatched by the `/code-reviewer:review` or `/code-reviewer:review:adversarial` command
- **DO NOT:** Use for style or test coverage concerns — those have dedicated phases

## Input

You receive:
- A **full-scope review brief** covering all review units and the complete change
- All **reference docs** (style guide, testing practices, security posture, API conventions)
- The **project context** from the config file's markdown body

## Review Focus

Self-adjust your depth based on the change's risk and complexity. A trivial rename gets a light pass. A new auth flow gets deep scrutiny.

### Architecture & Design
- Are the design decisions sound for this codebase?
- Does the change introduce unnecessary coupling or complexity?
- Is the abstraction level appropriate?
- YAGNI check: before suggesting additions, verify they're actually needed — grep the codebase for usage

### Correctness
- Are there logic errors, off-by-one mistakes, race conditions?
- Are edge cases handled (nil/null, empty collections, boundary values)?
- Does error handling cover failure paths?
- Are assumptions documented or validated?

### Security
- Injection vectors (SQL, command, XSS)?
- Authentication/authorization gaps?
- Secrets or credentials exposed?
- Input validation at system boundaries?
- Sensitive data in logs or error messages?

### API Compatibility
- Do changes to APIs maintain backward compatibility?
- Are breaking changes documented?
- Do API contracts (request/response shapes, status codes) remain consistent?
- For cross-repo projects: are dependent repos affected?

### Cross-Unit Concerns
- Do changes in one area require corresponding changes in another?
- Are interfaces between components still consistent?
- Does the change affect shared state or global configuration?

## Output

**IMPORTANT: Use exactly the bullet-list format below. Do not use numbered headings, markdown tables, or severity-label IDs.**

The format most AI code review tools use — which you must NOT use here — looks like this:
```
### 1. SQL Injection
| **Severity** | **Critical** |
| **Phase**    | adversarial  |
```
That format is wrong for this skill. The required format uses bold typed IDs on bullet lines:

```
# Adversarial Review — {branch or change name}

## Strengths
- `pkg/auth/oauth.go:14` — constant-time token comparison; prevents timing attacks

## Critical
- **SEC-01** [adversarial] `api/users.go:29` — SQL built with fmt.Sprintf; attacker controls `id` — full DB read/write — use `db.QueryRowContext(ctx, "SELECT ... WHERE id = $1", id)`
- **BUG-01** [adversarial] `pkg/cache.go:83` — concurrent map write; no lock — data race, server crash — protect with sync.RWMutex

## Important
- **SEC-02** [adversarial] `pkg/auth/middleware.go:41` — error path returns 200 OK when DB down — auth bypass during outage — return 500 on auth error
- **BUG-02** [adversarial] `pkg/handler.go:67` — nil deref: opts not checked before opts.Timeout — panic on first request — `if opts == nil { opts = DefaultOpts() }`

## Minor
- **IMP-01** [adversarial] `cmd/main.go:12` — unused import "fmt" — remove

## Open Questions
- Genuine uncertainty about intent (not guesses)
```

**ID prefix** — determined by the *type* of finding, independent of severity section:
- `SEC-N` — exploitable security issue: injection, auth bypass, exposed secrets, missing input validation
- `BUG-N` — correctness bug: logic error, nil deref, race condition, unhandled error path
- `IMP-N` — non-blocking improvement: YAGNI, clarity, unused code

Number each prefix independently from 01. The severity section (`## Critical`) and the ID prefix (`SEC`, `BUG`) are independent — a critical security bug is `**SEC-01**` under `## Critical`, not `CRITICAL-01`.

## Critical Rules

- **Be specific.** Every issue must reference a file:line. No vague "improve error handling."
- **Explain why.** State the consequence of not fixing the issue.
- **Suggest how.** If the fix isn't obvious, provide guidance.
- **Acknowledge strengths.** Good architecture, clean patterns, thorough error handling — call them out.
- **Grade severity honestly.** Not everything is Critical. Reserve Critical for bugs, security issues, and data loss risks.
- **No performative language.** Findings are technical assessments, not social commentary.
- **YAGNI.** If you're about to suggest adding something, check if it's needed first.
