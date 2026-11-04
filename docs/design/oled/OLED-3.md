# OLED-3 verification — Terra

4 November 2026. Worktree base `8e273ef960336b7acf9e97ae960d282e60990894`.

Decisions 1, 2 and 4 are implemented. Decision 3 is implemented for Command,
Navigator, Systems, Signal, Routines, Help, Settings and the missing-AI fallback.
**The installed AI console remains outside the supplied edit scope:**
`ai-bridge/qml/AiModule.qml` reads Theme directly at lines 489–656 and does not
accept a profile. Permission to include that file was requested; no response
has arrived. OLED-3 must remain open until that console is updated and tested.

- `DisplayProfile.appLink` resolves Theme.appLink × 0.80, with the existing
  foreground repair. Limb is `#67b8be`. All seven roles pass 4.5:1 against
  black, material planes and the actual translucent Bezel/input composites.
- Only persistent Ground/Strip decoration takes idle policy. With hiding on,
  Ground's entire presentation disappears and Strip retains only the opaque
  textDim clock and raised privacy/caution/critical cells. Layout space is
  retained; seconds are suppressed at idle. With hiding off, functional text
  remains opaque and decoration takes 0.55 × configured idleDimLevel.
  Deck, notices, OSD and session keep full foreground opacity and their
  non-idle decoration. Existing ambient work stops at OLED seat idle.
- Every core Deck bay and nested visual receives the destination profile.
  Theme continues to supply geometry, type and motion. OLED selected/tinted
  rows use surface2, recessed inputs use bg, separators use grid, and
  functional focus outlines remain opaque signal. Standard aliases are
  unchanged.
- Ground AppContinuity requires primary-output identity and its previous
  conditions. Tests cover primary changes, focus changes and single-output
  fallback without moving/reflowing the vacant area.

## Checks

Commands below ran sequentially for headless scenarios. Output directories
are under `build/oled3-*`; unit logs are under `build/oled3/`.

```sh
node tests/js/run-node.mjs
python3 -m pytest -q tests/py
node tools/gen-config-doc.mjs --check
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
tools/headless/run.sh tests/scenarios/smoke.sh build/oled3-smoke
OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/oled3-oled
OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/oled3-multimonitor
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/oled3-deck
tools/headless/run.sh tests/scenarios/app-links.sh build/oled3-app-links
SHELL_PATH=build/oled3/baseline/shell tools/headless/run.sh tests/scenarios/perf.sh build/oled3-perf-before-frozen
tools/headless/run.sh tests/scenarios/perf.sh build/oled3-perf-after
git diff --check
```

Node: 207 passed, 0 failed. Qt JS: 193 passed, 0 failed. Pytest: 303 passed,
1 skipped. Configuration documentation is up to date. All listed headless
scenarios pass. The OLED scenario verifies loaded bay identity before checking
profiles (preventing an empty-loader pass), live movement to either output,
opaque retained clock, no seconds even with showSeconds enabled, hiding-off
text, sharing opacity, transient exemptions, immediate interruption/resume of
Ground and workspace-tape fades, and zero Ground/Strip swaps over 3 settled
idle seconds. Test-only clock/telemetry freezing makes pixel comparisons
independent of wall time and system load.

The expanded tests were also run against disposable regressions: old token
logic fails the appLink/opaque-idle expectations; omitting Deck profile
assignment fails the loaded-bay profile assertion; restoring duplicate bars
fails the initial primary-only assertion. These expected failures are recorded
in `build/oled3/regression-{tokens,deck,primary}.txt`.

A frozen original shell and current shell were captured with
`OUTPUTS=2 CONFIG=docs/design/oled/standard-config.json`, using the existing
`standard-comparison.sh` copied to `build/oled3/standard.sh` and
`SHELL_PATH=build/oled3/baseline/shell` for the baseline. Primary standard PNGs
compare byte-for-byte. Secondary differences are intentional primary-only
app-bar removal. The OLED scenario also compares raw full-resolution standard
output pixels across profile/idle changes and restores exact secondary pixels
when switching back to standard.

The performance baseline is a frozen `git archive HEAD shell` extraction in
`build/oled3/baseline/`; the compared current checkout stays unchanged during
its measurement. Both use the same default single-output software-rendered
scenario, 120 s initial idle and 30 s per subsequent state. An initial run
against live source was discarded from comparison because edits could reload
its QML.

## Performance comparison

CPU is percent of one core; switches are voluntary + involuntary context
switches per second. Same software renderer, output count and durations.

| State | CPU before → after | Switches/s before → after |
|---|---|---|
| idle-strip | 0.11% → 0.11% | 1.6 → 1.6 |
| systems-bay-open | 3.50% → 3.66% | 92.0 → 96.5 |
| command-core-open | 0.87% → 0.83% | 25.0 → 25.0 |
| idle-after-use | 0.13% → 0.13% | 1.9 → 1.6 |

Raw results: [before](perf-oled3-before.json), [after](perf-oled3-after.json).
QML [log audit](oled3-log-audit.json): zero errors in smoke, OLED, multimonitor,
Deck and app-links. Software idle cost is unchanged; real GPU/panel behaviour
remains unmeasured.

## Captures and limits

The seven existing 960×540 captures are refreshed. New `bay-*-oled.png` images
show each remaining core bay and the **missing-AI fallback**, not the installed
AI console. The old README and evidence below it describe OLED-2 history;
this record supersedes its remaining-core-bay gap and whole-surface-idle policy.

Headless sway delivers the real IdleMonitor idle event. Virtual input still
does not resume that monitor; a disposable test hook verifies immediate
production-binding restoration. Real input resume, mixed refresh/scale,
near-black OLED separation and actual panel brightness/retention remain
hardware follow-up. No host settings, global packages or commits were changed.

Review of the inherited Sol/Terra boundary work: Displays.primary fallback,
Ui.overlayScreen placement, singleton IdleMonitor and per-output profile
construction preserve the documented ownership/lifecycle contracts. No new
systems finding was identified. **P2, unresolved inherited gap:**
`ai-bridge/qml/AiModule.qml:489` and the AiConsole controls at 498–656 still
read global Theme colours. Minimal correction: give AiConsole a profile,
forward it into Bezel/Label/StatusLine, and map colour roles to that profile;
Deck.BaySlot.onLoaded already supports the handoff. Including this file needs
the scope clarification requested above.

## Changed paths

Source/test edits and refreshed review artifacts:

```text
docs/design/oled/OLED-3.md
docs/design/oled/README.md
docs/design/oled/bay-ai-oled.png
docs/design/oled/bay-help-oled.png
docs/design/oled/bay-navigator-oled.png
docs/design/oled/bay-routines-oled.png
docs/design/oled/bay-settings-oled.png
docs/design/oled/bay-signal-oled.png
docs/design/oled/bay-systems-oled.png
docs/design/oled/deck-oled-2.png
docs/design/oled/idle-1.png
docs/design/oled/idle-2.png
docs/design/oled/oled-1.png
docs/design/oled/oled-2.png
docs/design/oled/oled3-log-audit.json
docs/design/oled/perf-oled3-after.json
docs/design/oled/perf-oled3-before.json
docs/design/oled/standard-1.png
docs/design/oled/standard-2.png
shell/components/Annunciator.qml
shell/components/AppContinuity.qml
shell/components/AppGlyph.qml
shell/components/Bezel.qml
shell/components/ChordSlot.qml
shell/components/CircularField.qml
shell/components/Counterphase.qml
shell/components/Hatch.qml
shell/components/InstrumentField.qml
shell/components/InstrumentTabs.qml
shell/components/Instrumentation.qml
shell/components/KeyHint.qml
shell/components/Label.qml
shell/components/Material.qml
shell/components/MetricTape.qml
shell/components/NowPlaying.qml
shell/components/Readout.qml
shell/components/Ruler.qml
shell/components/ScrollMark.qml
shell/components/StatusLine.qml
shell/components/TapeGauge.qml
shell/components/Trace.qml
shell/components/WorkspaceOrbit.qml
shell/core/DisplayProfile.qml
shell/lib/tokens.mjs
shell/modules/command/CommandCore.qml
shell/modules/command/ResultRow.qml
shell/modules/deck/Deck.qml
shell/modules/deck/DeckView.qml
shell/modules/ground/Ground.qml
shell/modules/ground/GroundSurface.qml
shell/modules/help/HelpBay.qml
shell/modules/navigator/Sector.qml
shell/modules/navigator/SpatialNavigator.qml
shell/modules/routines/RoutineConsole.qml
shell/modules/settings/SchemePicker.qml
shell/modules/settings/SettingControl.qml
shell/modules/settings/SettingsBay.qml
shell/modules/signal/DeviceRow.qml
shell/modules/signal/PlayerCard.qml
shell/modules/signal/SignalRack.qml
shell/modules/signal/StreamRow.qml
shell/modules/strip/FlightStrip.qml
shell/modules/strip/StripClock.qml
shell/modules/strip/WorkspaceTape.qml
shell/modules/systems/CoreBus.qml
shell/modules/systems/SystemsBay.qml
tests/js/runtime-qml.test.mjs
tests/js/tokens.test.mjs
tests/scenarios/multimonitor.sh
tests/scenarios/oled.sh
```
