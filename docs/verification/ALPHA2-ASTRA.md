# ALPHA2-ASTRA — covered desktop motion and Canvas fonts

Patch delivered in `codex/design-4e54a249`. Runtime verification is blocked;
this document does **not** certify a measured rendering-cost improvement.
The task's excerpts of findings 6 and 9 are the report input. No redesign
work, host configuration change, package installation or commit was made.

## Changes and visual rationale

- `shell/core/Theme.qml`: `desktopCovered` reads the existing Compositor
  window and logical monitor geometry snapshots, and the selected monitor's
  active workspace. `ambientHeld` combines coverage with the existing
  fullscreen suspension flag. A requested Deck bypasses only coverage;
  fullscreen still wins. Closing, removing, moving or switching away from
  covering clients resumes ambient motion **when the snapshots update**.
  Motion off, reduced motion, low effects, and fullscreen release remain
  governed by their existing settings/lifecycle.
- `shell/lib/ambient.mjs`: testable rectangle-union coverage and Canvas
  family-list resolution. Coverage is exact over the work area below/above
  the strip, uses logical coordinates at fractional scale and rotation,
  and ignores hidden/unmapped clients, other workspaces and ordinary floating
  clients. Overlapping areas cannot conceal gaps. Visible tiling gaps keep
  motion available. A shown special workspace conservatively keeps it
  available too. This is geometric coverage, not per-pixel opacity detection.
- `shell/components/InstrumentField.qml` and `shell/components/ShearField.qml`:
  Canvas text uses the installed configured family plus a generic monospace
  fallback, resolved once in Theme (and on configured family changes).
  Family names are no longer enclosed in literal quotes. Missing configured
  fonts fall back to `monospace`. Colors, strokes, dimensions and text content
  are unchanged; actual Qt warning removal still needs a rendering run.
- `tests/js/ambient.test.mjs` and `tests/js/index.mjs`: ten tests covering
  tiled/maximized coverage, removal, overlap, horizontal/vertical gaps,
  named workspaces, hidden/unmapped/floating clients, logical scaled/rotated
  output coordinates, malformed input and font fallback/list handling.

Inspected `shell/components/Counterphase.qml` without changing it: carriers
already use small Rectangle items with X/YAnimators; ShearField's tension
stroke already has a separate Rectangle and OpacityAnimator. None of those
animators requests a construction Canvas repaint. Splitting them further
would not establish reduced full-output damage without renderer evidence.
The new shared ambient hold stops their existing finite animation groups
and low-frequency escapement timer through their existing guards.

`shell/services/Compositor.qml` was inspected and left unchanged: it is locked
by Claude under ALPHA2-SOL-B. The shared hub initially reported
`Astra_Design_Audit` / owner `Astra`. File locks were acquired under
`ALPHA2-ASTRA`, with `--agent Astra` and `--repo /home/user/aerolith`.

## Checks and measurements

Executed in the worktree:

| Command | Result |
| --- | --- |
| `node tests/js/run-node.mjs` | 154 passed, 0 failed (includes ten new tests) |
| `python3 -m pytest -q tests/py` | 260 passed, 1 skipped, 34.17 s |
| `git diff --check` | Passed |
| `docker image inspect aerolith-dev --format '{{.Id}}'` | Exit 1: Docker daemon unavailable |

Attempted the following **sequentially**, one scenario at a time. Each exited
1 before launching the shell with:

```text
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

```bash
RES=3840x2160 SCALE=1.5 HYPR_MOCK_ARGS='--mode 3840x2160 --scale 1.5' \
  tools/headless/run.sh tests/scenarios/smoke.sh build/alpha2-astra/smoke
AUDIO=1 HYPR_MOCK_ARGS='--mode 2560x1440 --scale 1.5 --transform 1' \
  tools/headless/run.sh tests/scenarios/deck.sh build/alpha2-astra/deck
tools/headless/run.sh tests/scenarios/fullscreen.sh build/alpha2-astra/fullscreen
AUDIO=1 MEDIA=1 RES=3840x2160 SCALE=1.5 \
  HYPR_MOCK_ARGS='--mode 3840x2160 --scale 1.5' \
  tools/headless/run.sh tests/scenarios/perf.sh build/alpha2-astra/perf
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
```

Attempt logs and Node output are in the ignored `build/alpha2-astra/` directory.
The host also has no `qs`, `quickshell`, `sway`, or `qml6` executable for a
native fallback. The Docker daemon was not started or reconfigured.

| Requested comparison | Before | After |
| --- | --- | --- |
| Shell CPU / wakeups on covered desktop | Unavailable | Unavailable |
| Bay-open RSS / peak RSS | Unavailable | Unavailable |
| Headless screenshots / QML warning count | Unavailable | Unavailable |
| Hardware GPU cost | Owner's ~9% report (task excerpt) | Unmeasured |

No baseline or after screenshots were produced. Unit tests establish the
coverage algorithm, not QML startup, animation cancellation, visual parity,
warning elimination or resource savings. Headless software measurements also
cannot establish GPU cost on the owner's RTX 4060 Ti.

## Cache assessment and remaining work

No new static-layer cache was introduced and no RSS saving is claimed.
`DeckView` and its construction Canvases already persist between ordinary bay
opens; remap/visibility handlers explicitly request paint. The image content
and scene-graph resources have different lifetimes, and the fullscreen
lifecycle destroys the whole visual tree. Removing the reconstruction hooks
without remap screenshots could reintroduce missing engraving. Retaining
additional image/texture copies could increase the reported RSS. Verify
Canvas.Image reuse on the target Qt renderer before changing these hooks.

Single systems review, recorded through agent-sync as well:

- **P2 — potentially stale geometry after resize/drag.**
  `shell/services/Compositor.qml:92` explicitly says that its geometry is the
  last IPC snapshot and callers must refresh when geometry matters.
  `shell/services/ShellState.qml:119` refreshes on focus/workspace/fullscreen,
  open/close and related events, but does not establish refresh after every
  arbitrary resize/drag. The visual hold can therefore lag an uncovering
  resize until a subsequent snapshot update. **Minimal correction:** Claude
  should establish and test a coalesced geometry invalidation/refresh at the
  end of window move/resize using a supported compositor signal, or expose a
  reliable coverage property to Theme. No per-frame or idle polling was added
  here. Main checkout had no uncommitted peer changes at review time.

Required follow-up in an environment with the dev image/daemon: run the above
checks, take baseline/after idle, covered, reopened-bay and remap screenshots,
count the Canvas font warnings across repeated bay opens, and measure equal
CPU/wakeup/RSS windows before/after. The existing `perf.sh` does not itself
create a geometrically covered desktop; the current mock tiles with visible
gaps and its maximized operation changes mode flags, not geometry. A targeted
coverage integration fixture must supply truly covering client rectangles,
then remove/resize one and assert `status.ambient` resumes. Include Deck over
coverage, fullscreen with Deck summoned, both intensities, missing configured
fonts, and 4K at scale 1.5. Repeat the GPU/RSS comparison on real hardware.
