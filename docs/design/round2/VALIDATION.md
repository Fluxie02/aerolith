# UI-002 · Validation and handoff

## Scope

Exactly three executable concepts: Keel, Limb and Fault. Each has an idle ground,
Flight Strip, typed Command Core, navigator, live Systems bay, notice and six
opening captures plus the settled frame. All 36 retained PNGs were inspected,
including full-resolution command and navigator checks. The original screenshot
pixels are retained; WebP files only encode the captured sequence for playback.

`prototypes/r2-common/` contains the exploratory presentation and local copies of
the original command/navigator event functions. Each concept has a small
`shell.qml`, a `visual` symlink to that shared presentation, and symlinked
`core`, `services`, `lib`, `components` and `modules`. No `shell/` edits, commits,
branch changes, new service or public config key were made. These prototypes
require this checkout; they are not installable standalone shells.

The original registry activation/confirmation/report flows, navigator dispatches
and Systems telemetry acquisition/release are retained. Opening Systems asserts
1000 ms sampling; closing asserts 5000 ms. No visual sampling timer or idle
animation was added. Ground canvases redraw on geometry, workspace, bay and
bounded opening-progress events. Motion off and low-effects were checked together;
the tests do not independently establish each setting's behavior. All newly presented untrusted text is plain text.

## Commands and results

Run from `/home/user/aerolith-astra`:

```bash
AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh tests/scenarios/full.sh build/r2-original
```

The requested original run rendered its strip and typed Command Core, then failed
at the volume assertion: PipeWire had no default sink (`Translate ID error: -1`).
The original was visually inspected before concept construction. The later
captures show the harness's test audio/media records, but audio routing is not
claimed verified.

```bash
node tests/js/run-node.mjs
# 100 passed, 0 failed

docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
# 100 passed, 0 failed

python3 -m pytest -q tests/py
# 68 passed, 1 skipped

for concept in keel limb fault; do
  SHELL_PATH="prototypes/r2-$concept" AUDIO=1 MEDIA=1 MPV_AO=pipewire \
    ROUTINES=tests/fixtures/routines.json \
    tools/headless/run.sh prototypes/r2-capture.sh "build/r2-$concept"
done
# All three: exit 0, round2: ok; demand assertions passed.

for concept in keel limb fault; do
  CONFIG=prototypes/r2-motion-off.json SHELL_PATH="prototypes/r2-$concept" \
    AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
    tools/headless/run.sh prototypes/r2-capture.sh "build/r2-off/$concept"
done
# All three: exit 0, round2: ok; motion off + lowEffects + Noto font overrides.
# For every concept, motion frames 2–6 and settled are byte-identical.
```

The capture scenario enables the existing `notifications.server` and
`strip.telemetry=always` settings only inside the disposable container's config.
It types `@ a`, exercises navigator selection/close confirmation without accepting
it, changes Systems sorting, checks telemetry demand, and delivers a real D-Bus
notice. It schedules six `grim` captures 35 ms apart after launching `ipc open
command`; `motion-timing.json` records invocation times, rather than claiming
precise compositor presentation timestamps. No animation was slowed for capture.

Final concept, motion-off and performance QML logs were checked for TypeError,
ReferenceError, assignment errors and binding loops. Expected harness warnings
include unsupported Hyprland protocols under sway, unavailable UPower/system bus,
the intentionally invalid routine fixture, PipeWire scheduling/route warnings,
and Qt Wayland virtual-keyboard focus warnings.

Opaque text contrast was checked for six foreground roles across the three
background roles in each concept: 54 pairs passed 4.5:1. Minimum ratios:
Keel 5.61, Limb 5.91, Fault 6.09. This is a token check, not a complete
accessibility certification of arbitrary user palette overrides or wallpapers.
The designed ground is darker than the selected/tinted faces used for the checks.

## Performance

```bash
AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/r2-perf-original
for concept in keel limb; do
  SHELL_PATH="prototypes/r2-$concept" AUDIO=1 MEDIA=1 \
    tools/headless/run.sh tests/scenarios/perf.sh "build/r2-perf-$concept"
done
SHELL_PATH=prototypes/r2-fault AUDIO=1 MEDIA=1 \
  tools/headless/run.sh prototypes/r2-common/perf-final.sh build/r2-perf-fault
```

The existing scenario measured 120 s idle and 30 s per subsequent state for the
original, Keel and Limb. The interrupted queue never started Fault; its final
wrapper sources the same scenario with 20 s idle and 10 s per subsequent state.
Fault therefore has lower measurement precision. All use default telemetry settings.
Full raw results are retained alongside this document as `perf-*.json`; the table below is generated
from those results. The prototype background and retained software image buffers
increase RSS. Startup/capture activity overlapped part of the early measurements,
so these are indicative process measurements, not isolated frame-time benchmarks.

| Shell | Idle CPU % | After use CPU % | Idle RSS MiB | After use RSS MiB | Systems CPU % |
|---|---:|---:|---:|---:|---:|
| Original | 0.12 | 0.1 | 82.2 | 89.9 | 2.93 |
| Keel | 0.13 | 0.13 | 112.1 | 132.4 | 2.33 |
| Limb | 0.42 | 0.13 | 133.1 | 132.3 | 2.87 |
| Fault | 0.15 | 0.1 | 117.8 | 140.4 | 2.5 |

All four performance runs completed with `perf: ok`. Fault uses the shorter
windows specified above. CPU percentages are fractions of one core.

## One review of Claude's systems work

Read-only review of the in-progress main-worktree `Deck.qml`, `DeckView.qml`,
`Ui.qml`, `NoticeStack.qml` and registry-result changes: no actionable finding
in the portions reviewed. Deck retirement is bounded, outgoing bays release
activity/focus before destruction, notice expiry is arrival-based and centralized,
and keyed views retain notice identity. The new hooks fit the three concepts.
This review did not integrate or execute that separate worktree; the prototypes
still use the services and lifecycle in the Astra checkout.

## Limits

Real Hyprland, GPU rendering, hardware audio routing, compositor blur and physical
input were not verified. Exit and cross-bay retention are integration work for the
chosen concept. The prototype demonstrates opening and reactive selection; its
Deck closes immediately under the current Astra-worktree lifecycle. Routine,
Sound and Help use the original bays; AI is an explicit unavailable placeholder.
The requested 1920×1080 layout was judged; small screens, extreme UI scaling,
large window counts and complete accessibility behavior need a production pass
after the owner chooses. When geometry is unavailable, navigator tiles use a
stacked occupancy fallback rather than claiming spatial window positions.
