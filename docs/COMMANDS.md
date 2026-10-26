# Commands and routines

Everything AEROLITH can do is a command in one registry: the Command Core,
key bindings, IPC (`qs -p <shell> ipc call aerolith run <id> '<json args>'`),
routines and the optional AI proposals all go through it, with the same typed
parameter checks. Sensitive commands (suspend, reboot, power off, log out)
always need an explicit confirmation.

## Routines

A routine is a named list of command steps in
`~/.config/aerolith/routines.json`. It never contains code: each step names a
command marked "routine step" in the reference below and its
arguments. The file is reloaded when it is saved.

```json
{
  "schemaVersion": 1,
  "routines": [
    {
      "id": "focus-mode",
      "name": "Focus mode",
      "description": "Go to workspace 3, set volume to 30 %, show a notice.",
      "onError": "stop",
      "steps": [
        { "action": "workspace.focus", "args": { "workspace": 3 } },
        { "action": "audio.volume.set", "args": { "level": 30 } },
        { "action": "shell.notify", "args": { "message": "Focus mode engaged" } }
      ]
    }
  ]
}
```

A step with an unknown command or invalid arguments makes that routine
invalid; it is shown with its error in the Routine Console and never runs.

## Command reference

Generated from the running shell's registry by `tests/scenarios/catalogue.sh`
and `tools/gen-commands-doc.py` (CI checks it is current).

<!-- BEGIN GENERATED: tools/gen-commands-doc.py -->

61 commands with the AI module installed; without it the `ai` category is absent.

### shell

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `notifications.action`<br>Run notification action | — | `id`: integer ≥ 0<br>`action`: string | — |
| `notifications.clear`<br>Clear notifications | — | — | — |
| `notifications.dismiss`<br>Dismiss notification | — | `id`: integer ≥ 0 | — |
| `notifications.dnd.toggle`<br>Toggle do not disturb | `dnd` | — | — |
| `shell.delay`<br>Wait | — | `ms`: integer 0–30000 | routine step, AI may propose |
| `shell.history.clear`<br>Clear action history | — | — | — |
| `shell.notify`<br>Show a notice | — | `message`: string | routine step, AI may propose |
| `shell.open.help`<br>Open Help and shortcuts | `help` | — | — |
| `shell.open.navigator`<br>Open Spatial Navigator | `nav` | — | — |
| `shell.open.routines`<br>Open Routine Console | — | — | — |
| `shell.open.settings`<br>Open Settings | `set` | — | — |
| `shell.open.signal`<br>Open Signal Rack | `sig` | — | — |
| `shell.open.systems`<br>Open Systems Bay | `sys` | — | — |

### apps

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `app.launch`<br>Launch application | `run` | `app`: string | routine step, AI may propose |

### windows

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `window.close`<br>Close window — Ask the application to close (it may prompt to save) | — | `address`: string | — |
| `window.focus`<br>Focus window | — | `address`: string | — |
| `window.move`<br>Move window to workspace | — | `address`: string<br>`workspace`: integer 1–99<br>`follow`: bool (optional, default `false`) | — |
| `window.move-active`<br>Move active window to workspace | `mv` | `workspace`: integer 1–99 | routine step, AI may propose |

### workspaces

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `workspace.focus`<br>Go to workspace — Switch to a workspace by number | `ws` | `workspace`: integer 1–99 | routine step, AI may propose |
| `workspace.next`<br>Next workspace | — | — | routine step, AI may propose |
| `workspace.previous`<br>Previous workspace | — | — | routine step, AI may propose |

### audio

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `audio.input.mute.set`<br>Set microphone mute | — | `muted`: bool | routine step, AI may propose |
| `audio.input.mute.toggle`<br>Toggle microphone mute | `mic` | — | — |
| `audio.input.set`<br>Set audio input | `in` | `device`: one of the current choices | routine step, AI may propose |
| `audio.mute.set`<br>Set output mute | — | `muted`: bool | routine step, AI may propose |
| `audio.mute.toggle`<br>Toggle mute | `mute` | — | — |
| `audio.output.set`<br>Set audio output | `out` | `device`: one of the current choices | routine step, AI may propose |
| `audio.stream.route`<br>Route application audio | — | `stream`: integer ≥ 0<br>`device`: one of the current choices | — |
| `audio.stream.volume.set`<br>Set application volume | — | `stream`: integer ≥ 0<br>`level`: integer 0–150 | — |
| `audio.volume.down`<br>Volume down | — | — | routine step, AI may propose |
| `audio.volume.set`<br>Set volume — Set output volume in percent | `vol` | `level`: integer 0–150 | routine step, AI may propose |
| `audio.volume.up`<br>Volume up | — | — | routine step, AI may propose |

### media

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `media.next`<br>Next track | `next` | — | routine step, AI may propose |
| `media.pause`<br>Pause media | — | — | routine step, AI may propose |
| `media.play-pause`<br>Play / pause | `pp` | — | routine step, AI may propose |
| `media.player.select`<br>Select media player | — | `player`: one of the current choices | — |
| `media.previous`<br>Previous track | `prev` | — | routine step, AI may propose |

### routines

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `routine.open`<br>Preview routine | — | `routine`: string | — |
| `routine.revert`<br>Revert last routine | — | — | — |
| `routine.run`<br>Run routine | `rt` | `routine`: one of the current choices | — |

### system

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `brightness.down`<br>Brightness down | — | — | routine step, AI may propose |
| `brightness.set`<br>Set brightness | `bright` | `level`: integer 1–100 | routine step, AI may propose |
| `brightness.up`<br>Brightness up | — | — | routine step, AI may propose |
| `power.profile.set`<br>Set power profile | `power` | `profile`: one of `balanced`, `performance`, `power-saver` | routine step, AI may propose |
| `session.lock`<br>Lock session — AEROLITH's lock screen when lock.enabled is on; otherwise loginctl lock-session (needs a locker such as hyprlock via hypridle) | `lock` | — | routine step, AI may propose |
| `session.logout`<br>Log out (exit Hyprland) | — | — | asks for confirmation |
| `system.poweroff`<br>Power off | — | — | asks for confirmation |
| `system.reboot`<br>Reboot | — | — | asks for confirmation |
| `system.suspend`<br>Suspend | — | — | asks for confirmation |
| `telemetry.performance-mode`<br>Toggle telemetry performance mode — Halve all sampling rates | — | — | — |

### settings

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `settings.density`<br>Set interface density | `density` | `density`: one of `compact`, `standard`, `comfortable` | — |
| `settings.intensity`<br>Set interface intensity | `intensity` | `intensity`: one of `saturated`, `insane` | — |
| `settings.low-effects`<br>Toggle low-effects mode | — | — | — |
| `settings.motion`<br>Set motion level | `motion` | `motion`: one of `full`, `reduced`, `off` | — |
| `settings.scheme`<br>Set colour scheme | — | `scheme`: one of `limb`, `bathyal`, `corona`, `cinder`, `ferrite`, `iris`, `argent`, `lichen`, `helios`, `umbra`, `vellum`, `glacial` | — |
| `settings.strip.edge`<br>Move Flight Strip | `edge` | `edge`: one of `top`, `bottom` | — |
| `settings.strip.telemetry`<br>Set Flight Strip telemetry | `readouts` | `mode`: one of `off`, `alert`, `always` | — |
| `shell.reload-config`<br>Reload configuration | — | — | — |

### ai

| Command | Alias | Parameters | Notes |
|---|---|---|---|
| `ai.ask`<br>Ask AI — Send a request to the configured AI provider (explicit, visible) | `ai` | `prompt`: string | from `ai` module |
| `ai.cancel`<br>Cancel AI request | — | — | from `ai` module |
| `ai.open`<br>Open AI Bridge | — | — | from `ai` module |

<!-- END GENERATED -->
