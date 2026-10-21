# AEROLITH research record

This document records what was verified about the target stack before the
architecture was chosen, and how it was verified. Every statement is tagged:

- **[measured]**: observed directly in this project's development container or tooling.
- **[documented]**: stated by upstream documentation (source linked).
- **[estimate]**: reasoned expectation, not yet measured.
- **[open]**: unresolved; tracked in `docs/ROADMAP.md`.

Research date: 2026-10-21.

## 1. Target environment

| Component | Version found | How verified |
|---|---|---|
| Arch Linux `extra/quickshell` | 0.3.2-1, LGPL-3.0-only | [measured] `pacman -Si quickshell` in `archlinux:latest` |
| Arch Linux `extra/hyprland` | 0.56.2-4, BSD-3-Clause | [measured] `pacman -Si hyprland` |
| `extra/pipewire` / `extra/wireplumber` | 1.6.9 / 0.5.18 | [measured] |
| `extra/qt6-base` | 6.12.0 | [measured] `pacman -Q qt6-base` |
| `extra/openai-codex` | 0.163.0 | [measured] `pacman -Ss codex` |
| `extra/power-profiles-daemon`, `extra/upower` | 0.30, 1.91.5 | [measured] |
| Claude Code CLI | 2.1.306 (npm latest 2.1.307) | [measured] `claude --version`, `npm view` |
| Python (Arch) | 3.14 | [measured] |

CachyOS uses the Arch repositories plus its own optimised rebuilds, so these
versions are representative. [estimate] CachyOS ships the same Quickshell and
Hyprland versions within days of Arch.

### The development machine is not the target machine

The work for this repository was done in a cloud VM running Ubuntu 24.04 with
**no GPU and no DRM device** (`/dev/dri` absent, no kernel modules). An Arch
Linux container (`tools/devcontainer/Containerfile`) provides the real Arch
packages.

- [measured] Hyprland 0.56.2 **cannot start** in this environment:
  `CBackend::create() failed!` with both default and `AQ_BACKENDS=headless`.
  Hyprland's renderer requires a GBM/DRM device; there is no software path.
- [measured] Quickshell 0.3.2 **does run** under `sway` with
  `WLR_BACKENDS=headless WLR_RENDERER=pixman` and
  `QT_QUICK_BACKEND=software`. A `PanelWindow` was rendered as a real
  `zwlr_layer_shell_v1` surface and captured with `grim`.

Consequence: Quickshell rendering, layer-shell behaviour, QML loading,
PipeWire, MPRIS and D-Bus can be exercised for real in the container. Hyprland
IPC is exercised against a protocol mock (`tools/mock-hyprland/`) that
implements the documented socket protocol. **Nothing in this repository has
been verified on a real Hyprland session yet.** That verification is the first
item in `docs/ROADMAP.md`.

## 2. Hyprland 0.55+ switched configuration to Lua

[documented] <https://wiki.hypr.land/0.56.0/Configuring/Start/>:

- "Since Hyprland 0.55, hyprlang is deprecated in favor of lua."
- Main config: `$XDG_CONFIG_HOME/hypr/hyprland.lua`.
- Other files are included with `require("dir/file")`, relative to the config
  directory. A missing module makes `require` throw in the calling file, so
  optional includes must use `pcall(require, "...")`.

[documented] <https://hypr.land/news/26_lua/>: if `hyprland.lua` exists it is
loaded instead of `hyprland.conf`; hyprlang remains supported "for 1 - 2
releases starting from 0.55".

[measured] Hyprland 0.56.2 logged `Using lua config found at .../hyprland.lua`.

Syntax that AEROLITH needs (all [documented]):

| Purpose | Lua (0.55+) | hyprlang (≤0.54, still accepted) |
|---|---|---|
| Keybind to a global shortcut | `hl.bind("SUPER + SPACE", hl.dsp.global("aerolith:command"))` | `bind = SUPER, SPACE, global, aerolith:command` |
| Autostart | `hl.on("hyprland.start", function() hl.exec_cmd("...") end)` | `exec-once = ...` |
| Include file | `pcall(require, "aerolith/aerolith")` | `source = ~/.config/hypr/aerolith/aerolith.conf` |

### Dispatch over IPC is now Lua

[documented] <https://wiki.hypr.land/0.56.0/Configuring/Advanced-and-Cool/Using-hyprctl/>:
`hyprctl dispatch 'hl.dsp.focus({ workspace = "3" })'` is shorthand for
`eval 'hl.dispatch(...)'`. Dispatchers are Lua tables (`hl.dsp.focus`,
`hl.dsp.window.move`, `hl.dsp.window.close`, ...).

**Security consequence:** in Lua mode a dispatch string is evaluated as Lua. Any
value interpolated into it (window titles, workspace names, addresses) is a code
injection vector. AEROLITH builds dispatch strings only from validated values:
integer workspace ids, `0x`-hex addresses, and string literals escaped by a
dedicated Lua string encoder (`shell/lib/hyprdispatch.mjs`, unit tested).

### Quickshell supports both dialects

[documented] Quickshell changelog v0.3.0: "Added lua config support to Hyprland
module." [documented] `Hyprland.usingLua` (v0.3.2 docs): "True if Hyprland is
running in lua mode. Dispatcher syntax changes when using lua."
`HyprlandWorkspace.activate()` is documented as sending the legacy
`workspace <name>` form, so AEROLITH does not use it and dispatches through its
own dialect-aware builder.

### IPC sockets and events

[documented] <https://wiki.hypr.land/0.56.0/IPC/>: `.socket.sock` for requests
(`[flags]/command args`, connections must be short-lived because Hyprland
handles them synchronously); `.socket2.sock` streams `EVENT>>DATA\n` lines.
Events used by AEROLITH: `workspacev2`, `createworkspacev2`,
`destroyworkspacev2`, `openwindow`, `closewindow`, `movewindowv2`,
`activewindowv2`, `windowtitlev2`, `monitoraddedv2`, `monitorremovedv2`,
`screencast` (screen-share indicator), `urgent`, `configreloaded`.

## 3. Quickshell 0.3.2 capabilities

Source: <https://quickshell.org/docs/v0.3.2/types/> [documented], and the
installed `.qmltypes` files under `/usr/lib/qt6/qml/Quickshell/` [measured].

| Need | Quickshell type | Notes |
|---|---|---|
| Edge panel | `PanelWindow` + `WlrLayershell` | `layer`, `keyboardFocus` (`None`/`Exclusive`/`OnDemand`), `namespace` |
| Global keybinds | `GlobalShortcut` (Hyprland) | `hyprland_global_shortcuts_v1`; duplicate appid+name across processes crashes the later registrant |
| CLI control | `IpcHandler` | `qs ipc call <target> <fn>`; typed arguments |
| Workspaces/windows | `Hyprland.workspaces`, `.toplevels`, `.monitors`, `.dispatch()`, `.rawEvent` | `HyprlandToplevel.address`, `.workspace`, `.title`, `.lastIpcObject` |
| Window thumbnails | `ScreencopyView` with a `Toplevel` | Requires `hyprland-toplevel-export-v1`; optional in AEROLITH |
| Applications | `DesktopEntries.applications`, `DesktopEntry.execute()` | Tracks changes live since 0.2.1 |
| Audio | `Pipewire.nodes`, `.defaultAudioSink`, `.preferredDefaultAudioSink`, `PwNodeAudio.volume/muted` | Volume/mute require binding via `PwObjectTracker`; reconnects if PipeWire restarts (0.3.0) |
| Media | `Mpris.players`, `MprisPlayer.canPlay/canGoNext/...`, `position` | "Support ... varies wildly by player. Always check the associated canXyz" |
| Battery / power | `UPower.displayDevice`, `PowerProfiles.profile` | Needs `upower` / `power-profiles-daemon` installed |
| Files | `FileView` (`watchChanges`, `atomicWrites` default true) | Used for config and `/proc` reads |
| Processes | `Process` (argv list, never a shell), `StdioCollector`, `SplitParser` | Used for `nvidia-smi` streaming and `ps` |
| Clock | `SystemClock` (`precision`) | Minute precision avoids per-second redraws |

### QML JavaScript engine (V4) limits

[measured] by running a probe module under Qt 6.12's `qml` tool. Supported:
classes with methods/getters/static members, generators, `Map`/`Set`,
optional chaining, nullish coalescing, `Object.entries`, `padStart`,
`Promise`, sticky and unicode regex flags, labelled loops.

**Not supported** (syntax error or missing API): object spread `{...o}`, class
fields and private fields, `async`/`await`, BigInt, `Array.prototype.flat`,
`Array.prototype.at`, `Object.fromEntries`, `String.prototype.replaceAll`,
`matchAll`, `trimStart`, regex named groups and lookbehind,
`Promise.allSettled`, `structuredClone`, `Intl`.

AEROLITH's shared logic modules (`shell/lib/*.mjs`) are written to this subset
and their unit tests run in **both** Node.js and Qt's engine.

[measured] Arch's Qt sends `console.*` output to the journal unless
`QT_FORCE_STDERR_LOGGING=1` is set, which matters for test runners.

## 4. Audio and media

PipeWire and WirePlumber are reached through Quickshell's PipeWire module, which
speaks the native PipeWire protocol (not `pactl`/`wpctl` subprocesses). Default
device changes go through `Pipewire.preferredDefaultAudioSink`, which
[documented] "is a hint to pipewire" and may differ from the effective default.
AEROLITH shows both when they disagree.

MPRIS is consumed through `Mpris.players`. AEROLITH gates every control on the
player's `canXyz` property and shows unsupported controls as disabled.

## 5. Telemetry sources

| Metric | Source | Cost |
|---|---|---|
| CPU total / per core | `/proc/stat` deltas | One file read per sample |
| CPU frequency | `/proc/cpuinfo` `cpu MHz` or `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq` | Read only while the Systems Bay is open |
| Memory, swap | `/proc/meminfo` | One file read |
| Memory pressure | `/proc/pressure/memory` (PSI) | Absent on kernels without PSI; reported as unavailable |
| Network | `/proc/net/dev` deltas | One file read |
| Storage | `df -P -B1` via `Process` | Only while the Systems Bay is open, every 30 s |
| Temperatures | `/sys/class/hwmon/hwmon*/name` + `temp*_input` (`k10temp`, `coretemp`, `amdgpu`, `nvme`) | Discovered once, then direct reads |
| AMD GPU | `/sys/class/drm/card*/device/gpu_busy_percent`, `mem_info_vram_used/total` | [documented] amdgpu sysfs |
| Intel GPU | No unprivileged utilisation counter in sysfs; `intel_gpu_top` needs perf privileges | Reported as unavailable, frequency only (`gt_cur_freq_mhz`) |
| NVIDIA GPU | One long-running `nvidia-smi --query-gpu=... --format=csv,noheader,nounits -lms <ms>` stream | Started only while the Systems Bay is open; NVML direct access would need a native module |
| Top processes | `ps -eo pid=,times=,rss=,comm=` deltas | Only while the process list is visible |

Unavailable metrics are represented as `null` and displayed as `N/A`, never as 0.

## 6. AI provider CLIs

### Claude Code

[documented] <https://code.claude.com/docs/en/setup>: native install with
`curl -fsSL https://claude.ai/install.sh | bash` (launcher at
`~/.local/bin/claude`, versions under `~/.local/share/claude/`), or
`npm install -g @anthropic-ai/claude-code`. No official Arch package. User
configuration and credentials live under `~/.claude/` and `~/.claude.json`.
Requires a Pro, Max, Team, Enterprise or Console account, or a third-party API
provider. Free claude.ai plans do not include Claude Code.

[measured] `claude --help` (2.1.306) flags used by AEROLITH:
`-p/--print`, `--output-format json`, `--tools ""` ("disable all tools"),
`--no-session-persistence`, `--strict-mcp-config`, `--disable-slash-commands`,
`--system-prompt`, `--model`.

[measured] `claude auth status` works with **no network** (run inside an
empty network namespace) and prints JSON containing `loggedIn` and
`authMethod`, without secrets.

### Codex

[measured] `extra/openai-codex` 0.163.0 is in the official Arch repositories.
[measured] `codex exec --help` flags used by AEROLITH: `--sandbox read-only`,
`--ephemeral`, `--skip-git-repo-check`, `--ignore-user-config`,
`--output-schema <file>`, `-o/--output-last-message <file>`, `--color never`,
`-C <dir>`, prompt from stdin with `-`.

[measured] `codex --disable shell_tool --disable apps --disable plugins
--disable browser_use --disable computer_use --disable in_app_browser` turns
those features off; an **unknown** feature name is a hard error
(`Unknown feature flag`). AEROLITH fails closed in that case rather than run
Codex without its lock-down flags.

[measured] `codex login status` works offline and reports through its exit
code (non-zero when not logged in). Credentials live in `~/.codex/`;
AEROLITH never reads that directory.

ChatGPT subscriptions, OpenAI API keys and Codex CLI access are separate
entitlements. AEROLITH does not assume one implies another.

## 7. Packaging

- Arch: a `PKGBUILD` with split packages `aerolith` (core) and
  `aerolith-ai-bridge` (optional) is the natural fit. The per-user steps
  (configuration, AI choice, Hyprland integration) cannot live in a package
  because packages must not touch `$HOME`. They are handled by the `aerolith`
  CLI.
- Runtime dependencies of the core: `quickshell`, `qt6-svg`, `hyprland`,
  `procps-ng`, `python` (CLI only, not the running shell). Optional:
  `upower`, `power-profiles-daemon`, `nvidia-utils`.

## 8. Options evaluated

See `docs/DECISIONS.md` ADR-001 for the decision. Summary of evidence:

| Option | Wayland/Hyprland access | Audio/MPRIS | Iteration speed | Idle cost | Risk |
|---|---|---|---|---|---|
| A. Quickshell + QML | All needed protocols already implemented and maintained upstream | Native PipeWire and MPRIS modules | Live reload | [estimate] near zero CPU when nothing animates; Qt Quick RSS typically tens of MB | Tied to Quickshell's release cadence |
| B. Native C++ (Qt + LayerShellQt or GTK4 + gtk4-layer-shell) | Must implement Hyprland IPC, toplevel export, global shortcuts | Must bind libpipewire, implement MPRIS over D-Bus | Rebuild per change | Similar to A for Qt; GTK4 comparable | Months of integration work before any feature |
| C. Native daemon + separate UI | Adds an IPC protocol between two processes | Same as B for the daemon | Mixed | Two resident processes | More moving parts for no capability gain |
| D. Rust (iced/gtk4-rs + layer shell) | Same gaps as B | pipewire-rs, zbus | Slower compile loop | Low | Same months of integration work |

[open] Resident memory and idle CPU of the finished shell on real hardware.
See `docs/PERFORMANCE.md`.
