# P2-TERRA — geometry, measured tour anchors and workspace set

## P2-TERRA-FIX — follow-up verification, 5 November 2026

All seven requested checks now pass in this worktree. No production shell or
visual design files changed, and no commit made. The original blocked attempt
is retained below as history; its Docker blocker no longer applies.

### Causes and changes

- `tests/scenarios/tour-probe.py:50`, private `target()` fixture: the previous
  `item.parent.x += 13` writes to a Hatch ancestor positioned by `anchors.fill`
  (`shell/components/InstrumentField.qml:158`). The original assertion correctly
  rejected a move that never happened; identical rects were evidence of that
  no-op, not a rounding failure. Opposite left/right margins now translate the
  ancestor without changing its size. The private reveal action is named
  `reveal`: passing `show` made qs print the IPC function signature instead of
  invoking it.
- `tests/scenarios/tour.sh:83`, `anchor_check()` / `wait_anchor()`: compare
  x/y/width/height with absolute tolerance 0.5 logical pixels, relative tolerance
  zero, between Tour's target, its rendered highlight, the registered anchor,
  and the independently mapped real target bounds. Mutation waits also require
  the expected translation/scale, so agreement between stale rectangles cannot
  pass. Restoration compares scalar geometry with the same tolerance.
- `docs/design/network-tour/ui-input.sh:3`, `ui_is()`: put the evaluation
  namespace in globals. Nested Python comprehensions could not resolve `s`
  from eval's locals, causing a suppressed NameError on the true hide assertion.
- `tools/mock-hyprland/mock_hyprland.py:394`, `open_window()`: announce a newly
  created workspace with `createworkspace` and `createworkspacev2` before
  `openwindow`, as the existing focus/move paths do. Previously workspace 33
  existed in mock state but Quickshell's workspace model was never told of its
  creation. The shell and multimonitor assertions need no change.
- `tests/py/test_mock_hyprland.py:50`: regression covers event order, unfocused
  workspace membership/occupancy, and no duplicate creation on a second open.

### Observed probe data

Opus's supplied multimonitor log has exactly **one** workspace view on each of
the two Grounds and two strips. All contain ids 1–5 with window counts
`[1, 2, 1, 0, 0]`; none contains 33. After the mock fix,
`build/p2-terra-fix/multimonitor/higher-workspace.json` still reports one view
per surface, with ids **1–33** on all four. Window counts are 1 on id 1, 2 on
id 2, 1 on id 3, zero on ids 4–32, and **1 on id 33**. Each ring has stations
1, 2, 3, 4 and an overflow station containing **5–33**. The original assertions
at `tests/scenarios/multimonitor.sh:109` and `:110` pass unchanged.

At 1080p, saved hatch snapshots show x=960 initially, x=973 after moving,
width=345.6 initially and width=311.04 after scaling by 0.9; restoration returns
to x=960. All three tour variants verify all five targets, hide/reveal,
fullscreen remapping, keyboard focus/persistence, and the actual overflow action.
An ad hoc Python replay of the extracted assertions passed six checks: valid
move accepted, original no-op move rejected, highlight displaced by 1 pixel
rejected, actual target displaced by 1 pixel rejected, true/false nested
comprehensions accepted/rejected respectively. Evidence: `probe-regression.log`.

### Commands and results

Commands ran from this worktree, one scenario at a time, followed by Node.
Scenario stdout/stderr went to `build/p2-terra-fix/<variant>.log`; snapshots and
QML logs are in the corresponding `<variant>/` directory. The bottom fixture
was created with `printf '%s\n' '{"strip":{"edge":"bottom"}}' >build/p2-terra-fix/bottom-config.json`.

| Command | Result |
| --- | --- |
| `docker info --format '{{.ServerVersion}}'` | Exit 0; 29.9.1 |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/p2-terra-fix/tour` | Exit 0; tour: ok |
| `TOUR=1 RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/tour.sh build/p2-terra-fix/tour-4k` | Exit 0; tour: ok |
| `TOUR=1 CONFIG=build/p2-terra-fix/bottom-config.json tools/headless/run.sh tests/scenarios/tour.sh build/p2-terra-fix/tour-bottom` | Exit 0; tour: ok |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/p2-terra-fix/multimonitor` | Exit 0; multimonitor: ok |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/p2-terra-fix/smoke` | Exit 0; smoke: ok |
| `tools/headless/run.sh tests/scenarios/app-links.sh build/p2-terra-fix/app-links` | Exit 0; app-links: ok |
| `node tests/js/run-node.mjs` | Exit 0; 268 passed, 0 failed, including anchors 7/7 and geometry 6/6 |
| `python3 -m pytest -q tests/py/test_mock_hyprland.py` | Exit 0; 3 passed |
| `bash -n tests/scenarios/tour.sh tests/scenarios/multimonitor.sh docs/design/network-tour/ui-input.sh` | Exit 0 |
| `python3 -m py_compile tests/scenarios/tour-probe.py tools/mock-hyprland/mock_hyprland.py` | Exit 0 |
| `git diff --check` | Exit 0 |

The original 1080p failure was reproduced before editing (exit 1,
`tour-before.log`). Intermediate corrected runs exposed the eval scope and
`show` argument bugs above; the final three variants all pass.

### Scope, coordination and remaining limits

Reviewed all requested shell paths, including `AnchorTarget.publish()`, the
scalar registry, `TourHost.target`, and the shared ring/tape workspace bindings;
the harness results require no production change. One peer review of the merged
suite registration (`f8ea2ec`, `tests/js/index.mjs`) found no actionable issue:
both default exports are registered once, and Node executes their 13 tests.

The shared state is Claude_Performance_Audit, owner Claude; the explicit
P2-TERRA-FIX assignment uses Opus's matching Claude-held reservation despite the
older top-level workflow task id. Additional fixture/mock/test/evidence locks
were acquired as Terra. Completion is published as Terra; only Terra's extra
locks are released, leaving Opus's reservation for Opus.

Docker was already running and was only used, never started/stopped/cleaned.
No host configuration, secrets, global packages or files outside this worktree
were accessed or edited, apart from the requested main-checkout logs and sync
hub operations. Opus supplied byte-identical Ground pixel results at 1080p and
4K x1.5; those comparisons were **not rerun** in this fix. Real Hyprland/GPU
rendering remains outside this software-rendered headless verification.

## Original implementation report (historical)

5 November 2026. The initial implementation attempt was blocked on Docker.

## Implementation

- `shell/lib/geometry.mjs:3` — `ground()` owns the ring centre/radii, hatch
  rectangle/aperture offset, app-bar rectangle and existing compact threshold.
  `station():22` preserves the original station equations and `Theme.du()`
  rounding. The six Ground components below consume this source.
- `shell/core/AnchorTarget.qml:30` — maps its bounds into its own window's
  `contentItem`. `publish():34` submits only scalar geometry plus the explicitly
  supplied output-relative surface origin. Ancestor geometry/visibility/opacity,
  window visibility and output changes are observed through Connections and
  bindings. No production polling or timers added.
- `shell/core/Anchors.qml:10` and `shell/lib/anchors.mjs:5` — per-output/name
  leases; generation checks reject old Loader updates and destruction. The
  singleton stores no Item references. Observer connections die with their
  target. Hidden targets have no rectangle. Inactive Deck instrument instances
  do not acquire Ground anchor names.
- `shell/components/WorkspaceOrbit.qml:23` — aggregates actual delegate bounds,
  then maps the bounding observer into the Ground surface. Hatch and apps
  register their actual entrance/bar bounds. FlightStrip registers the whole
  surface and actual search button. Ground origin is `(0,0)`; strip origin is
  `(0,0)` at the top and `(0, screen.height - strip.height)` at the bottom.
- `shell/modules/tour/TourHost.qml:24` — reads registered geometry and retains
  existing missing/hidden-target explanatory copy. No cross-window `mapToItem`.
- `shell/lib/geometry.mjs:54` and `shell/services/Compositor.qml:98` — one shared
  ordered workspace range, configured minimum through highest positive live id.
  The former strip cap of 30 is removed. Both ring and tape consume the same
  records. Special/negative ids are excluded.
- `geometry.mjs:36` retains the configured station slot budget/spacing. If the
  shared range exceeds it, the last slot represents all remaining workspace ids
  as `+N`. `WorkspaceOrbit.qml:93` opens Windows/Navigator for overflow; numeric
  stations keep numeric `workspace.focus` dispatch and existing keyboard actions.
  Further physical fit policy remains Astra's follow-up, as requested.
- `CircularField` remains unused (`rg -n 'CircularField' shell --glob '*.qml'`
  finds no instantiation); its legacy equations now also use the shared source.

No tokens, colours, fonts, animation parameters or existing default Ground
positions/sizes were changed. The requested overflow label and measured tour
highlight are the intended visible behavior changes. Pixel identity is unverified.

## Files changed

Production:

- `shell/lib/geometry.mjs`, `shell/lib/anchors.mjs`
- `shell/core/Anchors.qml`, `shell/core/AnchorTarget.qml`
- `shell/components/InstrumentField.qml`, `CircularField.qml`, `WorkspaceOrbit.qml`,
  `Hatch.qml`, `Instrumentation.qml`, `AppContinuity.qml`
- `shell/modules/strip/FlightStrip.qml`, `WorkspaceTape.qml`
- `shell/modules/tour/TourHost.qml`
- `shell/services/Compositor.qml`

Verification:

- `tests/js/geometry.test.mjs`, `tests/js/anchors.test.mjs`
- `tests/scenarios/tour.sh`, `tests/scenarios/tour-probe.py`
- `tests/scenarios/multimonitor.sh`, `tests/scenarios/ground-pixels.sh`
- `docs/verification/P2-TERRA.md`

`tests/js/index.mjs` and Sol's config transaction files are untouched.

## Checks executed

| Exact command | Result |
| --- | --- |
| `node tests/js/geometry.test.mjs` | Exit 0; 6 passed, 0 failed |
| `node tests/js/anchors.test.mjs` | Exit 0; 7 passed, 0 failed |
| `node tests/js/run-node.mjs` | Exit 0; 241 passed, 0 failed |
| `bash -n tests/scenarios/{ground-pixels,tour,multimonitor}.sh` | Exit 0 |
| `python3 -m py_compile tests/scenarios/tour-probe.py` | Exit 0 |
| `git diff --check` | Exit 0 |

Local logs: `build/p2-terra/{geometry,anchors,node}.log`. Fixture composition was
also exercised in a repository-local copy: the existing network/tour fixture
followed by `tour-probe.py` generated one search-button name and the expected
Ground/registry/overflow probes. This checks patch composition, **not QML types**.

The geometry suite compares the original equations exactly at 1920x1080,
2560x1440 logical (3840x2160 / 1.5), and 1280x720, with six density/scale units
and both strip edges. It also checks complete workspace representation and
unchanged retained station positions. Anchor tests cover generations, hidden
leases, removal, output/name isolation, bottom-origin conversion, invalid bounds
and immutable scalar copies.

The commands below were invoked exactly as shown, sequentially, and each was
retried once. Every invocation exited **1 before container startup**:

```bash
tools/headless/run.sh tests/scenarios/smoke.sh build/p2-terra/smoke
TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/p2-terra/tour
TOUR=1 RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/tour.sh build/p2-terra/tour-4k
TOUR=1 CONFIG=build/p2-terra/bottom-config.json tools/headless/run.sh tests/scenarios/tour.sh build/p2-terra/tour-bottom
tools/headless/run.sh tests/scenarios/app-links.sh build/p2-terra/app-links
tools/headless/run.sh tests/scenarios/scratch.sh build/p2-terra/scratch
OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/p2-terra/multimonitor
AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/p2-terra/oled
AUDIO=1 CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/fullscreen.sh build/p2-terra/fullscreen
```

`bottom-config.json` was generated locally with `{"strip":{"edge":"bottom"}}`.
Each retry log is `build/p2-terra/<scenario>-retry.log` and reports:
`Cannot connect to the Docker daemon at unix:///var/run/docker.sock.`

`docker info --format '{{.ServerVersion}}'` failed. Automatic approval review
rejected the requested `rm -f /var/run/docker.pid /var/run/docker.sock` cleanup
because `rm -f` commands are not permitted. Starting without cleanup did not
restore the daemon. A foreground `dockerd` attempt exited 1 with
`chmod /var/lib/docker: read-only file system`. No host configuration workaround,
package installation, reboot or shutdown was attempted.

## Pending Wayland/pixel evidence

`tour.sh` now independently measures actual targets on their own surfaces and
compares them with the registry and highlight, including rendered highlight
position after motion settles. It also exercises ancestor movement, target
scale/hide/show, explanatory text, all five steps and fullscreen surface remap.
`multimonitor.sh:108` creates a live workspace 33 and asserts it is represented
on both outputs' rings/overflow and tapes. Tour also invokes the actual overflow
station's `choose()` and checks that Navigator opens. These probes have **not run**.

A pre-edit shell snapshot exists locally at `build/p2-terra/before-shell`.
The following capture commands were also each attempted twice; all exited 1 on
the same daemon error, so no pixel comparison or differing-pixel count exists:

```bash
SHELL_PATH=build/p2-terra/before-shell tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-terra/pixels-before-1080
tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-terra/pixels-after-1080
SHELL_PATH=build/p2-terra/before-shell RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-terra/pixels-before-4k
RES=3840x2160 SCALE=1.5 tools/headless/run.sh tests/scenarios/ground-pixels.sh build/p2-terra/pixels-after-4k
```

The capture fixture freezes host-dependent telemetry identically in disposable
copies, turns motion off, hides the strip and saves raw `ground.ppm` plus PNG.
When Docker is available, compare each before/after PPM pair; identical raw bytes
prove identical pixels. Baseline snapshots and generated artifacts are ignored
by Git, so preserve/regenerate the reference tree before integrating this change.

QML type/signal validity, actual layer-shell origin conversion, output hotplug,
fullscreen cleanup, scaled/bottom tour geometry and real pixels remain risks
until the requested harness runs succeed. Existing physical fit constraints and
per-output workspace-focus policy were not redesigned here.

## Coordination and peer review

The shared top-level state was `Claude_Performance_Audit`, owner Claude.
The explicit owner assignment authorizes Terra's systems work under Opus's
Claude-held `P2-TERRA` reservation. Only additional helper/probe/evidence files
were separately locked as Terra. Sync events use Terra throughout. Terra's own
locks are released at completion; Opus's reservation is left for Opus to release.

One read-only review of the current `P2-SOL-A` worktree snapshot covered
`Config.qml` begin/apply/cancel/save callbacks, `config.mjs`
prepareBatch/mergeChanges/setPreviewValues and AppThemes' committed-only observer.
No actionable finding in that scope. No edits or claims to have executed Sol's
tests; later edits and independent-writer TOCTOU are outside this snapshot review.
