# Claude Code + Codex Sync Hub

A lightweight repository-local coordination starter for a Hyprland desktop shell.
It lives in `tools/agent-sync/`; the shared state file `.ai_sync_hub.json` sits at
the repository root so both agents find it. It provides a JSON blackboard, a watchdog filesystem observer, explicit workflow
transitions, expiring file-lock records, and a bounded review protocol.

## Important limitation

This daemon does **not** autonomously launch or message Claude Code or Codex Cloud.
It records state and watches files. An external dispatcher must start/resume the
appropriate agent task and pass it the relevant request. Claude Code has a CLI/headless
interface that can be automated in a controlled environment. Codex Cloud tasks are
started through the Codex product/workspace workflow; do not assume a local script can
directly control a remote Codex task unless you have an explicitly supported API or
integration for that action.

Filesystem notifications are observations, not proof of which agent made a change.
The daemon cannot undo a write after the fact. For strong enforcement, use separate
worktrees/branches and require agents to acquire a lock before editing and validate
the lock before committing or opening a PR. Keep a human approval gate for merges.

## Roles and authority

- **Codex / Astra: visual owner.** Owns visual direction, design tokens, layout,
  spacing, typography, colour, effects and animation choices.
- **Claude: systems owner.** Owns Wayland/Hyprland IPC, asynchronous event handling,
  system hooks, process lifecycle, memory/resource safety, build reliability and
  measurable performance.
- **Hard requirements override both.** Neither agent may violate safety, functional
  requirements or explicit user requirements.
- **Evidence-based objections only.** A performance objection must identify a
  reproducible issue, measurement, test, or specific mechanism. A design objection
  must point to a concrete hierarchy, spacing, proportion, readability or interaction
  defect.
- **No bickering loop.** One review and one revision per task. Any unresolved material
  conflict is summarized with options, evidence, risks and a recommendation for the
  user. Do not repeat an already-recorded argument without new evidence.

## State transitions

| Trigger | State after event | Next owner |
|---|---|---|
| Initial state | `Astra_Design_Phase` | Astra |
| Astra publishes `design_complete` | `Claude_Performance_Audit` | Claude |
| Claude publishes `performance_audit_complete` | `Astra_Design_Phase` | Astra |
| Claude publishes `integration_complete` | `Astra_Design_Audit` | Astra |
| Astra publishes `design_audit_complete` | `Testing_Phase` | Claude |
| Claude publishes `tests_passed` | `Astra_Design_Phase` | Astra |
| Either agent publishes `blocked` | State unchanged | Escalate |

`Claude_Integration_Phase` is available for an explicit integration task. The daemon
does not infer completion from a file event; agents must publish completion explicitly.

## Install

Python 3.10+ is recommended.

Run everything from the repository root.

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r tools/agent-sync/requirements.txt
```

Only the watcher needs `watchdog`; `status`, `publish`, `lock`, `unlock`, `check`
and `transition` work with plain Python, so agents can call them in any sandbox.

Start the watcher:

```bash
python tools/agent-sync/agent_sync.py watch
```

In another terminal, inspect state:

```bash
python tools/agent-sync/agent_sync.py status
```

`--repo` defaults to the repository the script lives in, so it does not matter
which directory you run it from. Run the tests with:

```bash
python -m pip install pytest
python -m pytest tools/agent-sync/tests
```

## Publish events

When Codex completes a visual implementation:

```bash
python tools/agent-sync/agent_sync.py publish \
  --agent Astra --type design_complete \
  --files src/ui/theme.css src/ui/panel.qml \
  --summary "Implemented the new visual direction" \
  --notes "Please audit blur cost and animation frame-time." \
  --task-id UI-014
```

When Claude finishes the performance audit:

```bash
python tools/agent-sync/agent_sync.py publish \
  --agent Claude --type performance_audit_complete \
  --files src/ui/theme.css \
  --summary "Audit complete; one expensive effect was reduced." \
  --notes "Measured under the agreed test procedure." \
  --task-id UI-014
```

When Claude finishes a system integration:

```bash
python tools/agent-sync/agent_sync.py publish \
  --agent Claude --type integration_complete \
  --files src/wayland/ipc.py src/ui/panel.qml \
  --summary "IPC integration complete; UI contract preserved." \
  --task-id IPC-008
```

When Astra finishes the visual audit:

```bash
python tools/agent-sync/agent_sync.py publish \
  --agent Astra --type design_audit_complete \
  --files src/ui/panel.qml \
  --summary "Spatial hierarchy and proportions verified." \
  --task-id IPC-008
```

When the test suite passes:

```bash
python tools/agent-sync/agent_sync.py publish \
  --agent Claude --type tests_passed \
  --files tests/ \
  --summary "Relevant tests and smoke checks passed." \
  --task-id IPC-008
```

## File locks

Acquire locks before editing files:

```bash
python tools/agent-sync/agent_sync.py lock \
  --agent Astra --files src/ui/theme.css src/ui/panel.qml \
  --task-id UI-014 --ttl 1800
```

Check a lock before editing or committing:

```bash
python tools/agent-sync/agent_sync.py check --agent Claude --file src/ui/theme.css
```

Release locks after the task:

```bash
python tools/agent-sync/agent_sync.py unlock --agent Astra --task-id UI-014
```

Locks expire automatically after their TTL. The JSON blackboard is authoritative for
the orchestrated workflow, but the watcher alone cannot prevent arbitrary writes.
For robust isolation, use separate Git worktrees/branches and make the check command
part of the controlled commit/PR workflow. Do not have both agents edit the same
working tree simultaneously.

## Agent contract

This contract is already in the repository's `AGENTS.md` (read by Codex) and
`CLAUDE.md` (read by Claude Code), so both agents follow it automatically.

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

## Recommended agent dispatch architecture

Keep this daemon independent from provider-specific agent launching:

1. The daemon observes repository changes and reads explicit events.
2. A dispatcher watches for a pending request and creates a task using a supported
   provider interface.
3. The dispatcher includes the current state, task ID, requested files, design brief,
   architecture contract, latest audit notes and review budget.
4. The agent returns a structured result and publishes a completion event.
5. The dispatcher records success/failure and stops after one review + one revision.
6. A human reviews major architecture changes and merges.

Do not put API keys in the JSON file, repository, logs, prompts or Git history. Use
environment variables or the provider's approved authentication flow. Avoid committing
generated logs unless the team intentionally wants them versioned.

## Files generated by the daemon

- `.ai_sync_hub.json`: current state, communication queues, design tokens and recent events.
- `.ai_sync_events.jsonl`: append-only event log (ignored by Git).
- `.ai_sync_hub.lock`: lock file that stops two processes writing the hub at once (ignored by Git).
- `.ai_sync_locks.json`: reserved filename for future external lock adapters; the current
  implementation stores lock records in `.ai_sync_hub.json`.

The event log and lock file are already in `.gitignore`. Keep the blackboard in Git
only if you want state changes shared through commits; Git is not a real-time transport.
