---
name: codex-cli
description: Operates OpenAI Codex CLI safely and efficiently for interactive coding, non-interactive automation, and session management. Use when users ask about Codex CLI/Codec CLI setup, commands, flags, slash commands, cloud tasks, approvals, sandbox modes, or scripting Codex in CI.
---

# Codex CLI

Use this skill when the user asks to install, configure, troubleshoot, or automate OpenAI Codex CLI (sometimes written as "codec CLI").

## Scope and defaults

- Treat "codec CLI" as "Codex CLI" unless the user explicitly means something else.
- Prefer safe defaults first: scoped directories, explicit sandboxing, and non-dangerous approval modes.
- For automation, prefer `codex exec` with deterministic outputs (`--json`, `--output-last-message`, `--output-schema`).
- Call out experimental commands before suggesting them.

## Version and drift policy

- Treat this skill as valid only for the current Codex CLI command surface in official docs.
- Before proposing risky or uncommon flags, verify they still exist in current docs/changelog.
- If user behavior differs from docs, prefer observed CLI behavior and explicitly note potential version drift.

## Quickstart workflow

1. Install/upgrade:
   - `npm i -g @openai/codex`
   - `npm i -g @openai/codex@latest`
2. Start session:
   - `codex`
3. Authenticate:
   - ChatGPT login flow (default) or API key flow
   - Check login status in scripts with `codex login status`
4. Validate runtime assumptions:
   - Confirm current directory, repository, and sandbox mode before edits.

## Core command decision tree

- **Interactive coding session** -> `codex`
- **One-shot script/CI run** -> `codex exec "..."` (or `codex e`)
- **Continue a prior interactive session** -> `codex resume --last` or `codex resume <SESSION_ID>`
- **Continue a non-interactive run** -> `codex exec resume --last` or `codex exec resume <SESSION_ID>`
- **Cloud task lifecycle** -> `codex cloud ...` then `codex apply <TASK_ID>`
- **Feature toggles** -> `codex features list|enable|disable`
- **MCP server config** -> `codex mcp ...`

## High-value flags to prefer

- Safety/permissions:
  - `--ask-for-approval untrusted|on-request|never`
  - `--sandbox read-only|workspace-write|danger-full-access`
  - `--add-dir <path>` for extra writable scope
  - Avoid `--yolo` unless user explicitly accepts risk
- Session/config:
  - `-C/--cd <path>`, `-m/--model <name>`, `-p/--profile <profile>`, `-c key=value`
- Non-interactive output:
  - `codex exec --json`
  - `codex exec --output-last-message <file>`
  - `codex exec --output-schema <json-schema-file>`

## Interactive slash-command playbook

Use slash commands to steer a live session without restart:

- Context/scope management: `/compact`, `/status`, `/mention`, `/diff`
- Mode/routing: `/plan`, `/model`, `/personality`, `/agent`, `/fork`, `/resume`, `/new`
- Safety/config: `/permissions`, `/debug-config`, `/statusline`
- Integrations/tooling: `/mcp`, `/apps`, `/review`, `/init`

If the session is long or noisy, run `/compact` before major new tasks.

## Automation patterns

- Deterministic CI run:
  - `codex exec --json --output-last-message result.txt "Run lint and summarize failures"`
- Schema-constrained output:
  - `codex exec --output-schema schema.json "Return release metadata"`
- Resume latest run:
  - `codex exec resume --last "Continue with remaining fixes"`

For unattended workflows, combine explicit sandbox/approval flags with stable prompts and capture artifacts to files.

## Safety guidance

- Prefer `--add-dir` over `--sandbox danger-full-access`.
- Only recommend `--dangerously-bypass-approvals-and-sandbox` (`--yolo`) in explicitly hardened environments.
- Warn when mixing low-friction automation (`--full-auto`) with bypass flags.
- For team use, move defaults into config profiles and keep CLI invocations minimal.

### Permission/risk matrix

- Low risk: `--sandbox read-only` + `--ask-for-approval untrusted`
- Medium risk: `--sandbox workspace-write` + `--ask-for-approval on-request`
- High risk: `--sandbox danger-full-access` or `--yolo`
- If user does not specify, default to low/medium depending on whether edits are required.

## Troubleshooting playbook

- Auth errors: run `codex login status`, then re-run `codex login`.
- Session resume mismatch: retry with explicit ID (`codex resume <SESSION_ID>`), then `--last`.
- Non-interactive failures: repeat with `codex exec --json` and inspect failing event/tool step.
- Cloud apply conflicts: treat as patch conflict; rebase/update branch, then retry `codex apply <TASK_ID>`.

## Response format when helping a user

1. Clarify the target workflow (interactive, CI, cloud, or MCP).
2. Provide a minimal command sequence first.
3. Add one safer alternative if the first sequence is risky.
4. Include a quick verification step (`git diff`, status command, or output file check).
5. Include an explicit rollback path when commands may mutate repo or environment.

## Additional resources

- Detailed command/flag map: [reference.md](reference.md)
