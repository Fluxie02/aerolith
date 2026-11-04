# Configuration

AEROLITH reads `~/.config/aerolith/config.json` (`$XDG_CONFIG_HOME/aerolith/`).
Every key is optional; a missing key takes its default. Invalid values are
reported in the Flight Strip (`CFG`) and replaced by their default, never
silently accepted. Settings changed in the Settings bay are written back to
this file, and edits made to the file apply as soon as it is saved.

`~/.config/aerolith/installation.json` is separate: it holds the
installation-only choice of application direction (THEARS or PIYTI), which is
set by `aerolith install --direction` and has no Settings control.

For multiple outputs, `display.primary` chooses the primary screen and
`display.outputs` maps connector names to optional settings objects. For example:

```json
{
  "display": {
    "primary": "DP-1",
    "outputs": {
      "DP-1": { "strip": true, "ground": true, "profile": "oled" },
      "HDMI-A-1": { "strip": true, "ground": false }
    },
    "overlayOn": "focused",
    "noticesOn": "primary"
  }
}
```

Unlisted outputs use `strip: true`, `ground: true`, `profile: "standard"`.
The global `strip.visible` and `ground.enabled` switches still apply.
A missing primary falls back to the deprecated `display.output`, the lowest
Hyprland monitor id, then the first Qt screen. Disconnected connector settings
are kept; a renamed connector uses defaults until its new name is configured.
`display.output` remains readable for one release. `warnOnMultipleDisplays`
is accepted and ignored. Profile selection is metadata for the separate OLED
profile work; profile metadata alone does not change colours or add OLED protection.

The reference below is generated from `shell/lib/config.mjs`, the single
source of truth, by `node tools/gen-config-doc.mjs` (CI checks it is current).

<!-- BEGIN GENERATED: tools/gen-config-doc.mjs -->

### `display`

Multi-monitor placement. Ground and Strip run on every enabled output; global services remain singletons.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `display.primary` | string (≤ 64) | `""` | Primary output name. Empty or unavailable: deprecated output alias, then lowest Hyprland id, then first screen. Applies live. |
| `display.output` | string (≤ 64) | `""` | Deprecated alias for display.primary (one release). Used when primary is empty or unavailable. |
| `display.outputs` | object of colours | `{}` | Settings by output name: strip/ground default true, profile standard or oled (default standard). Disconnected or renamed entries are retained and ignored; new names use defaults. |
| `display.overlayOn` | `focused` \| `primary` | `"focused"` | Output for Deck, OSD and session menu. Missing focus falls back to primary. |
| `display.noticesOn` | string (≤ 64) | `"primary"` | Output for notices: primary, focused, or an output name. Missing names fall back to primary. |
| `display.warnOnMultipleDisplays` | bool | `true` | Retired; accepted for compatibility and ignored. All enabled outputs get surfaces. |

### `theme`

AEROLITH Instrument System appearance.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `theme.scheme` | `limb` \| `bathyal` \| `corona` \| `cinder` \| `ferrite` \| `iris` \| `argent` \| `lichen` \| `helios` \| `umbra` \| `vellum` \| `glacial` | `"limb"` | Colour spectrum. Choose in Settings; applies live. Palette overrides take precedence. |
| `theme.density` | `compact` \| `standard` \| `comfortable` | `"standard"` | Spacing and type scale. |
| `theme.uiScale` | number 0.75–2 | `1` | Multiplier applied on top of the compositor's own scaling. |
| `theme.motion` | `full` \| `reduced` \| `off` | `"full"` | Animation level. 'off' disables all transitions. |
| `theme.intensity` | `saturated` \| `insane` | `"saturated"` | How much the interface shows: 'saturated' or the even denser 'insane'. Switch with `aerolith intensity`. |
| `theme.lowEffects` | bool | `false` | Opaque backdrops and no shadows, for slow GPUs or screen recording. |
| `theme.fontSans` | string (≤ 128) | `"Inter"` | Interface font family. |
| `theme.fontMono` | string (≤ 128) | `"JetBrains Mono"` | Monospaced font for commands and telemetry. |
| `theme.palette` | object of colours | `{}` | Colour overrides. Keys: obsidian, surface, surface2, grid, text, textDim, signal, caution, critical, nominal. |

### `strip`

The edge-mounted status strip.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `strip.visible` | bool | `true` | Show the Flight Strip. |
| `strip.edge` | `top` \| `bottom` | `"top"` | Screen edge for the Flight Strip. |
| `strip.showWindowTitle` | bool | `true` | Show the focused window title. |
| `strip.telemetry` | `off` \| `alert` \| `always` | `"alert"` | CPU/memory readouts: never, only when above thresholds, or always. |
| `strip.clock` | `24h` \| `12h` | `"24h"` | Clock format. |
| `strip.showDate` | bool | `true` | Show the date next to the clock. |
| `strip.showSeconds` | bool | `false` | Show seconds. Costs one redraw per second. |
| `strip.workspaceCount` | integer 1–20 | `5` | Minimum number of workspace cells shown on the workspace tape. |

### `ground`

The desktop background surface.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `ground.enabled` | bool | `true` | Draw AEROLITH's own desktop background behind all windows. Turn off to keep a wallpaper from another program such as hyprpaper or swaybg. |

### `commandCore`

The universal command palette.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `commandCore.maxResults` | integer 5–200 | `40` | Maximum results listed. |
| `commandCore.historySize` | integer 0–1000 | `100` | Executed actions kept in history. |
| `commandCore.terminal` | list of strings | `[]` | Terminal command used for Terminal=true applications, e.g. ["foot"] or ["kitty", "-e"]. Empty: detect. |
| `commandCore.launchPrefix` | list of strings | `[]` | Command prefix for launching apps, e.g. ["uwsm", "app", "--"]. |

### `telemetry`

Systems Bay sampling. Nothing is sampled while no view needs the data.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `telemetry.stripIntervalMs` | integer 1000–60000 | `5000` | Sampling interval while only the Flight Strip needs data. |
| `telemetry.panelIntervalMs` | integer 500–60000 | `2000` | Sampling interval while the Systems Bay is open. |
| `telemetry.detailIntervalMs` | integer 250–60000 | `1000` | Sampling interval for the detailed process view. |
| `telemetry.historySamples` | integer 10–3600 | `120` | Samples kept for graphs (bounded memory). |
| `telemetry.gpu` | `auto` \| `amd` \| `intel` \| `nvidia` \| `off` | `"auto"` | GPU telemetry source. |
| `telemetry.performanceMode` | bool | `false` | Halve sampling rates everywhere (useful while gaming). |
| `telemetry.cpuCautionPercent` | integer 1–100 | `85` | CPU percentage that raises a caution. |
| `telemetry.memoryCautionPercent` | integer 1–100 | `90` | Memory percentage that raises a caution. |
| `telemetry.temperatureCautionC` | integer 30–120 | `85` | Temperature that raises a caution. |
| `telemetry.temperatureCriticalC` | integer 30–130 | `95` | Temperature that raises a critical alert. |

### `audio`

Signal Rack audio behaviour.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `audio.volumeStep` | integer 1–25 | `5` | Volume change per step, in percent. |
| `audio.maxVolume` | integer 100–150 | `100` | Upper volume limit in percent. Above 100 amplifies. |
| `audio.showStreams` | bool | `true` | List per-application streams in the Signal Rack. |

### `lock`

Session lock.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `lock.enabled` | bool | `false` | Lock with AEROLITH's own lock screen (Wayland session lock and PAM). Off: the lock command asks logind, for a locker such as hyprlock. |

### `navigator`

Spatial Navigator overview.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `navigator.thumbnails` | bool | `false` | Live window thumbnails (uses hyprland-toplevel-export; costs GPU memory). |
| `navigator.showEmptyWorkspaces` | bool | `true` | Show empty workspaces up to strip.workspaceCount. |

### `routines`

Routine engine safety settings. Routines themselves live in routines.json.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `routines.allowCommandSteps` | bool | `false` | Allow routines to run programs with 'shell.exec' steps (argument list, no shell). Each run still asks for confirmation. |

### `notifications`

Optional built-in notification server.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `notifications.server` | bool | `false` | Act as the desktop notification server. Leave off if mako, dunst or swaync is running. |
| `notifications.doNotDisturb` | bool | `false` | Suppress notification popups (they are still counted). |
| `notifications.popupTimeoutMs` | integer 1000–60000 | `6000` | How long popups stay visible. |

### `logging`

Diagnostics.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `logging.level` | `debug` \| `info` \| `warn` \| `error` | `"info"` | Minimum level written to the Quickshell log. |

<!-- END GENERATED -->
