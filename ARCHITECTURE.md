# AEROLITH architecture

AEROLITH is a keyboard-first desktop shell for Hyprland, written in QML on
Quickshell (0.3.0 or newer; developed against 0.3.2 with Qt 6.12). This file
maps the code, says who owns what, and lists the **contracts the visual layer
must keep** while Astra redesigns it. Design direction lives in
[`DESIGN_BRIEF.md`](DESIGN_BRIEF.md); verified facts about the stack live in
[`docs/RESEARCH.md`](docs/RESEARCH.md).

Nothing here is a design decision. Where a contract blocks a design idea,
ask Claude to change the systems side (see "Systems requests" below) rather
than working around it.

## Repository map

| Path | What it is | Owner |
|---|---|---|
| `shell/shell.qml` | Composition root: starts every service, creates the surfaces | Claude (coordinate edits) |
| `shell/core/Theme.qml`, `shell/lib/tokens.mjs` | Design tokens and their resolution from config | Astra |
| `shell/components/*.qml` | Shared visual components (Bezel, Label, StatusLine, gauges, ...) | Astra |
| `shell/modules/**/*.qml` | The surfaces and bays: presentation mixed with key handling and service calls | Astra for presentation, contracts below |
| `shell/modules/ControlSurface.qml`, `shell/modules/AiLoader.qml` | IPC handler, global shortcuts, AI module loader | Claude |
| `shell/core/{Ui,Config,Exec,Log,Paths,Registry,Store,Wait}.qml` | UI state machine, config, processes, logging, command registry, persistence | Claude |
| `shell/services/*.qml` | Compositor (Hyprland IPC), Audio (PipeWire), Media (MPRIS), Notifications, Power, Telemetry, Routines, Apps, shell commands | Claude |
| `shell/lib/*.mjs` (except `tokens.mjs`) | Pure logic shared with the tests: fuzzy search, registry, config schema, routines, telemetry maths, Hyprland dispatch | Claude |
| `shell/schema/config.schema.json` | Generated from `shell/lib/config.mjs` by `node tools/gen-schema.mjs` | generated |
| `ai-bridge/` | Optional AI module, shipped as a separate package. `qml/AiModule.qml`: lines up to the `AiConsole` inline component are systems; `AiConsole` is presentation | split, see contract 15 |
| `installer/`, `install.sh` | Installer, maintenance CLI and uninstaller with an ownership manifest | Claude |
| `tests/`, `tools/headless/`, `tools/mock-hyprland/`, `tools/devcontainer/` | Unit tests, headless scenarios, Hyprland IPC mock, dev image | Claude |
| `tools/agent-sync/`, `.ai_sync_hub.json` | Coordination between Claude and Astra | shared |

Ui.qml is a state machine, not theming: it holds the open bay, the pending
query, the chosen screen and the notice queue. The visual layer reads it.

## Surfaces

The shell has four windows, all `PanelWindow`s on wlr-layer-shell. Each
surface is a systems host (Claude) that draws a visual view (Astra):

| Surface | Host / view | Layer, namespace | Focus | Lifecycle |
|---|---|---|---|---|
| Ground | `modules/ground/GroundSurface.qml` / `Ground.qml` | Background, `aerolith-ground` | never | mapped while `ground.enabled` (default on); behind every window, reserves nothing. `ground.enabled: false` leaves the background to another program |
| Strip | `modules/strip/FlightStrip.qml` | Top, `aerolith-strip` | never | always mapped while `strip.visible`; reserves `exclusiveZone = Theme.stripHeight` on `strip.edge` (top or bottom) |
| Deck | `modules/deck/Deck.qml` / `DeckView.qml` | Overlay, `aerolith-deck` | Exclusive while a bay is requested | mapped while a bay is open, plus at most `deck.exitMs` for an outgoing bay's exit (see contract 6) |
| Notices | `modules/notices/NoticeColumn.qml` / `NoticeStack.qml` | Overlay, `aerolith-notices` | never | mapped while there is a notice or popup and the Deck is not mapped (the Deck shows the stack then) |

There is no lock screen (`Power` calls `loginctl lock-session` for an
external locker), and no brightness, network, Bluetooth or
display-configuration service. Each of these needs Claude first; see
"Systems requests".

Keep the namespaces: users' Hyprland `layerrule`s can target them.

## Contracts the visual layer must keep

1. **Bay ids and IPC.** Bays are `command`, `navigator`, `systems`,
   `signal`, `routines`, `help`, `ai` (`Ui.qml`). They are used by
   `qs ipc call aerolith open|toggle|close <bay>`, by the global shortcuts
   the installer writes, and by every test scenario. Labels on screen are
   free; ids are not. The Deck rail order doubles as the Ctrl+1..6 key map
   (command, navigator, systems, signal, routines, ai).
2. **Keyboard.** While open, the Deck holds exclusive keyboard focus and each
   bay is a `FocusScope` that gets `forceActiveFocus()` on load. Deck-level
   keys run after the bay (`Keys.priority: Keys.AfterItem`): Esc closes, F1
   toggles help, Ctrl+1..6 switch bays. The strip and notices never take
   focus. The text input must accept keys from the first frame.
3. **Bay key handlers are product behaviour.** The scenarios type and press
   real keys: Command Core (`vol 40` + Return), Routine Console (Return runs
   the first routine), AI console (Tab toggles review, A approves the
   selected proposal, D dismisses), Navigator (arrows follow the visual
   layout; M then 1-9 moves a window; X X closes; Delete), Systems (C, M sort,
   P performance mode), Signal Rack (↑↓/jk, ←→/hl, Enter/Space, M, comma,
   period). A new layout must keep the arrow keys coherent with what is drawn.
   `HelpBay` key groups must match the real handlers.
4. **Timing.** Scenarios take screenshots, type and press keys 0.3 to 1.5 s
   after `ipc open`. Open transitions must stay well under that, and no
   action may wait for an animation to finish.
5. **Motion.** Every duration comes from Theme motion tokens and every
   `Behavior`/`Transition` is gated by `enabled: Theme.animate`.
   `theme.motion` is a user setting: `full`, `reduced` (feedback without
   travel) and `off` (the schema promises that `off` disables **all**
   transitions; `HelpBay` jumps instead of flicking then). No looping or
   ambient animation may run while the shell is idle: one infinite
   `NumberAnimation` on an 8 px item measured 4.25 % of a core and
   188 context switches/s, against 0 % for a static strip.
6. **Lifecycles.** The Deck keeps two bay slots (`deck.slotA`, `deck.slotB`,
   Loaders parented into `DeckView.frameA`/`frameB`). A slot is `current`
   while its bay is requested and `leaving` for at most `deck.exitMs`
   (`Theme.normal`, or 0 with motion off or `lowEffects`) after the bay was
   closed or replaced; `deck.exiting` is true while a closed Deck shows its
   exit. Animate enter, exit and cross-bay motion from these properties.
   The moment a bay stops being requested, its `active` property goes false
   (bays release demand on it), it loses focus, and a closed Deck passes
   pointer input through and drops keyboard focus; a third change during an
   exit cuts the oldest exit short. Bays are created fresh on every open.
   Notices and popups are keyed models (`Ui.notices` records keyed by `id`,
   `Notifications.popups` are the notification objects), so a card lives as
   long as its record. Expiry belongs to the services and is fixed when a
   record arrives; cards have no timers. Clicking a popup calls
   `Notifications.activate(n)` (its "default" action, else hide);
   clicking a notice calls `Ui.dismiss(id)`. While the Deck is mapped the
   notice column unmaps and `DeckView` must show a `NoticeStack`.
7. **Rendering limits.** Tests and screenshots use `QT_QUICK_BACKEND=software`
   on headless sway with the pixman renderer. Measured: `MultiEffect` (blur,
   shadow, colourisation), `RectangularShadow`, `ShaderEffect`, and Qt5Compat
   `GaussianBlur`/`OpacityMask` render **nothing, with no warning**. Rectangle
   gradients, radius and border, `layer.enabled` group opacity, `Canvas`,
   rotated antialiased rectangles, scaled `Text` and `Image` do render. Any
   shader look therefore needs a non-shader rendering that carries the same
   meaning, both for the screenshots and for machines without a GPU.
   No compositor blur is configured (the installer writes no `layerrule`),
   so translucent surfaces show the desktop behind them unblurred.
8. **lowEffects.** `theme.lowEffects` is documented as "Opaque backdrops and
   no shadows, for slow GPUs or screen recording". Every translucency, shadow
   or effect you add must switch off under it.
9. **Tokens are user configuration.** Palette role names in `tokens.mjs` are
   the keys users put in `theme.palette`; `resolvePalette` silently drops
   unknown keys, so renaming a role loses users' overrides. `theme.density`
   (`compact`/`standard`/`comfortable`), `theme.motion`, `theme.uiScale`
   (0.75-2.0), `theme.fontSans`/`fontMono` and `theme.lowEffects` are schema
   keys the installer also writes. Renaming or adding keys means editing
   `shell/lib/config.mjs` (Claude) and regenerating the schema; tell Claude
   and keep the old keys working until then. `tokens.mjs` must stay
   V4-compatible because Node, Quickshell and Qt's test runner all load it.
10. **Contrast gate.** `tests/js/launch.test.mjs` (`tokensSuite`) requires
    4.5:1 for `text`, `textDim`, `signal`, `caution`, `critical`, `nominal` on
    `obsidian`, `surface`, `surface2`. If you change the roles, change the
    test with them so it still checks every foreground/background pair you
    actually use. It only checks opaque pairs: text over translucent tints or
    over the desktop needs its own check.
11. **Unknown is not zero.** Unavailable metrics are `null`/`NaN` and show as
    N/A (a hatch, a hollow frame, `--:--`), never as 0. Note that binding
    `null` to a `property real` gives 0, not NaN. Swap total 0 shows NONE;
    `null` shows N/A. Live streams have no length.
12. **Untrusted text is plain text.** Window titles, app ids, notification
    summaries and bodies, media titles, device names, screencast owners and
    model output must render with `textFormat: Text.PlainText`. Today several
    places use the default `AutoText`, which interprets HTML: `StatusLine`,
    `Annunciator` (media title, screencast owner), `FlightStrip` (active
    class), `ResultRow` subtitle, `Sector` and `SpatialNavigator`,
    `StreamRow`, `DeviceRow`, and `AiConsole` proposal rows (`NoticeStack`
    is already fixed). Fix these as you restyle them. The only allowed rich text
    is `Fuzzy.highlightMarkup`, which escapes its input.
13. **Demand-driven work.** Visuals must not add their own sampling or
    timers. `SystemsBay` holds telemetry demand while its `active` property
    is true; the scenarios assert 1000 ms sampling while open and 5000 ms
    right after close. `SignalRack` holds audio detail the same way
    (`Audio.acquireDetail`/`releaseDetail`, reference counted, so other
    views may show device or stream volumes too). `Audio.volumeKnown` is
    false while the default sink's volume is unknown: show N/A then.
    `Ground` must stay static between events. `Trace` is a `Canvas` that
    repaints only when its `seq` changes while visible. `ScreencopyView`
    thumbnails are opt-in, `live: false`, one `captureFrame()` per tile.
    The strip's clock has minute precision unless `strip.showSeconds`.
14. **Service-call semantics stay exact.** For example: `PlayerCard` emits
    `picked()` before `command(...)` so the right player is controlled;
    `DeviceRow` writes volumes clamped to `audio.maxVolume`; `StreamRow`
    shows volume only for bound nodes; `CommandCore.activate()`,
    `SpatialNavigator.runAndReport()` and `RoutineConsole.runCurrent()` keep
    their confirm and report flows; `WorkspaceTape` runs `workspace.focus`
    with `{record:false}`. Restyle around these functions; do not rewrite them.
15. **The AI module is a separate package.** `ai-bridge/qml/AiModule.qml` is
    copied into `<shell>/modules/ai/` and must stay one file (a
    Loader-sourced file cannot resolve sibling types). It uses `Bezel`
    (`designation`, `title`, `status`, `statusColor`, default content),
    `Label` (`text`, `strong`), `StatusLine` (`hints`, `message`,
    `messageState`) and Theme properties `px`, `pad`, `gap`, `rowHeight`,
    `border`, `radius`, `bg`, `surface2`, `grid`, `text`, `textDim`,
    `signal`, `caution`, `critical`, `sans`, `mono`, `fontXs`..`fontLg`.
    Adding Theme properties or component API is free; renaming or removing
    one must change `AiModule.qml` in the same commit.
16. **Strip geometry is window layout.** `exclusiveZone` equals
    `Theme.stripHeight`, which the Deck, `WorkspaceTape` and `Annunciator`
    also read. The screencast annunciator is a privacy indicator and must
    stay visible in any design.
17. **Single display.** Every surface binds `screen: Ui.screen` and hides when
    it is null. With several outputs the strip shows a caution
    (`display.warnOnMultipleDisplays`).
18. **JavaScript is Qt's V4 engine.** Not available: object spread, class
    fields, `async`/`await`, BigInt, `Array.prototype.flat`/`.at`,
    `Object.fromEntries`, `replaceAll`, `matchAll`, `trimStart`, regex named
    groups and lookbehind, `Promise.allSettled`, `structuredClone`, `Intl`.
19. **Fonts are not bundled.** Inter and JetBrains Mono are defaults, not
    dependencies (the installer only warns), and users can set any family.
    The design must survive fontconfig's fallback. The dev image also has
    Inter Display, Inter Variable, JetBrains Mono NL and the Noto families;
    DejaVu and Cantarell are not installed. If a design needs a bundled font,
    ask Claude: it affects packaging and licensing.
20. **Installer trap.** The installer skips any directory named `ai` at any
    depth, so do not put new visual files in a folder called `ai`.
21. **Copy tied to the registry.** The Command Core placeholder and empty
    state and the Help bay spell out the search prefixes from
    `shell/lib/registry.mjs` (`>` commands, `@` windows, `!` routines,
    `?` AI). Keep them in step.

## Systems requests

These are known gaps the brief may need. Astra decides whether the design
needs them; Claude builds them. Record requests in `.ai_sync_hub.json`
(`publish --type note` or a `blocked` event) and in your design document.

Done: the background-layer surface (`Ground`), Deck exit and cross-bay
lifetimes, keyed notices with a defined order above the Deck,
reference-counted audio detail, notification actions
(`Notifications.invokeAction`, `activate`, command `notifications.action`)
and quiet results (a command that already gave feedback returns
`{quiet: true}` and is not reported again).

Still open:

- A lock screen (`WlSessionLock` with PAM authentication) and session
  transitions.
- Brightness (backlight), network, Bluetooth and display-configuration
  services, and a volume/brightness OSD surface.
- Hyprland `layerrule`s from the installer: blur behind a surface, or
  disabling Hyprland's own layer animations (which otherwise stack with
  in-shell motion and ignore `theme.motion`).
- New config keys or renamed palette roles (schema change and migration).

## Seeing your work

The dev image (`tools/devcontainer/Containerfile`) runs Quickshell under
headless sway. Build it once with
`docker build -t aerolith-dev -f tools/devcontainer/Containerfile tools/devcontainer`.

```bash
# Smoke run: strip and Command Core screenshots in build/headless/smoke/
tools/headless/run.sh tests/scenarios/smoke.sh

# Full run with audio, media and routines: one screenshot per bay
AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh tests/scenarios/full.sh
```

`run.sh` empties its output directory first, so pass a separate directory
per run (`tools/headless/run.sh <scenario> build/shots-a`). The scenario
path must be relative and inside the repository. Useful variables: `RES`
(default `1920x1080`), `SCALE`, `CONFIG=<config.json>` (for example
`{"schemaVersion":1,"theme":{"motion":"off"}}` for still frames), `AUDIO=1`,
`MEDIA=1 MPV_AO=pipewire`, `AI=1`, `ROUTINES=tests/fixtures/routines.json`,
`HYPR_MOCK=0` (compositor unavailable). Scenarios use the helpers `ipc`,
`shot`, `typ`, `key`, `mock`, `wait_for_log` and `alive`
(`tools/headless/session.sh`). Global shortcuts do not work under sway; open
bays with `ipc open <bay>`. A shots-only scenario can live in `build/`
(gitignored):

```bash
# shellcheck shell=bash
sleep 3; shot 00-strip
for bay in command navigator systems signal routines help ai; do
  ipc open "$bay"; sleep 1.5; shot "bay-$bay"
done
ipc close; sleep 0.5
ipc run shell.notify '{"message":"Notice test"}'; sleep 0.5; shot notices
alive || { echo "FAIL: quickshell died"; exit 1; }
```

After every run read `$OUT/qs.log`: no scenario fails on QML warnings, but a
`TypeError`, `ReferenceError`, `Unable to assign` or binding loop is a
regression (the current shell logs none).

Checks to run with any visual change:

```bash
node tests/js/run-node.mjs                     # unit tests in Node
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
python3 -m pytest -q tests/py                  # installer and AI bridge
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/deck       # Deck lifecycle, notices
CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh build/notify
AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/perf  # CPU, RSS per state
```

`perf.sh` has no thresholds; compare its `perf.json` with a run from before
your change. Idle states should stay at about 0 % CPU and near-zero context
switches. `qmllint` is in the image at `/usr/lib/qt6/bin/qmllint`.

Hyprland itself cannot run in the dev environment (no GPU or DRM device).
Hyprland IPC is a protocol mock, and nothing has been verified on a real
Hyprland session yet.
