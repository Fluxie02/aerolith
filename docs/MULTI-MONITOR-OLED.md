# Multi-monitor and OLED profile: architecture and work record

Owner assignment of 4 November 2026: dual-monitor support and an optional,
per-monitor OLED profile, without redesigning AEROLITH. This file is the
shared record for Opus, Sol, Terra and Astra: decisions, assignments, status
and test results. Keep entries short; update the Status section on every
merge.

## Audit (Opus, on claude/redesign-2 @ 09f4a01)

- Six window types: Ground (desktop), FlightStrip (top bar), Deck (overlay),
  NoticeColumn, OsdHost, SessionHost; LockHost already covers every output.
- All of them use `Ui.screen`: one output picked by `display.output`, else
  Hyprland's lowest monitor id (`core/Ui.qml`), with a caution annunciator
  when more are connected. 31 call sites, 13 files.
- Global services (Compositor, Audio, Media, Telemetry, Notifications, Apps,
  Registry ...) are singletons: right for multi-monitor, keep them single.
- `ShellState` (fullscreen lifecycle) and `Theme.desktopCovered` (ambient
  hold) evaluate one output only. `lib/shellstate.mjs::outputFullscreen`
  already takes an output name.
- Theme is one global singleton read by 48 files; a palette is resolved once
  (`lib/tokens.mjs`).
- The mock Hyprland already has `add_monitor` / `remove_monitor`; the headless
  sway has one output.

## Decisions (Opus)

1. **Displays service.** New singleton `services/Displays.qml` with pure
   logic in `lib/displays.mjs` (unit tested): the list of outputs (Quickshell
   screens joined with Hyprland monitors: name, id, scale, refresh, focused),
   the primary output, the focused output, and per-output settings. Event
   driven from Quickshell's screen list and Hyprland monitor events; no
   polling.
2. **Configuration** (`display` in config.mjs; schema regenerated):
   - `primary`: output name or `""` (auto: the existing rule, lowest Hyprland
     id). `display.output` stays readable as a deprecated alias for one
     release, so existing configs keep working.
   - `outputs`: map of output name to `{ strip, ground, profile }` with
     `strip`/`ground` booleans (default: true on every output) and `profile`
     `"standard" | "oled"` (default `"standard"`).
   - `overlayOn`: `"focused" | "primary"` (default `"focused"`): where the
     Deck (command overlay), OSD and session menu open.
   - `noticesOn`: `"primary" | "focused" | <output name>` (default
     `"primary"`).
   - `warnOnMultipleDisplays` is retired with the single-display policy.
3. **Per-monitor surfaces.** Ground and FlightStrip become one instance per
   enabled output (`Variants`), each bound to its own screen. Deck, OSD,
   session menu and notices stay single instances that move to the output
   chosen by `overlayOn` / `noticesOn`. Global services are never duplicated.
   `Ui.screen` keeps meaning "the primary output"; new `Ui.overlayScreen` and
   `Ui.noticeScreen` carry the placement; nothing else re-resolves outputs.
4. **Fullscreen per output.** `ShellState` keeps one lifecycle per output.
   A fullscreen window releases that output's Ground and Strip only; the
   other output keeps its shell. Ambient hold (`desktopCovered`, fullscreen)
   is evaluated per output as well.
5. **Display profiles (OLED).** A small non-singleton `core/DisplayProfile.qml`
   created inside each per-output surface (`profile.output` = its screen),
   resolving that output's profile into the few tokens that differ:
   window/background fill, surface fills, grid and separator opacity,
   decoration opacity, and idle dim level. Components on per-output surfaces
   read `profile.*` for those tokens and `Theme.*` for everything else, so a
   mixed OLED/LCD setup never forces OLED values onto the LCD. Single-instance
   surfaces (Deck, OSD, notices) use the profile of the output they are on.
   Token derivation lives in `lib/tokens.mjs` (`oledPalette`) with the
   existing contrast checks; Astra reviews the values once with screenshots.
6. **OLED protection** (only what AEROLITH controls; no burn-in claims):
   - optional idle dimming of shell surfaces on OLED outputs, via Wayland
     idle notification (Quickshell `IdleMonitor`), event driven;
   - optional hiding of static decoration when idle;
   - darker idle states for stationary instrumentation;
   - no pixel shifting, no new continuous animation, no polling.
7. **Performance rules.** No per-monitor copies of services or timers; a
   surface on a disabled or fullscreen output is destroyed, not hidden; idle
   dimming changes one opacity per surface; measure idle CPU and wakeups
   before and after with `tests/scenarios/perf.sh` in the harness.

## Assignments

| Who | Task | Files (locked by Opus) |
|---|---|---|
| Sol | MM-1: Displays service, config, per-output Ground/Strip, overlay and notice placement, per-output fullscreen and ambient hold, harness second output, scenarios | `services/Displays.qml` (new), `lib/displays.mjs` (new), `core/Ui.qml`, `shell.qml`, `services/ShellState.qml`, `lib/shellstate.mjs`, `lib/config.mjs`, `modules/{ground,strip,deck,notices,osd,session}/*Host/Surface/Strip/Column/Deck.qml`, `core/Theme.qml` (ambient hold only), `tools/headless/*`, `tools/mock-hyprland/*`, tests |
| Terra | OLED-1 (in parallel, disjoint files): `oledPalette` and contrast tests in `lib/tokens.mjs`, `core/DisplayProfile.qml`, idle service `services/Idle.qml` (IdleMonitor) | those files and their tests |
| Terra | OLED-2 (after MM-1 merges): wire `profile` into per-output surfaces, OLED config options, idle dimming and decoration hiding, scenarios and measurements | per-output surface components |
| Astra | One review: OLED values and dual-monitor layout from screenshots; compact decisions for Terra | none |
| Opus | Review and merge each job, run the harness, measure, final review | — |

## Status

- [x] MM-1 (Sol): Displays service, display.primary/outputs/overlayOn/noticesOn (display.output kept as alias), per-output Ground/Strip, overlay/notice placement, per-output fullscreen lifecycles, OUTPUTS=2 harness, multimonitor scenario in CI. Opus verified: JS 197, pytest 302, headless multimonitor, smoke, fullscreen, deck, scratch, notify pass. Single-output idle CPU 0.92% -> 0.87%.
- [x] MM-1b (Sol): ambient per output (and coverage detection fixed: it had stopped seeing covered desktops after MM-1), telemetry demand across outputs, popup expiry on the notice output, Deck notice takeover only on the notice output, config-doc map label, hot-unplug warnings 2 -> 0. Opus verified: JS 203, pytest 303, headless multimonitor, fullscreen, deck, app-links, perf pass. perf.sh idle with the desktop covered by a tiled window: 0.1% of one core, 1.6 context switches/s (Sol measured 2.80% / 39.6 before the coverage fix).
- [x] OLED-1 (Terra): oledPalette (min contrast 4.99:1, 12 schemes), DisplayProfile, Idle (IdleMonitor, off by default). Suite tests/js/tokens.test.mjs registered after MM-1 merges.
- [x] OLED-2 (Terra): per-output DisplayProfile wired into Ground, Strip, notices, OSD, session and Deck frame; display.oled (idleDimAfter 300 s, idleDimLevel, hideDecorationWhenIdle); OLED-only idle dimming; status fields; oled.sh in CI. Standard outputs pixel-identical; idle unchanged (0.11% CPU, 1.7 cs/s). Opus verified: JS 205, pytest 303, headless oled, multimonitor, smoke, deck pass. Gap: Deck bay interiors (command, navigator, systems, ...) still use Theme tokens on an OLED output.
- [x] OLED-3 (Terra): Astra's decisions 1, 2 and 4; decision 3 for every core bay. Opus verified: JS 207, pytest 303; headless oled, multimonitor, smoke, deck, fullscreen, app-links, scratch pass; idle 0.11% CPU, 1.6 cs/s. Open: the optional AI console (ai-bridge/qml/AiModule.qml) still reads Theme on an OLED output.
- [x] OLED-4 (Sol): the optional AI console (ai-bridge/qml/AiModule.qml) takes the output's profile (the Deck already hands its profile to any bay that has one); oled.sh in CI now runs with the AI module installed (AI=1) and checks the real console on both outputs. Opus verified: JS 207, pytest 306; headless oled (AI=1 and AI=0) and ai pass.
- [x] Astra review: docs/design/oled/ASTRA-DECISIONS.md (palette kept, cyan x0.80; idle hides static content, clock stays; Deck bays take the output's profile; app bar on the primary output only)
- [x] Final review (Opus), measurements, PR

## Needs real hardware

Mixed refresh rates and scales, 240 Hz QD-OLED behaviour, sleep/wake and
display power cycles, NVIDIA multi-output fullscreen: verified only on the
owner's PC (the harness has software outputs and a mock Hyprland).
