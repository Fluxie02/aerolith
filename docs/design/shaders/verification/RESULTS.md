# E01/E02 verification results

Base `9b60683e5b23779edf66741ccadbe11d4daf79dd`; commands and limitations are
in [the README](../README.md). All rendering evidence here is Qt software
on headless sway/pixman. No shader appearance, GPU cost or GPU release result
is claimed.

| Check | Result |
| --- | --- |
| `node tests/js/run-node.mjs` | 135 passed, 0 failed |
| Qt V4 / `qml6 tests/js/run-qt.qml` with offscreen QPA | 135 passed, 0 failed |
| `python3 -m pytest -q tests/py tools/agent-sync/tests` | 111 passed, 1 skipped |
| `tools/build-shaders.sh` in aerolith-dev | Four programs baked successfully |
| `tools/build-shaders.sh --check` | All four packages match regenerated output |
| Changed shared include in disposable copy | Exit 1, all four stale packages named |
| smoke | Pass |
| full, AUDIO=1 MEDIA=1 MPV_AO=pipewire, routines fixture | Pass; media player exposed through MPRIS; mpv-link warning remains |
| deck, AUDIO=1 | Pass; motion-off exit completed early at 135 ms |
| notify, server fixture | Pass |
| osd, AUDIO=1 BACKLIGHT=1 | Pass; default-input microphone case skipped by scenario |
| fullscreen, AUDIO=1 with server fixture | Pass; 20 cycles, sustained-RSS-growth screen passed |
| notices-layout-matrix, default source | **Fails before QML:** stale direction-seam assertion |
| notices-layout-matrix, compatibility input | **15/15 pass**, 300 geometry snapshots, eight bays/eight cards per cell |
| Additional native captures | Four directions/intensity pairs, baseline + modified; 72 PNG frames |
| 720p/uiScale 1.5/reduced/bottom-strip OSD | Pass, visual bus/strip clearance checked |
| 4K/output scale 2 smoke | Pass; Material diagnostic outputScale = 2, no active software ShaderEffects |
| Strongest bevel reflection / built-in palettes | Analytical dim-label contrast minimum 4.9276:1, all 12 schemes × both directions |
| `bash -n tools/build-shaders.sh` and evidence scripts | Pass |
| `git diff --check` | Pass |

The compatibility input is a disposable copy of the final shell with the
initial Theme direction declaration set to the old literal the runner
expects. The unchanged scenario then injects each test direction into its
own disposable copy. Neither scenario nor production direction logic was
edited. [Matrix results](matrix-results.json), complete logs and geometry
are in `matrix/`. The default failure is retained in
[notices-matrix.txt](notices-matrix.txt). Minimal correction belongs to Sol,
recorded with severity and evidence in [SYSTEMS-REQUESTS](../SYSTEMS-REQUESTS.md).

The fullscreen RSS samples at cycles 1/10/20 were 143652/165764/161128 KiB.
The test's two 8 MiB interval growth screen passed (`steady_growth: false`).
This checks an existing software lifecycle; it is not leak or VRAM proof.

Native profile screenshots preserve dark numeral backgrounds, legible
engraving, rectangular bays and bus clearance. Before/after native material
appearance is intentionally the same, apart from OSD placement. The images
are not synchronized; CPU telemetry and finite ambient phase vary.

## Idle CPU screen

[The measurement script](idle.sh) allows 15 s warm-up then samples the shell
process's `/proc` CPU ticks for 120 s. AUDIO=1, 1920×1080/output scale 1,
full motion. Baseline and modified copies have the same profile config and
installation direction. The four samples run sequentially; the first two
overlap the matrix/capture campaign, like the archived UI-013 measurements.
They are process CPU screens, not isolated hardware benchmarks.


| Intensity | Before | After | Budget |
| --- | ---: | ---: | ---: |
| Saturated | 1.492% | 1.542% | ~2% |
| Insane | 3.692% | 3.817% | ~4% |

Final paired results are in [idle/](idle/). The owner budgets documented in
UI-013 are about 2% of one core for Saturated and 4% for Insane. Software
backend shaders are unavailable throughout, so these measure the fallback
and interface overhead only. No off/lowEffects CPU or active GPU cost was
measured; those modes received geometry/scenario coverage instead.

## Log review

All 35 complete final `qs.log` files were read and archived as `qs.txt` (the repo
ignores `.log`). [log-audit.json](log-audit.json) records hashes, line counts,
QML error matches and remaining warnings for every final positive run.
Expected warnings include absent Hyprland protocols under sway, missing
system bus/UPower/RTKit, unavailable PipeWire when AUDIO=0, Wayland focus and
text-input diagnostics, the deliberately invalid routine, and Deck's
intentional read-only-config write failure. No shader appearance can be
inferred from these software logs. Failed GPU attempts are stored separately.

No service, Deck.qml, shell root, config/schema, or harness file changed.
Only the PanelWindow anchor/margin lines changed in OsdHost.qml.
