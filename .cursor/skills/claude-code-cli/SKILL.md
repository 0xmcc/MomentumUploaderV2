---
name: claude-code-cli
description: Operates Claude Code CLI for interactive sessions, scripted runs, session resumption, permission controls, and skill authoring. Use when users ask about Claude Code CLI commands, flags, print mode, MCP, agent teams, slash commands, or .claude/skills workflows.
---

# Claude Code CLI

Use this skill for tasks involving Anthropic Claude Code terminal workflows.

## Scope and defaults

- Prefer explicit, safe command lines: clear permission mode, minimal tool scope, and reproducible settings.
- Distinguish interactive (`claude`) from automation (`claude -p ...`) before giving commands.
- For scripting, prefer machine-readable output and bounded execution (`--output-format`, `--max-turns`, budget controls).
- Do not default to dangerous permission bypass flags.

## Version and drift policy

- Treat command/flag guidance as tied to current Claude Code docs and installed CLI behavior.
- If docs and local behavior diverge, prefer local behavior and explicitly flag likely version drift.
- Before recommending less-common flags, verify they are present in current `claude --help` output.

## Quickstart workflow

1. Install (pick platform path):
   - macOS/Linux/WSL: `curl -fsSL https://claude.ai/install.sh | bash`
   - Homebrew: `brew install --cask claude-code`
   - Windows: `winget install Anthropic.ClaudeCode`
2. Start in repo:
   - `cd <project>`
   - `claude`
3. First-run login via prompt.
4. Validate:
   - `claude -v`
   - Optional: run a short test prompt.

## Command decision tree

- **Interactive REPL** -> `claude`
- **One-shot programmatic run** -> `claude -p "..."` (print mode)
- **Continue latest session** -> `claude -c`
- **Resume named/session-id** -> `claude -r "<session>"`
- **Start isolated git worktree session** -> `claude -w <name>`
- **Manage MCP servers** -> `claude mcp`
- **List configured subagents** -> `claude agents`
- **Remote/web handoff** -> `claude --remote "..."`, `claude --teleport`

## High-value flags to prefer

- Session and model control:
  - `--model <alias-or-full-name>`, `--fallback-model <model>`
  - `--session-id <uuid>`, `--fork-session`
  - `--no-session-persistence` (print mode)
- Execution boundaries:
  - `--max-turns <n>`, `--max-budget-usd <amount>`
  - `--permission-mode <mode>`
  - `--tools "Bash,Read,Edit"` or `--allowedTools ...` / `--disallowedTools ...`
- Output and automation:
  - `--output-format text|json|stream-json`
  - `--json-schema '<schema>'`
  - `--input-format text|stream-json`
- Context and config:
  - `--add-dir <path>` (repeatable)
  - `--settings <json-file-or-string>`
  - `--setting-sources user,project,local`
  - `--mcp-config <path-or-json>`, `--strict-mcp-config`

## Prompt customization strategy

Use append-style prompt flags by default to preserve Claude Code’s built-in behavior:

- Preferred:
  - `--append-system-prompt "..."`
  - `--append-system-prompt-file <file>`
- Advanced/replace-all:
  - `--system-prompt "..."`
  - `--system-prompt-file <file>`

Use replacement only when full behavioral override is intentional.

## Skill authoring in Claude Code

When users ask for custom slash workflows:

- Skill location:
  - Personal: `~/.claude/skills/<skill-name>/SKILL.md`
  - Project: `.claude/skills/<skill-name>/SKILL.md`
- Include frontmatter with at least `name` and `description`.
- Use `disable-model-invocation: true` for side-effecting workflows (deploy, release, production actions).
- Keep `SKILL.md` concise; move details to supporting files.

## Permission/risk matrix

- Low risk: explicit `--tools` subset + conservative `--permission-mode`
- Medium risk: broader toolset with bounded turns/budget
- High risk: `--dangerously-skip-permissions` or unconstrained tool access in write-capable repos
- If user provides no risk preference, default to low risk and provide an upgrade path.

## Troubleshooting playbook

- CLI not responding as expected: check `claude -v` and `claude --help` for flag availability.
- Resume issues: use explicit `--resume <id>` then fallback `-c`.
- Print mode instability: add `--max-turns` and `--output-format json` to stabilize automation.
- MCP-related failures: validate `--mcp-config` path and retry with `--strict-mcp-config` for deterministic loading.

## Response format when helping a user

1. Identify intended mode: REPL, print-mode automation, or remote/web handoff.
2. Provide the shortest safe command sequence first.
3. Add one stricter alternative (more constrained tools/permissions).
4. End with a verification command/output check.
5. Include a fallback command if the primary path fails.

## Additional resources

- Detailed command and skill mechanics: [reference.md](reference.md)
