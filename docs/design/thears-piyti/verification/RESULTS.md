# UI-012 verification

The final required matrix passes: `smoke`, `full`, `deck`, and `ai` for THEARS and PIYTI in both Saturated and Insane (16 runs, exit 0). The production shell remains on THEARS; PIYTI was tested from a frozen review copy with only `Theme.applicationDirection` changed to `"piyti"`. No host installation, account login, git mutation, or development-image change was used.

Exact command arguments, environment, output paths, exits, timing, source hashes, and performance data are in [manifest.json](manifest.json). Runtime logs and scenario output are archived as `.txt` because the repository ignores `*.log`. The unit output is preserved as [Node](logs/unit-node.txt), [Qt V4](logs/unit-qt-v4.txt), and [Python](logs/unit-pytest.txt).

| Check | Result |
|---|---|
| `node tests/js/run-node.mjs` | 104 passed, 0 failed; exit 0 |
| Qt V4 `qml6 tests/js/run-qt.qml` | 104 passed, 0 failed; exit 0 |
| `python3 -m pytest -q tests/py` | 71 passed, 1 skipped; exit 0 |
| Required final headless scenarios | 16 / 16 pass |
| Compact reduced/off capture checks | 8 / 8 pass; 1280×720, uiScale 1.25, Noto fonts; off also uses lowEffects |
| Final motion capture checks | 4 / 4 pass; actual QML frames and fixture assertions |
| Short `perf.sh` confirmations | Both directions exit 0; exact results archived |
| `qmllint` on the six changed QML files plus the Ground wrapper | exit 0; static import-resolution and unqualified-access warnings remain |

The unit commands were run before the QML presentation edits. No JavaScript library, installer, or Python source changed afterward; the final headless runs load the changed QML using Qt's V4 engine. The skipped Python test requires host `luac`.

## Exact scenario invocations

All scenarios used `tools/headless/run.sh` and the unchanged `aerolith-dev` image. For each `direction` in `thears piyti` and `intensity` in `saturated insane`, the required invocation was:

```bash
SHELL_PATH="build/ui012/$direction-final-shell" \
CONFIG="build/ui012/$intensity-full.json" \
AUDIO=1 AI=1 MEDIA=1 MPV_AO=pipewire \
ROUTINES=tests/fixtures/routines.json \
tools/headless/run.sh "tests/scenarios/$scenario.sh" "$out"
```

`scenario` is `smoke`, `full`, `deck`, or `ai`. Deck additionally used `HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1"`. The saved final THEARS/Saturated smoke run was preserved across the interruption. The other runs were completed or retried afterward. The full scenario verifies typed volume changes against PipeWire, workspace dispatch against the Hyprland protocol mock, telemetry demand and release, routine side effects, and shell survival. Deck verifies bay lifetimes, geometry, notices, failed-save rollback, and subsequent successful save. AI uses a local fake provider, verifies explicit invocation and proposal approval, then removes the temporary AI module and checks that the core still works.

The Qt V4 command was:

```bash
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
```

The supplemental static lint command was:

```bash
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml shell/components/AppContinuity.qml shell/components/Bezel.qml shell/components/Instrumentation.qml shell/core/Theme.qml shell/modules/deck/DeckView.qml shell/modules/ground/Ground.qml shell/modules/strip/FlightStrip.qml'
```

All used configs and the valid visual-capture routine fixture are copied into [runs/configs](runs/configs). The original required fixture intentionally contains `broken-example`; its one routine warning and `CFG 1` are expected in required-scenario screenshots.

For compact capture checks, `RES=1280x720`, `CONFIG="build/ui012/$intensity-$motion-small.json"`, `AUDIO=1 AI=1`, and `ROUTINES=build/ui012/valid-routines.json` were passed to [accessibility.sh](scripts/accessibility.sh). Each run asserts successful typed `vol 45`, no config/routine errors, focused workspace 2, and the literal active title `<b>Literal & untrusted</b>`. `motion` is `reduced` or `off`; both use uiScale 1.25 and Noto Sans/Noto Sans Mono, while off also enables lowEffects. These checks use final2 output directories.

## Motion evidence and fixture corrections

[motion.sh](scripts/motion.sh) captures actual QML frames around window focus, Deck opening, bay replacement, and closing. It uses explicit mock windows and the existing Navigator refresh contract, not live application discovery. It asserts the creative window's literal title and focused workspace around the handoff. Frame timestamps and trigger timestamps are retained with the screenshots.

Self-review of the capture evidence found two fixture problems: mock-open does not focus the new app, and a newly introduced workspace 4 could show honest `N/A` until a later snapshot refresh. Compact captures now explicitly refresh and focus the Firefox window. Motion captures use seeded workspace 3 for the creative window and assert the focused workspace before the trigger and after the handoff. This changes only the test fixture. The production presentation and systems services were not changed to mask unavailable state. Final motion uses final3 outputs; the earlier final/final2 motion renders are superseded.

## Performance

Four frozen-source, default-length `tests/scenarios/perf.sh` measurements were recovered intact from the interrupted run. Each contains 120 seconds of initial idle, 30 seconds of Systems Bay use, 30 seconds of Command Core use, and 30 seconds idle after use. Initial idle remains below the approximately 0.14% of one core target.

| Direction / intensity | Initial idle CPU | Idle after use CPU | Initial / after-use RSS | Peak RSS |
|---|---:|---:|---:|---:|
| THEARS / Saturated | 0.11% | 0.13% | 125.0 / 128.3 MiB | 180.2 MiB |
| THEARS / Insane | 0.11% | 0.13% | 125.7 / 129.6 MiB | 203.5 MiB |
| PIYTI / Saturated | 0.10% | 0.13% | 124.8 / 127.5 MiB | 199.5 MiB |
| PIYTI / Insane | 0.10% | 0.10% | 125.1 / 143.9 MiB | 179.4 MiB |

Initial idle context switches are 1.6–1.8/s; after-use idle is 1.9–2.3/s. Command Core consumes 0.17–0.20% of one core; the actively sampling Systems Bay consumes 2.83–3.03%. These are software-renderer measurements of the Quickshell process, not compositor or GPU measurements.

The four complete JSON files were written after all measurement states and the scenario's final alive check; interruption lost the outer wrapper's exit/completion output. Short confirmations use the same `perf.sh` through [perf-confirm.sh](runs/configs/perf-confirm.sh), setting 30/10-second measurement windows. Both exited 0: THEARS measured 0.13% initial idle and 0.10% after use; PIYTI measured 0.10% and 0.20%. The 10-second after-use measurements contain one and two CPU ticks respectively, so their resolution is 0.10 percentage points; the longer primary windows above provide the steadier comparison. Earlier UI-012 performance runs against changing live source were contaminated by hot reload and are excluded.

```bash
SHELL_PATH="build/ui012/$direction-final-shell" \
CONFIG=build/ui012/saturated-full.json AUDIO=1 MEDIA=1 MPV_AO=pipewire \
tools/headless/run.sh build/ui012/perf-confirm.sh \
  "build/ui012/confirm-$direction-saturated-perf"
```

## Runtime log audit and limits

All 34 final scenario/performance `qs.log` files were read and scanned for `TypeError`, `ReferenceError`, `Unable to assign`, binding loops, syntax errors, and invalid assignment: **0 matches, 0 fatal/crash messages**. [log-audit.json](log-audit.json) records the exact scan and retained log paths. Expected non-QML messages are the headless compositor's absent Hyprland shortcut/toplevel protocols, absent UPower/system D-Bus and RTKit, Qt/sway text-input focus warnings, the intentional invalid-routine fixture, and the four deliberately failed saves in Deck's rollback test. A PipeWire connection error can appear during container teardown. `mpv stream not linked` is a harness limitation; no media-routing success is inferred from it.

Three simultaneously started resumed containers initially failed before `Configuration Loaded`, with Wayland `Connection refused`. This is consistent with the harness's five-second compositor readiness wait under concurrent startup and lint load. Those attempts are retained in [startup-retries](logs/startup-retries); the same required scenarios passed sequentially without any source edit.

Headless sway uses pixman and `QT_QUICK_BACKEND=software`; Hyprland IPC is a protocol mock. Global compositor shortcuts, physical GPU behavior, true app launch/focus identity, and fullscreen VRAM release are unverified here. The near-zero VRAM contract is a systems request, not an achieved measurement. Native-app and theme-format evidence is documented separately in the design README.
