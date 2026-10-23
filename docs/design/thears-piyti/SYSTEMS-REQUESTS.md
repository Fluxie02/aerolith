# UI-012 · systems handoff for owner approval

These requests describe future behavior. UI-012 adds visual code and uninstalled
app files; it does not implement process automation, new config/schema keys,
installer writes or host lifecycle policy. Claude implements the approved work.

## S1 · full-screen/game resource release — required before PIYTI ships

**Invariant:** while a game or full-screen app owns the selected output, AEROLITH
releases its rendered surfaces and GPU allocations to near zero. A transparent,
covered, hidden or paused texture is not proof of release. No offscreen app art,
window thumbnails, live previews, shaders, continuous capture or retained app
webviews are required by either direction.

Existing GroundSurface.qml:15 and FlightStrip.qml:17 only check configuration
and output availability; they do not suppress themselves for full-screen state.
This is an inherited systems gap, reviewed in [CLAUDE-REVIEW.md](CLAUDE-REVIEW.md).
Do not treat UI-012's CPU measurement as GPU-memory evidence.

**Input:** event-driven selected-output full-screen ownership and game lifecycle
(from Hyprland full-screen client state; optional Steam launch tracking).
**Contract:** one lifecycle owner unloads Ground, strip, Deck and notice visual
contents and releases the associated scene graphs/render resources. Stop pending
visual animations before teardown. Preserve configuration, pending notices,
privacy state, command/IPC registration and service semantics outside those
contents. Do not poll `/proc`, processes or window state from QML.
**Restoration:** after full-screen exits, reconstruct once from retained plain
state, repaint canvases once, no startup assembly replay, no stale Deck focus or
keys, no hidden audio/telemetry demand. Define explicitly whether an intentional
shell summon exits suspension temporarily and whether sharing privacy needs a
compositor-owned indicator; do not silently keep a rendered strip alive.
**Acceptance:** real Hyprland/GPU test with before/during/after per-process VRAM
and aggregate compositor allocation, accounting for driver noise, target <= 1 MiB
incremental shell GPU allocation during suspension. Repeat 20 cycles, both
intensities/directions, open bay + notification + active sharing; verify IPC and
input on return and no allocation growth. If the renderer cannot release with
Loader teardown, suspend/restart rendering out of process while retaining state.

## S2 · select THEARS or PIYTI

**Input:** a validated `theme.applicationDirection` enum `thears|piyti`, default
`thears`, in config/schema + Settings selection + CLI if consistent with current
settings. Migration preserves existing palette, intensity, motion and effects.
**Output:** bind existing visual seam `Theme.applicationDirection` to that setting.
It is a local QML property in this round, intentionally not a new user setting.
Review captures of PIYTI use a disposable shell copy with only its default value
changed. Both directions work in Saturated and Insane; direction is orthogonal
to intensity. No runtime shell write to app configurations on mode changes.
**Acceptance:** live THEARS↔PIYTI across open/closed Deck; keys, AI component API,
plain untrusted text, lowEffects and motion modes retain behavior. Persist once
through normal config transaction; invalid enum gives existing validation UI.

## S3 · explicit application routes, never inferred task authority

UI-012's bus uses existing `Compositor.windows()/activeClass`, opening Navigator
for linked app windows and Command search otherwise. Counts mean **windows**,
not tabs, documents, downloads, games, calls, projects or unsaved edits.

**Future input:** normalized event-driven app identity/address/workspace/title/
full-screen state from Hyprland. Mapping must handle Firefox ESR/Flatpak, LO
Writer/Calc/Impress/Draw, Steam main UI vs games, Discord/Vesktop and Crafting Apps
individually. Expose plain data with stable IDs; no title-based shell commands.
**Output:** optional read-only current-app context in PIYTI and a verified address
route through existing window.focus, with normal error feedback if it vanishes.
Users can always open full Navigator or Command. The current visual implementation
routes to these existing bays and does not guess which window to focus.
**Acceptance:** missing compositor, unknown app, duplicate windows, app closing
between paint and action, forged markup in titles and no app installed all remain
usable; zero extra periodic work at idle.

## S4 · optional media and game integration

Use existing MPRIS player selection for Firefox/Discord if that app actually
exports it; Discord calls are not MPRIS. No fake transport, call/mic status,
presence, download or game-progress indicators. Match bus identity explicitly to
player identity before attributing media. Demand follows Signal bay lifetime.
Steam launch action needs owner-approved command registration, a validated numeric
AppID and allowlisted invocation; distinguish launching from actually running.
Millennium and Vencord remain appearance mods; themes do not execute shell code
or grant remote content command access. No account login or token collection.

## S5 · app installer, opt-in and reversible

After owner approval, discover per-app paths/toolkit/sandbox and deployed versions,
merge imports/theme selection without replacing existing user data, back up and
record every changed file. Firefox needs the stylesheet preference and a restart;
LibreOffice xcu is a registry fragment to merge, not a replacement profile;
Millennium and Vencord must already be installed with owner consent. Offer each
app and direction separately; preserve high-contrast/accessibility overrides.
Do not claim PhotoCraft release builds support the debug token loader. See the
per-app sections of themes/README.md for exact destinations and format sources.
