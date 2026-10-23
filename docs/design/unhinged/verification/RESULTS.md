# UI-011 verification

All work is production `shell/` visual code. Seven QML files changed; no host, service, schema, config parser, key handler or AI package changed. Git was used read-only. Root recorded the explicit owner assignment over the stale audit state and acquired Astra/UI-011 locks before edits.

## Unit and QML checks

```sh
node tests/js/run-node.mjs
# 104 passed, 0 failed

docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
# 104 passed, 0 failed

python3 -m pytest -q tests/py
# 71 passed, 1 skipped

git diff --check
# exit 0
```

Exact unit command lines/output: `unit/`. QML lint on all seven changed files exits 0 with no Error diagnostics (`runs/final-qmllint.txt`). Remaining lint warnings concern singleton/import resolution, existing frame aliases and intentional sample dependency reads.

## Functional matrix

For each `intensity` in `saturated insane`, configuration is `verification/configs/<intensity>.json`. Commands used these equivalents; individual logs preserve exact original output paths and environment:

```sh
CONFIG="$cfg" tools/headless/run.sh tests/scenarios/smoke.sh "$out/smoke"
CONFIG="$cfg" AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh tests/scenarios/full.sh "$out/full"
CONFIG="$cfg" AUDIO=1 \
  HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" \
  tools/headless/run.sh tests/scenarios/deck.sh "$out/deck"
CONFIG="$cfg" AI=1 AUDIO=1 \
  tools/headless/run.sh tests/scenarios/ai.sh "$out/ai"
CONFIG="$notify_cfg" tools/headless/run.sh tests/scenarios/notify.sh "$out/notify"
```

**All pass in both intensities.** Notify configs merge the existing notify fixture with the selected intensity. Deck verifies immediate demand release, rapid changes, reopened text input, motion-off unmapping, notice lifetimes, logical monitor geometry and failed-save rollback. Full verifies real typed volume commands, workspace dispatch, telemetry demand, routine effects and every core bay. AI verifies the separate component API, explicit requests, single-proposal approval and runtime module removal.

Frozen verification used `mkdir -p build/ui011-final-shell; cp -a shell build/ui011-final-shell/shell` and `SHELL_PATH=build/ui011-final-shell/shell`. Final Deck checks in both intensities and final Insane full/notify replayed after the workspace-target/exposure fixes. The last low-effects-only inactive border opacity correction was checked directly against production with `build/ui011/opaque-navigator.sh`; both command smoke and the opaque Navigator passed. It does not change the default full-effects path measured below.

Screenshots and logs live under `../saturated/`, `../insane/`; commands and summaries under `runs/`. All 29 archived QML logs were read; `log-audit.json` records zero engine, type, reference, assignment or binding-loop errors. Expected headless diagnostics include missing UPower/RTKit/global-shortcut protocols and PipeWire connection failure when AUDIO=0. Full intentionally logs two broken fixture routines; Deck intentionally logs a failed read-only config save. The media harness reports its mpv stream unlinked, so real hardware audio routing remains unverified.

## Motion and accessibility

`scripts/motion.sh` captures actual compositor frames around startup, workspace/focus events, opening, bay replacement and release. `timing.json` records screenshot request times, not compositor presentation timestamps. Six PNGs per event plus complete 18-frame WebP previews are preserved. The shell.notify, input and sharing indicator states are included.

`scripts/accessibility.sh` passes for both intensities with off, reduced, and low-effects/full. Low-effects uses 1280×720, uiScale 1.25 and Noto Sans/Noto Sans Mono. Command execution, Systems and Settings remain usable. Synthetic HTML-like titles render literally. Final low-effects Navigator captures also verify inactive faceted housings and keyboard selection.

Development retries are preserved: one Insane notify run reloaded when source files were saved, then passed on frozen source. One concurrent Saturated/off run lost typed input amid Wayland keyboard-leave warnings; an unchanged serial retry passed. Neither produced a QML engine error.

## Performance

```sh
CONFIG="$cfg" SHELL_PATH=build/ui011-final-shell/shell \
  AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh tests/scenarios/perf.sh "$out/perf"
```

Default 120-second initial idle / 30-second other windows, per-process `/proc` CPU and RSS, Qt software renderer and sway pixman. Baseline is a frozen copy of the starting shell at `bfeae67`. Independent containers shared the host during some verification; metrics count only each Quickshell process. No production edits reached the frozen performance source.

| State | Baseline CPU/core | Saturated | Insane |
|---|---:|---:|---:|
| Initial idle | 0.14% | 0.13% | 0.14% |
| Systems open | 2.70% | 2.90% | 2.90% |
| Command open | 0.27% | 0.27% | 0.27% |
| Idle after use | 0.13% | 0.17% | 0.17% |

Initial idle RSS: 121.5 / 124.0 / 124.6 MiB. Peak RSS: 174.3 / 207.3 / 200.8 MiB. The additional cached software geometry has a bounded memory cost. Default-length JSONs contain all four measurements. Their outer wrapper returned 143 during shutdown after measurements; a shorter 30/10-second confirmation sources the same `perf.sh` (`scripts/perf-confirm.sh`) and is recorded separately. Both confirmation runs exited 0 with `perf: ok`. Earlier live-source measurements reloaded during editing and are excluded from the table.

Hardware Hyprland, GPU VRAM release, real compositor animation stacking and physical multi-output operation remain outside this headless environment. Existing host lifecycles were not changed.
