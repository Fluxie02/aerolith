# UI-017 — AEROLITH redesign, round 1

Implemented in the assigned worktree, based on `5bd2715`. Source of truth:
[the owner's interview](../OWNER-BRIEF-2026-10.md). No commit made.

| Brief item | Change and design rationale |
|---|---|
| 1. Clean desktop | Removed angular/edge scale numbers and split PIY TI / THE ARS title. Reduced and separated the wing from the main annulus and station targets. Bottom bar is one 48-unit row, with space above a bottom-mounted strip. |
| 2. Live wing | The bounded wing rotates as one object toward the actual active station, using a finite eased RotationAnimator. Reduced/off motion holds a fixed heading. Existing ambient hold, exposure, focus and material policies remain. |
| 3. Working ring | Active station has a filled face; occupied stations show a window count; empty stations say EMPTY. Clicks use existing `workspace.focus` with recording disabled. Shader and retained index point at the same station. Small logical screens retain stations along a lower chord. |
| 4. Now playing | New `NowPlaying.qml` presents title, artist, bounded cover art, play/pause and Next through Media/MPRIS and Registry. Unsupported controls are disabled; no player leaves one quiet label. Untrusted metadata stays plain text. |
| 5. App bar | Running apps first, then installed desktop entries; native app icons when resolvable and a readable fallback otherwise. Width caps the visible list; All Apps always opens search. Existing appbus focus/cycle/launch/search behavior stays. `rankedEntries` is the presentation slot for Sol's combined list. |
| 6. Labels | YOUR WORKSPACE, CPU CORES, OPEN WINDOWS, SEARCH, WINDOWS and SYSTEM MONITOR replace the touched decorative/internal labels. |
| 7. Motion | Workspace heading, occupancy, focus, CPU, memory, clock and media use existing data. Existing small retained ambient bearings and wing tension remain. Workspace switches no longer repaint the full-screen static InstrumentField Canvas. No new sampling timer or service. |
| 8. Deck | Rail shows Search & launch, Window overview and System monitor. Settings has a gear; F1 opens Help. Signal, Routines and optional AI retain their commands, shortcuts and modules. Deck host/state machine is unchanged. |

| Capture | Before | After |
|---|---|---|
| 1920×1080, scale 1 | [Before](before-1920.jpg) | [After](after-1920.jpg) |
| 2560×1440, scale 1 | [Before](before-2560.jpg) | [After](after-2560.jpg) |
| 3840×2160, scale 1.5 (2560×1440 logical) | [Before](before-3840.jpg) | [After](after-3840.jpg) |

Also judged: [cover and controls](media-cover.jpg), [paused](media-paused.jpg),
[workspace 05](workspace-05.jpg), [Deck](deck.jpg), [THEARS](thears.jpg),
[4K media](media-3840.jpg), [720p / UI scale 1.5 / Noto / low effects](compact.jpg),
[compact Deck](compact-deck.jpg), [all 12 schemes × both intensities](schemes.jpg).
JPEGs are 72–216 KB; [evidence.json](evidence.json) retains native capture dimensions.
[Reduced 05](reduced-workspace-05.jpg) and [reduced 01](reduced-workspace-01.jpg)
have pixel-identical wing crops across workspace changes.

Validation ran one headless scenario at a time, using the existing `aerolith-dev`
image. Container configuration and processes were disposable; no host setup changed.

| Check | Result |
|---|---|
| Node | 155 passed, 0 failed — [output](checks/node.txt) |
| Qt V4/offscreen | 155 passed, 0 failed — [output](checks/qt.txt) |
| Python | 260 passed, 1 skipped — [output](checks/python.txt) |
| smoke | PASS |
| full, audio/media/routines | PASS |
| deck, scaled/rotated mock | PASS |
| app-links | PASS: focus, repeat-click cycle, installed launch, All Apps search, window-row focus |
| fullscreen | PASS: 20 release/restore cycles; RSS 163932 → 167752 → 170064 KiB, sustained-growth gate false |
| direction | PASS: both startup directions, reload immutability, invalid/missing metadata fallback |
| notify | PASS |
| visual fixture | PASS at all three requested sizes and compact size; cover, Pause/Next delivery, empty-workspace click, F1, reduced/off motion |
| palette matrix | PASS: 24 combinations plus reduced/off views |
| THEARS views | PASS; explicit teardown warning findings described below |
| syntax / whitespace | Python fixture compilation, bash syntax and `git diff --check` pass |

Commands (repository root; full output directories remain under `build/redesign-1`):

```bash
node tests/js/run-node.mjs
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
python3 -m pytest -q tests/py
RES=1920x1080 SCALE=1 MEDIA=1 tools/headless/run.sh tests/scenarios/smoke.sh build/redesign-1/smoke
AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh tests/scenarios/full.sh build/redesign-1/full
AUDIO=1 HYPR_MOCK_ARGS='--mode 2560x1440 --scale 1.5 --transform 1' \
  tools/headless/run.sh tests/scenarios/deck.sh build/redesign-1/deck
tools/headless/run.sh tests/scenarios/app-links.sh build/redesign-1/app-links
AUDIO=1 tools/headless/run.sh tests/scenarios/fullscreen.sh build/redesign-1/fullscreen
tools/headless/run.sh tests/scenarios/direction.sh build/redesign-1/direction
CONFIG=tests/fixtures/notify-config.json \
  tools/headless/run.sh tests/scenarios/notify.sh build/redesign-1/notify
```

Before captures use the unmodified source archived within this worktree:

```bash
mkdir -p build/redesign-1/baseline
git archive 5bd2715 shell | tar -x -C build/redesign-1/baseline
# Run each command separately, with SIZE/MODE/SCALE respectively:
# 1080 / 1920x1080 / 1; 1440 / 2560x1440 / 1; 4k / 3840x2160 / 1.5.
SHELL_PATH=build/redesign-1/baseline/shell RES="$MODE" SCALE="$SCALE" \
  HYPR_MOCK_ARGS="--mode $MODE --scale $SCALE" \
  tools/headless/run.sh docs/design/redesign-1/scripts/capture.sh build/redesign-1/before-"$SIZE"
RES="$MODE" SCALE="$SCALE" HYPR_MOCK_ARGS="--mode $MODE --scale $SCALE" \
  tools/headless/run.sh docs/design/redesign-1/scripts/visuals.sh build/redesign-1/after-"$SIZE"
CONFIG=docs/design/redesign-1/scripts/compact.json RES=1280x720 SCALE=1 \
  HYPR_MOCK_ARGS='--mode 1280x720' \
  tools/headless/run.sh docs/design/redesign-1/scripts/visuals.sh build/redesign-1/compact
tools/headless/run.sh docs/design/redesign-1/scripts/schemes.sh build/redesign-1/schemes
tools/headless/run.sh docs/design/redesign-1/scripts/thears.sh build/redesign-1/thears
python3 docs/design/redesign-1/scripts/archive.py
python3 -m py_compile docs/design/redesign-1/scripts/*.py
bash -n docs/design/redesign-1/scripts/*.sh tests/scenarios/app-links.sh
git diff --check
```

The app-links scenario supplies deterministic desktop-entry fixtures in its
throwaway user directory, replacing coordinates tied to the old fixed five.
The missing-app search branch remains covered by existing appbus unit tests.
The media fixture initially lacked the separate Pause method used by Quickshell;
it was corrected and the final visual runs pass.

Files changed: `shell/components/{AppContinuity,InstrumentField,Instrumentation,
ShearField,WorkspaceOrbit}.qml`, new `shell/components/NowPlaying.qml`,
`shell/modules/deck/DeckView.qml`, `tests/scenarios/app-links.sh`, and this evidence
directory. Inspected and retained `Counterphase.qml`, `Media.qml`, `Apps.qml`,
`appbus.mjs` and `Deck.qml`.

Follow-up needs:

- **Sol:** one ordered combined list of running + most-used applications on Apps,
  with desktop-entry-compatible `id`, `name`, `icon` (suggested service property:
  `Apps.rankedEntries`). Bind it to
  `AppContinuity.rankedEntries`; include window-only apps with stable identity/icon
  resolution. Current fallback is functional and deliberately does not rank usage.
- **Opus:** review bounded wing transforms, art cache invalidation, coverage hold
  and fullscreen restore on real Hyprland/NVIDIA. Headless sway uses software
  rendering; GPU cost, HDR and physical pointing devices remain unverified.
- **Later round, Sol:** network connection/status/actions, Bluetooth device/status/
  actions, and persisted tour progress. Needed UI fields: network kind, connection name/state,
  known signal level and selectable connections; Bluetooth adapter power/state
  and device name/connection state; tour current step/completion and durable
  dismiss/complete actions. Expose connection/power actions through Registry.
  No invented data or inactive controls were
  added for these deferred features.
- **Low, systems review finding:** explicit process teardown in the THEARS capture
  logged four undefined-to-string/bool assignments after the IPC exit line, in
  `Compositor.qml:49`, `Theme.qml:146`, `ShellState.qml:35–36`. The restarted THEARS
  view works. Minimal proposed correction: guard teardown-time dependency reads
  and coerce the exposed string/bool bindings, preserving surface-release order.
  Evidence and baseline comparison follow below. These files remain untouched.

The shared hub named UI-016/Claude at entry and already reserved UI-017 for Astra.
The owner's explicit isolated-worktree assignment was recorded before edits.
Reviewed Claude's `5bd2715` coverage/slack change once: its tiling-gap behavior and
real-gap resumption have test coverage; no actionable visual issue found there.
The separate teardown finding above is submitted for one systems revision.

Matched software-rendering comparison (`AUDIO=1 MEDIA=1`, 15-second warm-up,
30-second first idle, 10 seconds per subsequent state):

| State | Before CPU (one core) | After CPU | Before RSS MiB | After RSS MiB |
|---|---:|---:|---:|---:|
| idle-strip | 1.27% | 0.87% | 127.4 | 129.2 |
| systems-bay-open | 3.89% | 3.69% | 172.9 | 173.3 |
| command-core-open | 1.6% | 1.2% | 169.2 | 169.7 |
| idle-after-use | 1.2% | 1.0% | 131.8 | 133.8 |

Peak RSS: 210.9 → 201.6 MiB. Both runs passed. This is a short
regression comparison, not evidence of GPU/VRAM cost or a long-run leak test.
Raw [before](checks/perf-before.json) and [after](checks/perf-after.json).

```bash
SHELL_PATH=build/redesign-1/baseline/shell AUDIO=1 MEDIA=1 \
  tools/headless/run.sh docs/design/redesign-1/scripts/perf-short.sh build/redesign-1/perf-before
AUDIO=1 MEDIA=1 \
  tools/headless/run.sh docs/design/redesign-1/scripts/perf-short.sh build/redesign-1/perf-after
```

Final QML audit: **26 logs, zero matched errors** across the required scenarios,
visuals, palettes, settled THEARS restart, baseline early exit and performance
runs. [Audit](checks/qml-errors.json). The earlier restart's four warnings are
retained in [thears-early-exit.txt](checks/thears-early-exit.txt). That first
fixture exited immediately after Configuration Loaded, before the shell settled.
A baseline early exit did not reproduce them ([log](checks/early-exit-before.txt));
a settled restart of the redesigned shell also did not reproduce them
([running log](checks/thears-running.txt)). Cause is unconfirmed; this remains a
low-severity intermittent startup/teardown finding for systems review, rather
than a reproduced steady-state failure.

```bash
SHELL_PATH=build/redesign-1/baseline/shell \
  tools/headless/run.sh docs/design/redesign-1/scripts/early-exit.sh build/redesign-1/early-exit-before
```
