# Phase 1 — reconnaissance

Astra · UI-001 · 22 October 2026 · baseline `9fe38cd`.

Read DESIGN_BRIEF.md, ARCHITECTURE.md (all 21 contracts), AGENTS.md, the local and shared hubs, and tools/agent-sync/README.md in full. There is no DECISIONS.md. The shared authoritative hub at `/home/user/aerolith/.ai_sync_hub.json` is `Astra_Design_Phase`, owner Astra, with no competing locks. This worktree is on `codex/astra-visual-language`.

## What exists

The shell is QML on Quickshell, with three layer-shell windows: a 28 logical pixel top/bottom Flight Strip, an exclusive-focus fullscreen Deck, and non-focusing notices. The strip reserves window space. The Deck contains seven stable bay ids; its rail is also the Ctrl+1..6 key map. UI state and service calls are independent of styling. Navigator already exposes titles, classes, workspace occupancy and window geometry; thumbnails are optional, single-capture, and unavailable in the sway harness. Command Core searches actual registry providers, supports typed arguments and confirms sensitive commands. Signal Rack exposes live PipeWire devices, streams and MPRIS players. Systems Bay owns demand for telemetry. Routines and AI are transactions, not decorative consoles.

Visually, nearly every surface is a small-type dark rectangular instrument: cyan brackets, thin rules, uppercase mono labels, identical shallow radii and framed rows. The top strip is dense but has useful privacy and fault indicators. The overview spends most of its space on empty miniature desktops and cannot show long titles well. Audio allocates three equal columns even when their contents differ markedly. The launcher has a clear input/result hierarchy, but looks like another instrument. The bare desktop is black: the shell does not draw wallpaper. This is visible in the baseline, not a styling defect in the Deck.

## Evidence from code and harness

Inspected shell.qml; Theme.qml and tokens.mjs; Ui.qml; Compositor, Audio, Media and Telemetry; Deck, FlightStrip, NoticeColumn; CommandCore, SpatialNavigator and SignalRack; the mock seed, dev Containerfile, run.sh, session.sh, full.sh and perf.sh. Baseline: `AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/design-baseline`. Screenshots inspected directly: strip, overview and audio. Full results and later checks are in VALIDATION.md.

The display is one 1920×1080 headless output by default, adjustable with RES/SCALE. The mock supplies actual protocol state: foot / `pilot@aerolith: ~` on workspace 1; Firefox / `Hyprland Wiki — Mozilla Firefox` and Nautilus / `Downloads` on 2; Code / `aerolith — Visual Studio Code` on 3. Empty workspaces 4 and 5 are configured slots, not invented tasks. PipeWire creates Test Speakers, Test Headphones and Test Microphone; mpv publishes AEROLITH Test Tone. The mock windows do not create actual application pixels. An active-window composition must therefore be tested with a real foot process in sway; never draw a counterfeit Firefox screenshot.

The harness binds the repository read-only and a unique output directory writable. SHELL_PATH selects a directory containing shell.qml; output is erased at the start of each run. QT_QUICK_BACKEND=software and pixman are hard evidence in session.sh. Contract 7 documents measured silent failures for MultiEffect, RectangularShadow, ShaderEffect, GaussianBlur and OpacityMask; no shader is an acceptable dependency. Rectangles, gradients, borders, radii, Canvas, rotated antialiased geometry, group opacity and text are available. The prototypes will independently exercise geometry, Canvas and typography with this backend. Existing measurements of shader failures are accepted, not falsely described as remeasured here. No blur layer rules are installed.

Inter, Inter Display, Inter Variable, JetBrains Mono, JetBrains Mono NL and Noto are installed by the dev environment; fonts are not shipped by AEROLITH. User font overrides must win. No bundled font is needed. Backgrounds can be constructed in QML: no image generation, heavy bitmap dependency or new package is required.

## Constraints that shape the exploration

No ambient loops or pointer polling. Event-driven geometry is enough. Every animation must use Theme tokens, disable entirely for off and lowEffects, and lose travel for reduced. Text from services must explicitly be PlainText; only escaped Fuzzy highlight markup is privileged. Unknown telemetry, duration and device volume stay unknown, never zero. V4 rules exclude object spread, async/await and modern convenience APIs. Original key handlers, confirmations, registry prefixes, bay ids, focus ownership and service demand must survive the next implementation phase.

The prototype directories can reuse production services through relative symlinks, while keeping exploratory presentation outside shell/. They demonstrate possible background composition only; they do not provide production background lifecycle infrastructure. No production code changes are authorized this run.

## Claude dependencies and one review of the handoff

A background-layer surface is essential for a designed idle desktop. Secure lock/session surfaces, brightness/network/Bluetooth/display services and their availability states need systems work. Deck exit/cross-bay lifetimes, stable notice identity and ordering, and compositor animation policy are also systems responsibilities. A second detailed-audio consumer would require reference counting; the exploration will keep just one.

Review findings from Claude’s current handoff (one pass):

| Severity | Evidence / affected file | Minimal correction |
|---|---|---|
| Medium | `shell/modules/notices/NoticeColumn.qml` repeats JS arrays; `Ui.notices` replacement rebuilds delegates and their expiry timers. ARCHITECTURE contract 6 already acknowledges this. | Provide stable keyed notice records and expiry anchored to creation time; changing one record must not restart another. |
| Medium | `shell/modules/deck/Deck.qml` ties visibility and Loader lifetime directly to Ui.deckOpen / activeBay. | Separate visual transition completion from demand release; release demand immediately and finish exit within bounded time. |
| Low | `shell/modules/help/HelpBay.qml` list.flick is not gated by motion off (contract 5). | Gate kinetic scrolling/feedback consistently; include off in acceptance checks. |

These are requests for Claude, not changes made here. Known headless limitations (no system bus/UPower, global shortcuts or Hyprland mapping) are not silently reported as production regressions. A real Hyprland/GPU session remains necessary.
