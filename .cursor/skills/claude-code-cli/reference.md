# Claude Code CLI Reference

Official docs used: Claude Code overview, CLI reference, and skills docs.

## Verification metadata

- Last verified: 2026-02-21
- Refresh trigger: mismatch between docs and `claude --help`

## Core operator commands

- Start REPL: `claude`
- One-shot automation: `claude -p "task"`
- Continue/resume: `claude -c`, `claude -r "<session>"`
- Update/version: `claude update`, `claude -v`
- Agent/MCP ops: `claude agents`, `claude mcp`
- Remote/web flow: `claude --remote "task"`, `claude --teleport`
- Worktree run: `claude -w <name>`

## High-value flags

- Scope/session: `--add-dir`, `--session-id`, `--fork-session`
- Execution bounds: `--max-turns`, `--max-budget-usd`
- Output format: `--output-format`, `--json-schema`, `--input-format`
- Tool controls: `--tools`, `--allowedTools`, `--disallowedTools`
- Permissions: `--permission-mode`
- Dangerous (explicit opt-in): `--dangerously-skip-permissions`
- Config: `--settings`, `--setting-sources`, `--mcp-config`, `--strict-mcp-config`
- Prompt strategy: prefer `--append-system-prompt` over full prompt replacement

## CI recipes

- Deterministic audit:
  - `claude -p --output-format json --max-turns 4 "Review changed files for security regressions"`
- Structured response:
  - `claude -p --output-format json --json-schema '{"type":"object","properties":{"summary":{"type":"string"}},"required":["summary"]}' "Summarize release risk"`
- Retry-safe bounded run:
  - `claude -p --max-turns 3 --max-budget-usd 2.00 "Continue unresolved checks only"`

## Skills quick facts

- Skill paths:
  - Personal: `~/.claude/skills/<name>/SKILL.md`
  - Project: `.claude/skills/<name>/SKILL.md`
- Invocation:
  - Manual: `/skill-name [args]`
  - Auto: based on `description` unless disabled
- Important frontmatter:
  - `disable-model-invocation`, `user-invocable`, `allowed-tools`, `context: fork`
- Argument placeholders:
  - `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `${CLAUDE_SESSION_ID}`

## Failure recovery

- `command not found` -> reinstall + verify `claude -v`
- unknown flag -> check local `claude --help`, then downgrade command complexity
- resume issues -> use explicit `-r "<session>"` instead of `-c`
- noisy parser output -> force `--output-format json` + bounded turns
- MCP ambiguity -> run with `--strict-mcp-config --mcp-config <file>`
