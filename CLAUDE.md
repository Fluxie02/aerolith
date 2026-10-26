# Agent instructions

This repository is worked on by two AI agents that coordinate through
`.ai_sync_hub.json` and `tools/agent-sync/agent_sync.py`
(full docs: `tools/agent-sync/README.md`).

You are **Claude (Claude Code)**. Use `--agent Claude` in every sync command.

- **Astra (Codex)** owns the visual side: design tokens, layout, spacing,
  typography, colour, effects and animation.
- **Claude (Claude Code)** owns the systems side: Hyprland/Wayland IPC, async
  events, process lifecycle, resource safety, build reliability and performance.

## Delegating to Astra

Do not do Astra's work yourself. For design tokens, layout, spacing,
typography, colour, effects or animation, delegate to Astra with the
`codex_design_task` tool from the `codex-bridge` MCP server, then review
the result once.

Astra runs on the Codex CLI. The bridge picks the ChatGPT account per kind of
work (`CODEX_ACCOUNTS` in `.mcp.json`, details in `codex-mcp-bridge/README.md`):
design work and `visual_design` reviews use `dad` (up to 80% of its limit, the
rest is left to its owner); delegate through the bridge rather than the Codex
plugin, which ignores the caps.

The owner's own account, `mine`, is a coding buddy on GPT-6.1 Sol and never
does design work. Use `codex_coding_buddy` for a second opinion on systems
code (`advise` is read-only, `edit` may change files) and `codex_review_diff`
with a non-visual focus to review your changes. You still own the systems
work and its result; review what the buddy says before acting on it.

Each account needs a login in each new cloud container. If `codex_status`
reports one is not logged in, run `CODEX_HOME=~/.codex-accounts/mine codex
login --device-auth` (for `mine`) or `codex login --device-auth` (for `dad`)
in the background and give the user the link and one-time code, saying which
account it is for; never store or ask for Codex tokens. If no account can take
a design job, tell the user and leave the visual work undone rather than doing
it yourself.

## Quick commands

```bash
python tools/agent-sync/agent_sync.py status
python tools/agent-sync/agent_sync.py lock --agent Claude --files <paths> --task-id <ID>
python tools/agent-sync/agent_sync.py check --agent Claude --file <path>
python tools/agent-sync/agent_sync.py publish --agent Claude --type <event> --files <paths> --summary "..." --task-id <ID>
python tools/agent-sync/agent_sync.py unlock --agent Claude --task-id <ID>
```

These commands need only plain Python 3.10+. `check` exits with code 2 when
a file is locked by the other agent.

## Contract

```text
Before editing:
1. Read .ai_sync_hub.json, plus DESIGN_BRIEF.md, ARCHITECTURE.md and DECISIONS.md if they exist.
2. Confirm system_state and workflow.current_owner match the task assignment.
3. Acquire locks for every file you intend to modify.
4. Work only within your assigned domain and listed files.
5. Do not edit files locked by the other agent.
6. Keep changes focused; do not opportunistically refactor unrelated files.

After editing:
7. Run the required tests and report exact commands/results.
8. Publish an explicit completion event with changed files, summary, task ID,
   and evidence/notes.
9. Release your locks.
10. Review the other agent's work once. Give actionable findings, each with
    severity, evidence, affected file, and minimal proposed correction.
11. Allow one revision. If still unresolved, record alternatives and escalate.
12. Never claim a cloud agent has been dispatched unless a supported dispatcher
    actually started the task.
```
