# aerolith

## Installer

Run `./install.sh` interactively, or choose the integrations explicitly:

```bash
./install.sh --yes --ai none --startup manual --direction piyti
aerolith install --yes --ai none --startup manual --direction thears --dry-run
aerolith status --json
```

The installer asks for the application direction once: **PIYTI** (default,
app windows become part of the shell instrument; the forward design) or
**THEARS** (apps take on SHEAR's look; maintained). Non-interactive installs
default to PIYTI. Reinstall/upgrade keeps the existing choice unless you pass
`--direction piyti|thears`; restart the shell to apply an intentional change.
There is no direction control in Settings. Intensity remains live-switchable
with `aerolith intensity saturated|insane`.

The installation-owned `$XDG_CONFIG_HOME/aerolith/installation.json` (normally
`~/.config/aerolith/installation.json`) holds `{"direction":"piyti"}` separately
from the live Settings schema. Writes preserve unrelated keys and refuse broken
JSON. `aerolith status` and `status --json` show the stored direction; shell IPC
status shows the running direction. Missing/invalid values fall back to PIYTI
in the shell, with a warning for invalid metadata. Uninstall keeps configuration
for a later reinstall by default; `aerolith uninstall --remove-config` also
removes this file, with the same modified-file protection as other owned files
(`--force` removes modified owned files).

## Claude Code + Codex sync

Claude Code and Codex coordinate their work in this repository through a shared
state file, `.ai_sync_hub.json`, and the helper in
[`tools/agent-sync`](tools/agent-sync/README.md). The rules each agent follows
are in [`AGENTS.md`](AGENTS.md) (Codex) and [`CLAUDE.md`](CLAUDE.md) (Claude Code).

```bash
python tools/agent-sync/agent_sync.py status   # show the current state
python tools/agent-sync/agent_sync.py watch    # run the watcher (needs watchdog)
```
