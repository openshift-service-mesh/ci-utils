# Contributing a Skill

## Where does it belong?

| Criterion | This repo (ci-utils) | Project-specific repo |
|---|---|---|
| Useful across multiple repos/teams | Yes | No |
| Domain-generic (review, docs, CI) | Yes | No |
| Tightly coupled to one repo's schema or APIs | No | Yes |

**Rule of thumb:** start project-specific in `.claude/`. If you copy it to a second repo, move it here.

**Examples:**
- `/code-reviewer:review` — central. Any project benefits; per-project config is handled via `.code-reviewer/`.
- A skill that reads `my-service/internal/schema_v3.go` to generate docs — project-specific.
- `/ossm-ci:confidence` — central within OSSM. Integrates with shared Report Portal infrastructure.

## Creating a Skill

Minimal plugin layout:

```
plugins/<name>/
  .claude-plugin/plugin.json    # name, version, description, author, license
  .cursor-plugin/plugin.json    # same schema — required for Cursor support
  commands/<name>.md            # YAML frontmatter (name, description, argument-hint) + prompt
  skills/<name>/
    SKILL.md                    # YAML frontmatter (name, description) + structured prompt
    eval.yaml                   # judges, thresholds, model
    eval.md                     # skill analysis: inputs, output format, judge rationale
    eval/cases/
      case-001-<scenario>/
        input.yaml
        annotations.yaml
      ...                       # minimum 5 cases
  agents/<name>.md              # if dispatching subagents: name, description, model, color, tools
```

Checklist before opening a PR:

- [ ] `SKILL.md` has `name` + `description` frontmatter and a clear purpose/workflow/output body
- [ ] Command `.md` has `name`, `description`, `argument-hint` frontmatter
- [ ] Agent `.md` has `model`, `color`, `tools` frontmatter with a minimal tool allowlist — `model` optional for plugins shipping to multiple hosts
- [ ] Plugin listed in `.claude-plugin/marketplace.json` (new plugins only)
- [ ] Both `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json` present
- [ ] Version string identical across both `plugin.json` files and both `marketplace.json` entries — for `codebase-scribe`, run `bash plugins/codebase-scribe/scripts/check-sync.sh` (exits 0 when all four agree)

## Eval

Every skill must ship with passing evals before it can merge:

```
/eval-analyze --skill <plugin>:<name>   # generates eval.yaml and eval.md from SKILL.md
/eval-dataset --count 5                 # generates realistic test cases
/eval-run --model opus                  # scores against all cases
/eval-optimize                          # edits SKILL.md until all judges pass
```

See [../README.md#eval-requirements-for-new-skills](../README.md#eval-requirements-for-new-skills) for the full spec.

## Security

Skills run inside a developer's editor session and can reach their credentials and cloud accounts. Before opening a PR, read [../README.md#security-guidelines-for-skill-contributions](../README.md#security-guidelines-for-skill-contributions).

Key rules:
- Do not execute cloud CLI commands (AWS, kubectl, oc) directly — output them and let the user run.
- Keep `tools` allowlists minimal; exclude `Bash` unless genuinely required.
- If a skill interacts with an external system, add a warning banner in its documentation.
