# UI-009 verification

Production matches the immutable `build/ui009/verified-shell` snapshot byte for
byte. [Contract hashes](contracts.json), [before/after source hashes](source-after.json)
and the [visual patch](visual-changes.patch) record the change. Git was used
read-only by Astra; the external overnight save (7486188) appeared during the
interruption. No Git write was performed by this task.

## Unit checks

| Exact command | Result |
| --- | --- |
| `node tests/js/run-node.mjs` | 104 passed, 0 failed |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 104 passed, 0 failed in Qt V4 |
| `python3 -m pytest -q tests/py` | 71 passed, 1 skipped |
| `git diff --check` | passed |

Full output: [Node](node-tests.txt), [Qt](qt-tests.txt), [Python](python-tests.txt).

## Required scenarios

All twelve runs pass against the final snapshot. Each command is
`tools/headless/run.sh tests/scenarios/<scenario>.sh build/ui009/<run>` with
`SHELL_PATH=build/ui009/verified-shell` and `CONFIG=build/ui009/<intensity>-full.json`.
The exact environment, accepted run and result for every cell are in
[scenarios.json](scenarios.json); raw command output is in [runs/](runs/).

| Scenario | Additional environment | Saturated | Insane |
| --- | --- | --- | --- |
| smoke | none | verified-saturated-smoke: pass | verified-insane-smoke: pass |
| full | `AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json` | verified-saturated-full: pass | verified-insane-full: pass |
| signal | same audio/media/routines environment | verified-saturated-signal: pass | verified-insane-signal: pass |
| deck | `AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1"` | verified-saturated-deck: pass | retry-insane-deck: pass |
| notify | `CONFIG=build/ui009/notify-<intensity>.json` | verified-saturated-notify: pass | retry-insane-notify: pass |
| ai | `AI=1 AUDIO=1` | retry-saturated-ai: pass | retry-insane-ai: pass |

Signal explicitly skips stream routing because mpv is unlinked in the headless
PipeWire graph. It verifies that a refused default switch is reported as a
failure, not a false success; media controls and mute pass. Deck verifies
immediate demand release, rapid switching, early keyboard input, scaled/rotated
logical geometry, notices and config-save failure recovery. AI verifies explicit
requests, per-action approval, no unapproved execution and module removal.

## Layout, motion and integration

The `gallery.sh` script captures actual first-boot frames, Ground and all eight
bays, scope navigation, scrolled registers and notices. It passes for both
intensities at full motion (1920×1080), reduced motion, and 1280×720/uiScale 1.5
with Noto fallback, motion off and lowEffects. Accepted final galleries are
`verified-gallery-saturated-full`, `verified-gallery-saturated-small`,
`resume-gallery-saturated-reduced`, and `resume-gallery-insane-{full,small,reduced}`.
[Before/after index](../README.md), [capture provenance](../captures.json).

The observer-only copied root and `probe.sh` pass in all six intensity/motion
combinations. Startup now waits for configuration: Saturated latches 2080 ms;
Insane latches 2600 ms. Full motion reports 93/67 finite progress events;
reduced and off/lowEffects report **zero** in both intensities. All remain at
progress 1 without replay after intensity switches, unmap/remap and motion or
lowEffects changes. A typed draft survives intensity changes. [Startup data](startup.json).

`build/ui008/compact.sh` passes at 720p/1.5 in both intensities, covering choice,
range, text draft/cancel, long selected description and last setting. The event
fixture passes with notifications enabled in both intensities, showing sharing,
multiple outputs, DND, literal notices, empty results and Help paging. AI's
required approval scenario also passes at 720p/1.5 in both; long literal replies,
last-proposal scrolling, dismissal, cancellation and authentication errors pass
through `build/ui006/ai-states.sh`.

The existing `prototypes/views/capture.sh` passes lock input clearing/retry,
blocked input, session confirmation/cancel/unavailable actions, and OSD exit
settlement in full, reduced, off and lowEffects. Extra `views.sh` captures both
intensities at 720p/1.5, including long literal messages. These are ordinary
window previews of production views, not a secure locker or system-action host.

Real foot launches pass in both intensities through
`build/ui008/tabs-capture.sh`, including Tab/Shift+Tab, Ctrl+3, Ctrl+7 and F1.
The unchanged kitty, Alacritty, foot, btop and Hyprland fragments share the
existing palette and rounding rules. Only foot rendering was exercised here;
other native application rendering and installer integration remain unverified.
Earlier successful view/terminal/long-AI checks were retained after the
startup-only correction; their presentation and action code did not change.

## Idle cost and log audit

Exact final performance commands:

```bash
SHELL_PATH=build/ui009/verified-shell CONFIG=build/ui009/saturated-full.json AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/ui009/verified-saturated-perf
SHELL_PATH=build/ui009/verified-shell CONFIG=build/ui009/insane-full.json AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/ui009/retry-insane-perf
```

Each uses 120 seconds of initial idle and 30 seconds in each subsequent state.
Renderer: Qt software / sway pixman, four available CPUs. Percentages are of
**one** core. No GPU/VRAM measurement is inferred.

| Measurement | Before / Saturated | Final Saturated | Final Insane |
| --- | ---: | ---: | ---: |
| Initial idle CPU | 0.25% | 0.24% | 0.26% |
| Idle after use CPU | 0.23% | 0.23% | 0.23% |
| Initial idle context switches/s | 5.0 | 7.4 | 6.0 |
| Idle after use context switches/s | 6.8 | 4.6 | 6.1 |
| Initial idle RSS, MiB | 121.1 | 123.1 | 123.0 |
| Idle after use RSS, MiB | 128.5 | 126.7 | 126.7 |
| Peak RSS, MiB | 181.4 | 184.1 | 183.6 |

Idle stays near zero. Peak RSS grows by less than 3 MiB. These are observations,
not a statistically established improvement. Raw data: [baseline](perf-baseline.json),
[Saturated](perf-saturated.json), [Insane](perf-insane.json).

All 91 `qs.log` files (3370 lines), including exploratory,
interrupted and failed runs, were read. [Audit](log-audit.json), [raw logs](logs/).
Accepted final runs have no QML parse/type/reference/assignment/binding-loop
regression. Known diagnostics cover absent UPower/RTKit/system bus, unsupported
Hyprland protocols on sway, Wayland focus events, intentionally absent audio,
invalid routine fixtures and the Deck's deliberate save-failure test.

Exploratory failures remain visible: the old-shell/current-AI dependency mix
is corrected by matching baseline snapshots; the initial notice capture used
unsupported parameters and was corrected; early DND captures lacked an enabled
notification server and were repeated with the correct fixture; an early probe
lost a draft under concurrent load. The startup probe exposed and verified the
configuration race fix. Interrupted runners were resumed only where completion
was missing. Resumed concurrent AI/audio and Wayland startup failures were
retried in isolation; all accepted final scenarios and performance runs pass.

## Scope and one systems review

All hosts, services, config.mjs, schema, tokens/palette and the entire FlightStrip
are unchanged, as is SettingsBay after its external UI-008 patch landed.
Systems/Signal/Routines/Help behaviour prefixes and the AI systems, timer and
key-handling prefix are byte-identical. No timer, sampling demand, shader,
blur or looping animation was added. [Evidence](contracts.json).

Two actionable findings for Claude, with one revision available:

- **P2 — mixed snapshot dependencies.** `tools/headless/session.sh:116` always
  installs the current AI module even when `SHELL_PATH` points to an older
  frozen shell. `before-insane-small` consequently logs `ScrollMark is not a
  type`. Minimal correction: allow a matching AI-module snapshot path, retaining
  the current path as default. For accurate before captures, the build-only
  baseline wrapper seeds the saved old AiModule; corrected baseline runs pass.
- **P2 — startup readiness.** `tools/headless/session.sh` tests socket presence
  and fixed audio delays. `resume-insane-perf` fails before QML starts with
  `Failed to create wl_display (Connection refused)`; `resume-saturated-ai`
  has no default audio sink. Minimal correction: confirm a compositor round
  trip and a usable default audio node before launching dependent scenarios.
  Isolated retries pass; no production changes were made for these failures.

Real Hyprland/GPU rendering, fullscreen/game VRAM release, PAM authentication
and live session/audio/backlight hosts remain systems integration checks.
Software rendering cannot establish GPU-memory behaviour. No agent dispatcher
was invoked or claimed.
