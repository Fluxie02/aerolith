# Agent instructions

This repository is worked on by two AI agents that coordinate through
`.ai_sync_hub.json` and `tools/agent-sync/agent_sync.py`
(full docs: `tools/agent-sync/README.md`).

You are **Astra (Codex)**. Use `--agent Astra` in every sync command.

- **Astra (Codex)** owns the visual side: design tokens, layout, spacing,
  typography, colour, effects and animation.
- **Claude (Claude Code)** owns the systems side: Hyprland/Wayland IPC, async
  events, process lifecycle, resource safety, build reliability and performance.

## Quick commands

```bash
python tools/agent-sync/agent_sync.py status
python tools/agent-sync/agent_sync.py lock --agent Astra --files <paths> --task-id <ID>
python tools/agent-sync/agent_sync.py check --agent Astra --file <path>
python tools/agent-sync/agent_sync.py publish --agent Astra --type <event> --files <paths> --summary "..." --task-id <ID>
python tools/agent-sync/agent_sync.py unlock --agent Astra --task-id <ID>
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
