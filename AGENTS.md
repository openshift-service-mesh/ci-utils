# AGENTS.md

Instructions for AI agents working in this repository.

## What this repo is

A Claude Code skills marketplace. The primary contribution unit is a **plugin** — a bundle of slash commands, skills, and agents installable into any project via `/plugin install`. See [docs/README.md](docs/README.md) for an overview.

## Before making changes

- Read [docs/contributing.md](docs/contributing.md) — it covers where skills belong and the required file layout.
- Read [README.md#security-guidelines-for-skill-contributions](README.md#security-guidelines-for-skill-contributions) before touching any skill that interacts with external systems.

## Hard rules

**Evals are not optional.** Every new or significantly modified `SKILL.md` must ship with passing eval infrastructure in the same PR. A skill without evals will not be merged. Run:

```
/eval-analyze --skill <plugin>:<name>
/eval-dataset --count 5
/eval-run --model opus
/eval-optimize   # iterate until all judges pass
```

**Do not execute cloud CLI commands.** Skills must output commands for the user to run, not execute them directly. No `aws`, `kubectl`, `oc`, `gcloud`, or `az` in skill prompts unless the skill explicitly hands control back to the user.

**Agent tool allowlists must be minimal.** When writing or modifying an `agents/*.md` file, only include tools the agent genuinely needs. Do not add `Bash` unless there is no alternative.

**Both plugin manifests are required.** Any plugin addition or rename must update both `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`, and register the plugin in `.claude-plugin/marketplace.json`.

## Where new skills belong

Add to this repo if the skill is useful across multiple projects or teams. Add to the target project's `.claude/` directory if it is tightly coupled to that repo's schema, APIs, or internal conventions. When in doubt, start project-specific — if you copy it to a second repo, move it here.

## Repo layout

```
plugins/<name>/
  .claude-plugin/plugin.json
  .cursor-plugin/plugin.json
  commands/<name>.md       # slash command: frontmatter + prompt
  agents/<name>.md         # subagent: frontmatter (model, color, tools) + prompt
  skills/<name>/
    SKILL.md               # frontmatter (name, description) + structured prompt
    eval.yaml
    eval.md
    eval/cases/            # minimum 5 cases
```
