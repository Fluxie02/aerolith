# UI-003 verification

All commands ran from `/home/user/aerolith-astra`. Headless commands used distinct
`build/limb/` output directories; the required scenarios used production `shell/`.

| Exact command (output-directory argument omitted) | Result |
|---|---|
| `node tests/js/run-node.mjs` | 103 passed, 0 failed |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 103 passed, 0 failed |
| `python3 -m pytest -q tests/py` | 68 passed, 1 skipped |
| `tools/headless/run.sh tests/scenarios/smoke.sh` | passed |
| `AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh` | passed, including final rerun |
| `AUDIO=1 MEDIA=1 MPV_AO=pipewire tools/headless/run.sh tests/scenarios/signal.sh` | passed; unlinked mpv graph routing checks skipped by harness |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh` | passed, including final rerun; immediate demand release, rapid switch, reopen input, motion off, notice expiry |
| `CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh` | passed; keyed popup lifetime and action delivery |
| `AI=1 AUDIO=1 tools/headless/run.sh tests/scenarios/ai.sh` | passed; fake provider, proposal review, approval and dismissal |
| `AUDIO=1 MEDIA=1 MPV_AO=pipewire tools/headless/run.sh tests/scenarios/perf.sh` | passed; 120 s idle, 30 s per subsequent state |
| `tools/headless/run.sh build/limb/windows.sh` | passed; real mock window open, M→4 move, Enter focus, X X close, literal markup |
| `git diff --check` | passed |

Capture runs: `build/limb/final-judge.sh` (1080p, audio/media/routines),
`RES=1280x720 CONFIG=build/limb/small.json` with `build/limb/preview.sh`
(uiScale 1.25, standard density, Noto Sans/Mono, motion off, lowEffects),
and `CONFIG=build/limb/reduced.json` with `build/limb/judge.sh`.
The capture scripts and config seeds are retained under `build/limb/`.

Every retained run's `qs.log` was read and scanned for QML parse, type, reference,
assignment and binding errors: none in the final runs. `log-audit.json` records
all 16 logs, including staging. Initial duplicate Label textFormat and a staging
Flow implicitHeight assignment were fixed before final runs. A source edit caused
one development capture to reload; its affected Signal/Routine/Help shots were
replaced with final full-scenario captures. Expected headless warnings remain:
missing Hyprland-only Wayland protocols and UPower/system bus/RTKit; smoke and
non-audio runs cannot connect PipeWire. The routine fixture intentionally includes
one invalid action and displays the actual configuration warning.

## Performance

Same `perf.sh`, software renderer and default observation lengths as the original.
CPU is percent of one core. These are single-run measurements, not a GPU benchmark.

| State | Original CPU / switches per s / MiB | Limb CPU / switches per s / MiB |
|---|---|---|
| Idle | 0.12 / 2.1 / 82.2 | 0.06 / 0.8 / 119.8 |
| Systems open | 2.93 / 135.6 / 108.8 | 2.30 / 88.4 / 161.4 |
| Command open | 0.33 / 10.3 / 106.4 | 0.17 / 5.0 / 159.3 |
| Idle after use | 0.10 / 2.1 / 89.9 | 0.07 / 1.2 / 132.6 |
| Peak RSS | 116.9 MiB | 180.4 MiB |

Idle remains near zero. RSS is higher with the new background surface and Canvas
planes: +37.6 MiB initially and +42.7 MiB after use. No idle animation or sampling
was added. The full-scenario render overlapped the beginning of the idle window;
all measurements read only the measured Quickshell process, and no source reload
occurred during the performance run. Original/final raw JSON accompanies this file.

## Limits and handoff

Real Hyprland, GPU frame pacing, real hardware and compositor layer-animation
suppression are unverified in this software-rendered sway harness. Mock window
open/focus/move/close were verified; maximize/fullscreen is not exposed by the
mock control protocol, so that state still needs a real session. Installer-owned
Hyprland layer animation rules remain Claude's systems work. No host or schema
change is needed for this implementation. AI console-specific refinement is the
requested follow-up; no file under `ai-bridge/` was edited.

Astra reviewed the merged hosts/services once: no actionable concrete finding in
Deck focus and demand release, ground lifecycle, notice expiry/order or audio
detail ownership. Claude's single systems/performance review follows design_complete;
one revision is allowed. No commit was attempted because shared Git is read-only.
