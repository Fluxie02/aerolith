# E01 / E02 — shallow material relief

Four bounded material programs and one shared QML interface implement the
existing [Counterphase requests](../counterphase/SHADER-REQUESTS.md).
The shapes, text hierarchy, click targets, functional bay surfaces and finite
motion stay native. This is a material refinement of PIYTI and the maintained
THEARS direction. No shader has a clock, texture sampler, blur, live-content
capture, layer effect, timer or animation of its own.

**Verification limit:** qsb compilation and the native fallbacks are verified.
The shader appearance, runtime pipeline compilation and GPU cost are **not
verified**. The container did not produce a working RHI output. These images
show native geometry, not the proposed shader appearance. E03/E04/B06's real
hardware gates remain open; optional shading does not supersede release
blocking systems work (roadmap rule 9).

Base revision: `9b60683e5b23779edf66741ccadbe11d4daf79dd`.
Astra made no commit; the bridge owns the worktree commit.

## Materials and design rationale

| Program / consumer | Purpose | Native fallback and motion |
| --- | --- | --- |
| `bevel.frag` / ShearField | Opposed directional values distinguish the leading skin, side bevel and dark toe. A short reflection uses appLink in PIYTI and signal in THEARS. Engraving and labels remain above the material. | Original opaque polygon faces, rules, tension strip and focus mark. Shader inherits the existing workspace rotation, focus displacement and startup assembly. No per-frame Canvas painting or shader uniform animation. |
| `annulus.frag` / WorkspaceOrbit | A narrow recessed inner lip and outer index edge give the workspace annulus depth. The center is fully transparent, preserving the numeral's uniform dark field. Signal registration matches InstrumentField's real workspace angle. | Original rings, index, occupancy teeth, workspace cards and actual focused-workspace arm. No sweep or invented occupancy. Changes remain compositor driven. |
| `catch.frag` / Counterphase | A short dark lip and light catch give the existing carriers thickness within their current rectangle. PIYTI's return path uses appLink. Reduced-mode light mixing is capped at .07. | Original carrier rectangles and rails. The tiny material travels as a child of the existing X/Y Animator; it never reads its position through a per-frame binding. Motion off/lowEffects are native and static. |
| `undercarriage.frag` / ChordSlot | Narrow right/bottom recesses explain separation between the rectangular working bay and its airframe. Only bg/surface2/grid are used; controls and tab labels receive no wash. | Original opaque undercarriage polygon and machining comb, or the existing lowEffects bay surface. Both strips inherit the bay's enter/exit/cross-bay transform and settle with it. |

OSD placement changes only the PanelWindow's anchor and margin: top center,
one Theme.pad below the top strip, or below the output edge with a bottom
strip. The application bus stays clear, as does the right-side notice lane.
The host's expiry, mapping, focus and input contracts are untouched.

## E02 interface

[`Material.qml`](../../../shell/components/Material.qml) is the only
ShaderEffect constructor. Every program includes
[`material.glsl`](../../../shell/shaders/material.glsl), which declares the
same std140 block. The component accepts a shader basename, four geometric
parameters, a semantic accent and a strength. Colours are never baked into
the shader sources.

| Shared input | Source / meaning |
| --- | --- |
| bg, surface, surface2, grid, text, textDim, signal, appLink, caution, critical, nominal | Existing Theme semantic roles |
| accent | appLink for PIYTI / signal for THEARS by default; a datum carrier can select its existing semantic colour |
| metrics.xy | Local logical extent, never full-output dimensions by default |
| metrics.z / metrics.w | Theme.unit (uiScale and density) / Screen.devicePixelRatio (output scale) |
| policy.x | Motion off = 0, reduced = 1, full = 2 |
| policy.y / policy.z | Saturated = 0 / Insane = 1; THEARS = 0 / PIYTI = 1 |
| policy.w | Theme.shaderQuality: 0 off, 1 standard; only one pass exists |

`Material.available` is the single selection gate. It requires a supported
RHI shader backend, quality above zero, normal effects, an exposed window,
nonzero geometry and no ambient suspension. It rejects software, unknown
and null rendering backends. A Loader destroys its ShaderEffect when the gate
closes. `Material.active` additionally requires **ShaderEffect.Compiled**;
native faces stay in place during compilation or a missing/broken package.
No offscreen target or retained texture is owned by the interface.

All instances are descendants of the existing Ground or Deck surfaces.
ShellState first holds ambient motion (which unloads these effects), then
destroys the surfaces. A user-summoned Deck during fullscreen uses native
geometry while the ambient hold remains set. No lifecycle code was changed.
This ordering is source-reviewed and exercised by the existing software
fullscreen test; GPU resource/cache release still needs hardware measurement.

The quality token is a visual seam, **not a new user setting**. Opus must
wire validated config/schema/CLI policy if required. Requests and the single
read-only systems review are in [SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md).

## Extents and cost limits

No new ShaderEffect is full-output sized:

* Each SHEAR face is `.135 × outputWidth` by `.52 × outputHeight`, before
  the existing rotation/scale; three faces in Saturated, five in Insane.
* Annulus relief is a square of side `.68 × outputHeight + Theme.du(8)`
  (about 742² logical pixels at 1080p/uiScale 1). The middle and corners
  output transparency. It exists only with the noncompact workspace orbit.
* Datum/return catches are only the original 42×5 or 24×5 and 8×24 design
  unit rectangles. Saturated has two datum carriers, Insane three; one return
  mark exists in both, travelling only in Insane as before.
* Each retained Deck slot has a 23-unit-wide right strip and a 19-unit-high
  bottom strip, clipped by their extents to the exposed undercarriage.

The existing full-output **nonrendering Items** (ShearField, Counterphase,
WorkspaceOrbit) and InstrumentField's full-output native Canvas remain.
Deck's existing background and instrument Canvas are also full-output.
ChordSlot's native carriage Canvas remains bay-sized plus its original
36×32-unit allowance. No new full-output render target is introduced.

Every shader is one analytical pass with no sampling or loops. Static
materials have no time input and cannot cause a new idle frame by themselves.
These facts bound the implementation; they do **not** establish real GPU
cost, memory consumption, direct scanout or frame pacing. The annulus still
shades a substantial bounding square, and Insane has five bevel passes:
measure those first on laptop hardware before approving E03.

## Evidence and reproduction

The baseline and modified captures cover PIYTI/THEARS × Saturated/Insane.
Each directory in [screenshots/fallback/](screenshots/fallback/) contains:

1. `01-idle`: settled native SHEAR, annulus and datum/vernier.
2. `02-workspace-motion` / `03-workspace-settled`: actual workspace 1→2.
3. `04-deck-motion` / `05-deck-docked`: Command entry and its undercarriage.
4. `06-bay-motion` / `07-bay-docked`: Command→Systems cross-bay transition.
5. `08-osd`: real PipeWire volume change; compare old and new placement.
6. `09-carrier`: later native carrier/rest state.

Open these first:

* PIYTI Insane [before OSD](screenshots/fallback/before-piyti-insane/08-osd.png)
  / [after OSD](screenshots/fallback/after-piyti-insane/08-osd.png).
* PIYTI Saturated [native idle](screenshots/fallback/after-piyti-saturated/01-idle.png)
  / [Deck docked](screenshots/fallback/after-piyti-saturated/05-deck-docked.png).
* THEARS Insane [native idle](screenshots/fallback/after-thears-insane/01-idle.png)
  / [Deck docked](screenshots/fallback/after-thears-insane/05-deck-docked.png).
* [720p / uiScale 1.5 / reduced / bottom strip OSD](verification/compact/08-osd.png).

These are independent process captures, not frame-locked comparisons.
Telemetry and ambient Animator phase differ. No image proves shader pixels
or high-refresh motion. `09-carrier` alone is not a motion measurement.
The reproducible finite-event capture script is
[verification/capture.sh](verification/capture.sh); [capture-all.sh](verification/capture-all.sh) recreates the profile configs and before/after copies from Git. Example:

```sh
AUDIO=1 CONFIG=build/E01/piyti-insane.json \
  tools/headless/run.sh build/E01/capture.sh build/E01/captures/after-piyti-insane
```

The four profile configs only set intensity and full motion; each direction
is selected in a disposable shell copy at the installation-only Theme seam.
Before copies came from the base revision; after copies contain this work.
No live direction control or production diagnostics were added.

## GPU-path attempt

The dev image has qsb and Mesa llvmpipe, but no DRM render node.
With QT_QUICK_BACKEND unset, LIBGL_ALWAYS_SOFTWARE=1,
WLR_RENDERER=gles2 and WLR_RENDERER_ALLOW_SOFTWARE=1, sway reports:
`Cannot create GLES2 renderer: no DRM FD available`.
See [sway.log](verification/sway.txt), [Qt log](verification/qs.txt) and the
[attempt script](verification/gpu-attempts/gpu-session.sh).

A second attempt retained the pixman compositor, unset QT_QUICK_BACKEND,
and requested Qt's OpenGL RHI with llvmpipe. The process started but produced
a [black output](verification/gpu-attempts/qt-over-pixman/gpu-probe.png),
with no working scene graph/pixel evidence. Its
[log](verification/gpu-attempts/qt-over-pixman/qs.txt) is retained.
Standalone minimalegl/eglfs surfaceless probes also terminated without a
usable output. None counts as shader visual verification. Because no GPU
path worked, the conditional SHADERS=1 switch was **not** added to run.sh
or session.sh; their defaults and contents are unchanged.

## Checks

All commands run from the worktree root; complete results are under
[verification/](verification/). The shader build/check and stale-include
negative check passed. The portable packages contain SPIR-V 100, GLSL
100es/120/150, HLSL 50 and MSL 12 (Qt qsb 6.12, QSB version 9).

```sh
docker run --rm -v "$PWD:/src" -w /src aerolith-dev tools/build-shaders.sh
docker run --rm -v "$PWD:/src:ro" -w /src aerolith-dev tools/build-shaders.sh --check
node tests/js/run-node.mjs
docker run --rm -v "$PWD:/src:ro" -w /src aerolith-dev bash -c \
  'QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
python3 -m pytest -q tests/py tools/agent-sync/tests
tools/headless/run.sh tests/scenarios/smoke.sh build/E01/smoke
AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh tests/scenarios/full.sh build/E01/full
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/E01/deck
CONFIG=tests/fixtures/notify-config.json \
  tools/headless/run.sh tests/scenarios/notify.sh build/E01/notify
AUDIO=1 BACKLIGHT=1 tools/headless/run.sh tests/scenarios/osd.sh build/E01/osd
AUDIO=1 CONFIG=tests/fixtures/notify-config.json \
  tools/headless/run.sh tests/scenarios/fullscreen.sh build/E01/fullscreen
tests/scenarios/notices-layout-matrix.sh build/E01/notices-matrix
D03_SHELL_SOURCE=build/E01/matrix-source \
  tests/scenarios/notices-layout-matrix.sh build/E01/matrix-compatible
bash -n tools/build-shaders.sh
git diff --check
```

Node and Qt V4: **135 passed each**. Pytest: **111 passed, 1 skipped**.
Smoke/full/deck/notify/osd/fullscreen: **pass**. OSD microphone coverage
skips because this harness has no default input. Fullscreen passed twenty
cycles; RSS at 1/10/20 was 143652/165764/161128 KiB and its sustained-growth
screen passed. This is not GPU memory evidence.

The default notice matrix **fails before launch** on its stale direction
seam assertion. The compatibility invocation uses an otherwise-current
disposable shell copy with the initial direction declaration adapted to the
runner; no scenario or production file is changed. Its final result and
paired idle measurements are recorded in [RESULTS.md](verification/RESULTS.md).

The intentional stale-input check changes the shared GLSL include in a
disposable copy; `--check` returns 1 and names all four stale packages.
See [build-check.txt](verification/build-check.txt). This checks actual
regeneration, including shared-include dependencies, rather than timestamps.

## Self-review and remaining work

The biggest implementation weakness found in self-review was treating
Loader.Ready as shader success: a missing/incompatible package could have
removed the native faces. The final interface keeps native geometry until
ShaderEffect.Compiled. The top-center OSD was also inspected at 1080p and
720p/uiScale 1.5 to confirm the bus clearance.

Shader appearance remains the largest verification gap. Do not approve it
from the native screenshots or infer GPU budgets from the CPU samples.
Opus/Sol must wire quality configuration, CI/package checking and perform
hardware visual, resource and pacing checks. The matrix runner correction
is separately requested with severity/evidence and a minimal fix in
[SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md).
