# aerolith

## Claude Code + Codex sync

Claude Code and Codex coordinate their work in this repository through a shared
state file, `.ai_sync_hub.json`, and the helper in
[`tools/agent-sync`](tools/agent-sync/README.md). The rules each agent follows
are in [`AGENTS.md`](AGENTS.md) (Codex) and [`CLAUDE.md`](CLAUDE.md) (Claude Code).

```bash
python tools/agent-sync/agent_sync.py status   # show the current state
python tools/agent-sync/agent_sync.py watch    # run the watcher (needs watchdog)
```
