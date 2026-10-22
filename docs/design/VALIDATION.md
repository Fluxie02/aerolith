# UI-001 validation and limits

Astra · 22 October 2026. All paths are relative to `/home/user/aerolith-astra` unless noted. No production source files were modified. No push or branch switch was performed.

## Automated checks

| Exact command | Result |
|---|---|
| `node tests/js/run-node.mjs` | Exit 0; 100 passed, 0 failed. Tests unchanged production logic/tokens, not a certification of the new prototype palette. |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | Exit 0; 100 passed, 0 failed in Qt V4. |
| `python3 -m pytest -q tests/py` | Exit 0; 68 passed, 1 skipped in 10.60 s. |
| `AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/design-baseline` | Exit 0; full: ok. Screenshots inspected. |
| `SHELL_PATH=prototypes/interleaf AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/design-interleaf-full` | Exit 0; full: ok. Vol 40 verified against PipeWire; workspace 2 verified against mock; routine changes workspace to 3 and volume to 30%; telemetry 1000 ms open, 5000 ms closed. Screenshots inspected. |
| `SHELL_PATH=prototypes/interleaf RES=1280x720 CONFIG=prototypes/accessibility.json AUDIO=1 MEDIA=1 tools/headless/run.sh prototypes/check-layout.sh build/design-interleaf-small` | Exit 0; layout-and-keys: ok. Compact, Noto fonts, motion off, lowEffects. PNG inspected: top navigation, readable titles, scrollable index, fixed key hints. |
| `SHELL_PATH=prototypes/interleaf CONFIG=/tmp/aerolith-ui001-scale2.json AUDIO=1 MEDIA=1 tools/headless/run.sh prototypes/check-layout.sh build/design-interleaf-scale2` | Exit 0; layout-and-keys: ok. Same JSON as accessibility.json with theme.uiScale changed to 2. PNG inspected: content fits via scrolling at effective 960×540. This is uiScale, not compositor fractional scaling. |
| `git diff --check` | Exit 0 for tracked changes; new files also checked in the isolated commit index. |

The baseline and full prototype scenario use actual fixture services. The deliberately invalid `broken-example` routine remains an expected warning. Qt global-shortcut/toplevel-mapping protocol warnings, missing UPower system bus, RTKit realtime privilege messages and sway/wtype text-input focus messages are harness limitations already present in baseline. No final run logs contain TypeError, ReferenceError, Unable to assign or binding loops.

## Render commands and retained artifacts

Run for each `name` in `interleaf`, `parallax`, `cut`:

```bash
SHELL_PATH=prototypes/$name AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh prototypes/capture.sh build/design-$name-final
```

Each exited 0 with `design-shots: ok`. Inspected all six PNGs and read qs.log for each. Retained all six per concept in `docs/design/shots/<name>/`: 01-idle, 02-launcher, 03-overview, 04-active, 05-notice, 06-sound. Retained two baseline images, the small off/lowEffects comparison and a privacy check. The main screenshot set is 1920×1080, scale 1. Each output directory was unique; no stale PNG was reused.

The saved main images predate two non-visual behavior refinements: geometrical selection feedback is now gated on full motion, and Parallax/Cut keep keyboard selection in view while scrolling. The selected prototype's later full scenario and size checks exercised the final sources without QML errors. Full-scenario images show the current selected workspace after actual dispatches, rather than a staged static state.

The idle desktop is exposed behind mock window records; those records do not create real application surfaces. Working-state screenshots use a real foot process, its real README output, and scenario-only foot/sway colours. No Firefox, file manager or editor pixels were fabricated. The notice text is explicitly injected test content composed of real fixture titles; the ordinary success report is also visible. The Sound screenshots read actual Test Speakers/Test Headphones/Test Microphone, mpv and MPRIS AEROLITH Test Tone. PipeWire in this environment reports the mpv stream unlinked at capture; the design displays this accurately. A bound 0% is actual service state, not a fabricated unknown value. The live tone has unknown length.

Privacy check: `SHELL_PATH=prototypes/interleaf tools/headless/run.sh build/design-render-probe.sh build/design-interleaf-privacy` exited 0 (`privacy-composition: ok`). The short scenario waits four seconds, sends `mock '{"op":"screencast","active":true,"owner":1}'`, opens navigator, captures 08-privacy, closes it, then clears screencast. PNG inspected: “SHARING window” remains visible over the opaque Deck. qs.log has no QML errors; PipeWire connection failure is expected in this specific AUDIO=0 run. The screenshot is retained, while the disposable scenario remains under build/.

## Iterations and renderer evidence

- `build/design-interleaf-v1`: did not load; Quickshell refuses an imported type directory outside its shell root. No PNG. Fixed using a relative `visual` symlink within each prototype root, avoiding service copies.
- `build/design-interleaf-v2`: did not load; QML font does not expose `families`. No PNG. Corrected to font.family with fontconfig fallback.
- `build/design-interleaf-v3`: rendered an idle PNG (inspected) but logged binding errors because Text.style shadowed the Style id. Renamed the id to visualStyle.
- `build/design-interleaf-v4`, `build/design-parallax-v1`, `build/design-cut-v1`: exited 0; inspected their PNGs and logs. Found empty bare-prefix search, invalid foot colour section and clipped grid composition. Used `@ a` for actual result comparison; corrected foot to colors-dark; preserved the grid drawback in concept critique. Removed systems-implementation placeholder copy from the Sound view.
- Final main and later full/size runs: no QML binding/type/reference errors. Standard rectangles, borders, text and a static Canvas orbit demonstrably render with Qt software/pixman. No shaders are used. Existing architecture measurements of silent shader failure were read and respected, not falsely reported as new measurements.

## Palette check

Computed with `contrast()` imported from shell/lib/tokens.mjs through `node --input-type=module`. For each new foreground, checked `#DCE4D9`, `#F0F2E8`, `#E3E9DD`:

| Ink | Ratios in that background order |
|---|---|
| text `#202A25` | 11.37 / 13.08 / 11.95 |
| textDim `#526056` | 5.10 / 5.87 / 5.36 |
| signal `#943F32` | 5.35 / 6.16 / 5.62 |
| caution `#77530D` | 5.33 / 6.13 / 5.60 |
| critical `#A52B28` | 5.42 / 6.24 / 5.70 |
| nominal `#286140` | 5.62 / 6.46 / 5.90 |

Inverse text and dim on `#202B26`: 12.94 / 8.10. This checks the selected opaque palette; Parallax transparency and arbitrary user overrides are not certified by it.

## Performance

Baseline exact command: `AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/design-perf-before` (exit 0). First prototype command: `SHELL_PATH=prototypes/interleaf AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/design-perf-after` (exit 0), but qs.log records a configuration reload caused by work in progress. Its 0.41% first idle CPU / 121.8 MiB RSS is not treated as a valid steady comparison.

A clean final-source repeat uses `SHELL_PATH=prototypes/interleaf AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/design-perf-stable`. Exit 0; perf: ok. No reloads or QML errors in the clean run. No prototype source is edited during this measurement. The standard scenario measures 120 s idle and 30 s each open/after-use, using /proc CPU ticks and context switches. No thresholds are built into the scenario; figures are evidence, not a pass claim for real hardware.

| State / duration | Baseline CPU % / switches/s / RSS MiB | Interleaf CPU % / switches/s / RSS MiB |
|---|---|---|
| idle / 120 s | 0.13 / 2.2 / 85.0 | 0.12 / 1.7 / 107.2 |
| systems open / 30 s | 3.03 / 129.5 / 111.1 | 2.77 / 120.9 / 137.1 |
| command open / 30 s | 0.37 / 9.7 / 109.2 | 0.40 / 12.6 / 134.7 |
| idle after use / 30 s | 0.10 / 2.1 / 93.0 | 0.13 / 1.6 / 118.5 |

Peak RSS: baseline 118.9 MiB, Interleaf 145.2 MiB. Static idle CPU remains close to baseline; no ambient loop is introduced. Initial idle RSS grows by **22.2 MiB** with the new background/presentation and loaded prototype types. This is a measurable cost, not a claim of zero overhead or a leak diagnosis. Production should remove unused exploration types and be measured again after integration. These single runs are not precise enough to call small CPU differences an optimization or regression.

## Scope limits and Git handoff

The production design, exit/cross-bay motion, keyed notifications, secure lock, background lifecycle and absent hardware services await Claude. Real Hyprland, a GPU/DRM path, fractional output scaling, authentication, suspend/resume, hardware brightness/network/Bluetooth and actual compositor animation rules were not verifiable here. The prototypes intentionally retain original Systems/Routines/Help presentation and simplify some strip settings; full styling/API fidelity is phase 5. AI relocation with relative symlinks is not supported by the prototype harness path. These are exploration artifacts, not installable replacement packages.

Normal `git add docs/design/RECON.md && git commit ...` failed with: `Unable to create '/home/user/aerolith/.git/worktrees/aerolith-astra/index.lock': Read-only file system`. The environment explicitly grants read-only access to shared Git metadata; no bypass, push or branch switch was attempted. To preserve the requested phase history, four commits are authored as Astra (Codex) in separate writable Git metadata under `/tmp/aerolith-ui001-commits.git`, using this worktree as the source. A portable bundle and import instructions are exported into `build/`. The assigned worktree branch itself remains at 9fe38cd until imported from a writable session. Do not interpret isolated commits as an update to that branch.
