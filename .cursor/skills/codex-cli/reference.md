# Codex CLI Reference

Official docs used: Codex CLI overview, command reference, and slash-command docs.

## Verification metadata

- Last verified: 2026-02-21
- Refresh trigger: flag mismatch, behavior drift, or command-not-found errors

## Core operator commands

- Install/update: `npm i -g @openai/codex@latest`
- Start: `codex`
- Auth check: `codex login status`
- Login/logout: `codex login`, `codex logout`
- Interactive continuity: `codex resume --last`, `codex fork --last`
- Automation: `codex exec "..."`, `codex exec resume --last`
- Cloud flow: `codex cloud list --json`, `codex apply <TASK_ID>`
- MCP flow: `codex mcp list --json`, `codex mcp add <name> -- <cmd...>`

## High-value flags

- Scope: `-C/--cd`, `--add-dir`
- Safety: `-a/--ask-for-approval`, `-s/--sandbox`, `--full-auto`
- Dangerous (opt-in only): `--yolo`
- Config/model: `-c key=value`, `-p/--profile`, `-m/--model`
- Automation output: `--json`, `--output-last-message`, `--output-schema`

## CI recipes

- Deterministic run:
  - `codex exec --json --output-last-message codex-summary.txt "Run lint/tests and summarize failures"`
- Structured output:
  - `codex exec --output-schema schema.json --output-last-message out.txt "Return release metadata"`
- Retry:
  - `codex exec resume --last "Continue remaining work only"`

## Useful slash commands

- Context/status: `/compact`, `/status`, `/diff`, `/mention`
- Routing/mode: `/plan`, `/model`, `/agent`, `/fork`, `/resume`, `/new`
- Config/safety: `/permissions`, `/debug-config`
- Integrations: `/mcp`, `/review`, `/init`

## Failure recovery

- `command not found` -> reinstall and verify PATH
- auth mismatch -> `codex logout && codex login && codex login status`
- non-zero exec -> rerun with `--json` and inspect failing event
- cloud apply conflict -> sync branch, resolve conflicts, re-run `codex apply`
- MCP failure -> `codex mcp list --json`, validate config, retry `codex mcp login <name>`
