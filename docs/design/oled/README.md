# OLED-2 verification and Astra review packet

Current implementation and refreshed captures: [OLED-3 verification](OLED-3.md).
The remainder of this page is the historical OLED-2 record.

Baseline revision: `05912cb44a70aeada1b71d34ca7d9cd89cc61149`.

4 November 2026. Implementation by Terra in the OLED-2 worktree; no commit,
lock or unlock. The shared hub still names the old UI-016 owner; the user's
explicit OLED-2 assignment authorizes working under Opus's existing locks.
Astra has not reviewed these images yet. No new palette, layout, typography,
spacing or animation timings were designed: the opt-in changes use OLED-1.

## Result by requested item

1. **Partial within assigned files.** Ground and Strip each own a profile
   bound to their actual connector. Deck, notices, OSD and session each bind
   to their placement output. Shared components accept an explicit `profile`
   property, with Theme as the compatibility default. Retained canvases repaint
   on profile changes. Standard output pixels are preserved. **Deck bay
   interiors are outside the allowed scope:** CommandCore/ResultRow,
   SpatialNavigator/Sector, SystemsBay/CoreBus, SignalRack/DeviceRow/StreamRow/
   PlayerCard, RoutineConsole, HelpBay, SettingsBay/SettingControl/SchemePicker
   and the optional AI bay still need mechanical property plumbing. Their
   direct Theme fills and nested components keep standard values. The OLED
   Deck image intentionally exposes this remaining gap; the surface root
   still dims its entire bay content. Scope expansion was requested; no
   out-of-scope files were edited. OLED-2 should remain open until resolved.
2. **Implemented.** `display.oled.idleDimAfter` defaults to 300 seconds (0
   disables), `idleDimLevel` to the existing token value 0.65,
   `hideDecorationWhenIdle` to true. Schema and configuration reference are
   regenerated. Old configuration and `display.output` remain valid.
3. **Implemented; hardware resume remains unverified.** One shared
   IdleMonitor is enabled only while a connected output opts in. Each surface
   dims one presentation root; OLED Deck content has black backing that leaves
   the strip lane exposed. Static field/carriage decoration hides when enabled;
   functional controls remain available. Existing ambient movement stops on
   idle OLED outputs. Entering idle uses existing motion durations; restoration
   is immediate, including when interrupting a reduced-motion fade. The
   Behavior checks its target value, avoiding an unintended upward fade.
   No production polling, timer, continuous animation, pixel movement or
   monitor-brightness control was added.
4. **Implemented.** `ipc status` includes `profile` and `idleDimmed` on each
   `outputs` entry.
5. **Implemented for the scoped surfaces.** Unit/config tests, mixed-output
   scenario, live profile toggles, pixel comparisons, idle and reduced-motion
   interruption checks, OSD/session component profile checks, and CI wiring.
   The scenario does not claim OLED coverage of the out-of-scope bay interiors.
6. **Measurements:** see the performance table below and the raw JSON files.

## Screenshots (960 × 540)

| State | Output 1 (standard) | Output 2 |
|---|---|---|
| Both standard | [standard-1.png](standard-1.png) | [standard-2.png](standard-2.png) |
| Output 2 OLED | [oled-1.png](oled-1.png) | [oled-2.png](oled-2.png) |
| Idle | [idle-1.png](idle-1.png) | [idle-2.png](idle-2.png) |

[OLED Deck, with the remaining bay-interior gap](deck-oled-2.png).
Output 1's standard/OLED/idle frames compare byte-for-byte as raw RGB at full
resolution. Output 2 has a true-black background, visibly dims, restores its
exact active OLED pixels, and returns to its standard pixels after a live
profile toggle. Scene-graph swap counters in the disposable shell observe
zero swaps over three settled idle seconds on both Ground/Strip instances.

Original baseline revision versus current standard rendering is compared separately on
both 1920 × 1080 outputs with motion/strip telemetry off. Only clock/date and
the live memory readout are frozen in disposable shell copies. No production
bindings are frozen. The first unfrozen comparison differed solely in the
live memory digit (bbox 224,131–231,139), so it was repeated with that readout
held constant. See `standard-pixel-comparison.json`. The disposable capture script is
[standard-comparison.sh](standard-comparison.sh), using
[standard-config.json](standard-config.json).

## Idle test limitation

Sway delivered the real IdleMonitor idle event after the two-second fixture
timeout. Its virtual keyboard/pointer input did not produce a resume event in
this harness. The scenario records that result and resets an override only
inside its disposable Idle.qml copy to exercise the production restore
bindings. That override has no production IPC endpoint or configuration.
`immediate-resume.json` is `[1,1,1,1]`, including interruption of a reduced
80 ms fade. Test real physical-input resume and idle inhibitors on hardware.

## Commands and results

All headless scenarios ran sequentially. Output directories below are under
`build/oled2/` in the worktree; each contains its compositor/shell logs.

```sh
node tests/js/run-node.mjs                       # 205 passed, 0 failed
python3 -m pytest -q tests/py                    # 303 passed, 1 skipped
node tools/gen-schema.mjs                       # regenerated schema
node tools/gen-config-doc.mjs                   # regenerated docs
node tools/gen-config-doc.mjs --check           # current
bash -n tests/scenarios/oled.sh                  # pass
git diff --check                                # pass

tools/headless/run.sh tests/scenarios/smoke.sh build/oled2/smoke
# smoke: ok
OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/oled2/multimonitor
# multimonitor: ok
OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/oled2/oled
# oled: ok; real idle, hook-assisted resume; zero settled swaps
AUDIO=1 CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/fullscreen.sh build/oled2/fullscreen
# fullscreen: ok; 20 cycles, no sustained RSS growth
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/oled2/deck
# deck: ok; motion-off exit ended at once

OUTPUTS=2 CONFIG=build/oled2/standard-config.json SHELL_PATH=build/oled2/baseline/shell tools/headless/run.sh build/oled2/standard.sh build/oled2/standard-before
OUTPUTS=2 CONFIG=build/oled2/standard-config.json tools/headless/run.sh build/oled2/standard.sh build/oled2/standard-after
# standard screenshots: ok; compare full-resolution RGB with Pillow

SHELL_PATH=build/oled2/baseline/shell tools/headless/run.sh tests/scenarios/perf.sh build/oled2/perf-before-isolated
CONFIG=build/oled2/oled-perf-config.json SHELL_PATH=build/oled2/final-shell tools/headless/run.sh tests/scenarios/perf.sh build/oled2/perf-after-oled
```

The first perf attempt (`perf-before`) mixed original and newly loaded source
while development proceeded; it is excluded. The valid baseline comes from
`git archive 05912cb44a70aeada1b71d34ca7d9cd89cc61149 shell` unpacked into `build/oled2/baseline/`. The after run
uses a frozen copy of the final shell, with HEADLESS-1 opted into OLED and a
two-second idle timeout (the identical fixture is checked in as
`tests/fixtures/oled-perf-config.json`). Both use the unmodified perf.sh 120/30 second windows,
no audio/media flags, one output, software Qt/pixman and seeded covered desktop.
Context switches are the harness's wakeup proxy, not a hardware interrupt count.

## Performance

| State | Baseline CPU % | OLED CPU % | Baseline switches/s | OLED switches/s |
|---|---:|---:|---:|---:|
| idle-strip | 0.11 | 0.11 | 1.7 | 1.7 |
| systems-bay-open | 4.03 | 3.10 | 102.3 | 80.2 |
| command-core-open | 0.77 | 0.20 | 28.5 | 5.8 |
| idle-after-use | 0.07 | 0.10 | 1.7 | 1.7 |

Idle CPU and wakeup proxy are unchanged. The idle-after-use CPU difference is
one 0.01-second CPU tick over 30 seconds; switches stay 1.7/s. Peak RSS:
202.9 → 205.9 MiB. Raw measurements are
[perf-before.json](perf-before.json) and
[perf-after-oled.json](perf-after-oled.json). The two-output idle swap-counter
check separately records zero redraws with unchanged inputs.

Full changed-path inventory: [changed-paths.txt](changed-paths.txt). The source
changes are confined to the assigned shared components/surfaces, DisplayProfile,
Idle, tokens/config, IPC status, shell service initialization, schema/docs, tests
and CI. Review evidence is in this directory; full runtime logs stay in build/.

The OLED scenario was also run against the isolated original baseline and
rejected its missing surface profile wiring with exit 1, as expected; see
[regression-proof.txt](regression-proof.txt). Exact negative command:

```sh
OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json SHELL_PATH=build/oled2/baseline/shell tools/headless/run.sh tests/scenarios/oled.sh build/oled2/regression-original
# exit 1 (expected): missing per-surface profile interfaces
```

All five mandatory scenario logs have zero QML binding/type/reference errors.
The separate standard comparison's final rendering scenes also have zero.
Stopping its initial shell emitted eight `undefined` assignment warnings in
one run (Theme/Ui/Compositor/Notifications and Idle); they precede the copied
scene startup and are preserved separately in `log-audit.json`. This remains
a teardown diagnostic, not a verified runtime failure; no unrelated shutdown
refactor was made.

## Review and remaining risks

Reviewed MM-1/MM-1b's Displays/settingsFor/liveScreen and surface ownership once.
No actionable finding in that reviewed area: connector policy is centralized,
Qt screen identity is preserved on unplug, and services stay singleton.

- Deck bay propagation requires scope expansion before OLED-2 is complete.
- Astra still needs to review OLED-1 token use and these mixed-output images.
- Real mixed scale/refresh, OLED brightness/perceived contrast, real physical
  input resume, idle inhibitors, DPMS/sleep/wake, GPU shader execution and NVIDIA
  fullscreen require hardware. Software outputs cannot establish panel power
  consumption or burn-in protection.
- The framebuffer-swap check deliberately freezes existing changing readouts;
  it proves the new idle policy adds no continuous redraw. Existing clocks and
  telemetry continue to update at their configured cadence.
