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

Unlisted outputs use `strip: true`, `ground: true`, `profile: "standard"`,
and `blackBackground: false`.
The global `strip.visible` and `ground.enabled` switches still apply.
A missing primary falls back to the deprecated `display.output`, the lowest
Hyprland monitor id, then the first Qt screen. Disconnected connector settings
are kept; a renamed connector uses defaults until its new name is configured.
`display.output` remains readable for one release. `warnOnMultipleDisplays`
is accepted and ignored. The `standard` profile preserves the theme; `oled`
uses true-black fills, adjusts the palette and decoration, and enables the
idle protection configured by `display.oled` below.

The reference below is generated from `shell/lib/config.mjs`, the single
source of truth, by `node tools/gen-config-doc.mjs` (CI checks it is current).

`display.oled` applies only to connectors with `profile: "oled"`. Set
`idleDimAfter` to the number of idle seconds (default 300, range 0–86400);
0 disables both dimming and idle decoration hiding. `idleDimLevel` sets the
shell surface opacity (default 0.65, range 0–1). `hideDecorationWhenIdle`
defaults to true; false retains decoration at its OLED intensity while idle.
The shared Wayland idle monitor respects idle inhibitors. Activity restores
the shell immediately; entering idle fades with the configured motion level.
These settings do not change monitor brightness or move pixels.

`display.outputs.<name>.blackBackground` selects a true-black background on
LCD or OLED outputs without enabling OLED idle protection. It preserves the
scheme's distinct surface planes; `profile: "oled"` continues to use the full
OLED palette and idle policy.

`theme.textSize` accepts 100, 112, 125 or 150 percent independently of
`theme.uiScale`. Type and its row/header containers grow; spacing and decorative
geometry retain their scale. Per-output text and density overrides are deferred
until mixed-scale validation (ASTRA.md decision 2).

`strip.showNetwork`, `showBluetooth`, `showMedia`, `showAudio`, `showBattery`
and `showNotifications` default to true. The existing `strip.telemetry` controls
readouts; sharing/mic privacy indicators, configuration warnings, critical
battery and critical temperature warnings remain available. Ground's
`showNowPlaying`, `showTelemetry` and `showAppRegister` also default to true.
Hiding the app register removes its measured tour anchor; Tour explains a
hidden target using its existing fallback.

`workspaces.names` maps positive numeric IDs to labels (64 entries maximum,
48 characters per label). Empty labels use the ID. Ring and strip show plain
text with elision and expose the full label through their accessible name;
workspace commands always retain numeric IDs. These new appearance keys carry
`preview: true` metadata and work through the existing preview transaction.
Consumers use `Config.data.workspaces.names`; the settings controls are added
separately by the settings UI owner.

<!-- BEGIN GENERATED: tools/gen-config-doc.mjs -->

### `display`

Multi-monitor placement. Ground and Strip run on every enabled output; global services remain singletons.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `display.primary` | string (≤ 64) | `""` | Primary output name. Empty or unavailable: deprecated output alias, then lowest Hyprland id, then first screen. Applies live. |
| `display.output` | string (≤ 64) | `""` | Deprecated alias for display.primary (one release). Used when primary is empty or unavailable. |
| `display.outputs` | map of objects | `{}` | Settings by output name: strip/ground default true, blackBackground default false, profile standard or oled (default standard). Disconnected or renamed entries are retained and ignored; new names use defaults. |
| `display.oled` | object | `{"idleDimAfter":300,"idleDimLevel":0.65,"hideDecorationWhenIdle":true}` | Protection for outputs whose profile is oled; standard outputs are unaffected. idleDimAfter is idle seconds (0 disables); idleDimLevel is surface opacity (0–1); hideDecorationWhenIdle hides static geometry. No display brightness changes or pixel shifting. |
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
| `theme.textSize` | `100` \| `112` \| `125` \| `150` | `100` | Text size in percent, independent of UI scale. Grows type and its rows/headers; never shrinks text to fit. |
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
| `strip.showNetwork` | bool | `true` | Show the network indicator. Privacy and critical warnings remain visible. |
| `strip.showBluetooth` | bool | `true` | Show the Bluetooth indicator. Privacy and critical warnings remain visible. |
| `strip.showMedia` | bool | `true` | Show the media indicator. Privacy and critical warnings remain visible. |
| `strip.showAudio` | bool | `true` | Show the audio indicator. Privacy and critical warnings remain visible. |
| `strip.showBattery` | bool | `true` | Show the battery indicator. Privacy and critical warnings remain visible. |
| `strip.showNotifications` | bool | `true` | Show the notifications indicator. Privacy and critical warnings remain visible. |
| `strip.telemetry` | `off` \| `alert` \| `always` | `"alert"` | CPU/memory/temperature readouts: off, above thresholds, or always. Critical temperature warnings always remain visible. |
| `strip.clock` | `24h` \| `12h` | `"24h"` | Clock format. |
| `strip.showDate` | bool | `true` | Show the date next to the clock. |
| `strip.showSeconds` | bool | `false` | Show seconds. Costs one redraw per second. |
| `strip.workspaceCount` | integer 1–20 | `5` | Minimum number of workspace cells shown on the workspace tape. |

### `ground`

The desktop background surface.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `ground.showNowPlaying` | bool | `true` | Show Now playing on Ground. |
| `ground.showTelemetry` | bool | `true` | Show telemetry readouts on Ground. |
| `ground.showAppRegister` | bool | `true` | Show the application register on Ground. |
| `ground.enabled` | bool | `true` | Draw AEROLITH's own desktop background behind all windows. Turn off to keep a wallpaper from another program such as hyprpaper or swaybg. |

### `workspaces`

Workspace labels shared by the ring and status strip.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `workspaces.names` | map of string | `{}` | Workspace ID to label: at most 64 entries, positive IDs 1–999999999, labels at most 48 characters. Ring and strip elide labels; dispatch always uses the ID. |

### `welcome`

Welcome startup preference.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `welcome.showOnStartup` | bool | `false` | Show Welcome on every shell start. Fresh installs show it once regardless; this does not enable shell autostart. |

### `tour`

First-run tour.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `tour.enabled` | bool | `true` | Show the first-run tour on the primary output. Completion is saved in shell state, separately from this config. |

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
