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

Application themes are a separate opt-in. The interactive installer starts
with nothing selected; non-interactive installs and `--yes` apply none unless
you pass `--themes kitty,foot,hyprland`. `--no-themes` skips the prompt and
keeps previously deployed themes. No third-party modification system is installed.

```bash
aerolith themes list
aerolith themes apply kitty foot hyprland --scheme bathyal --dry-run
aerolith themes apply kitty foot hyprland
aerolith themes status --json
aerolith themes remove kitty foot hyprland
```

Exports use the installed direction and `config.json`'s `theme.scheme`
(default `limb`); `--scheme` affects only this deployment. Changes to shell
Settings do not refresh external apps yet (C06). Includes are backed up and
tracked separately in the ownership manifest. Removing themes, or a full
uninstall, removes their blocks while retaining other user edits and modified
theme files. btop and Qt exports need manual selection in the application.
See [per-app mechanisms and limits](themes/README.md#installer-deployment-c05).

## Claude Code + Codex sync

Claude Code and Codex coordinate their work in this repository through a shared
state file, `.ai_sync_hub.json`, and the helper in
[`tools/agent-sync`](tools/agent-sync/README.md). The rules each agent follows
are in [`AGENTS.md`](AGENTS.md) (Codex) and [`CLAUDE.md`](CLAUDE.md) (Claude Code).

```bash
python tools/agent-sync/agent_sync.py status   # show the current state
python tools/agent-sync/agent_sync.py watch    # run the watcher (needs watchdog)
```
