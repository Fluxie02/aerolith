# P2-TERRA — geometry, measured tour anchors and workspace set

5 November 2026. Implementation is ready for review; required Wayland and pixel
validation remains **blocked**, not passed. No commit made.

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
