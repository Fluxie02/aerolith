# UI-008 verification

Astra · 22 October 2026 · headless sway, Quickshell, software rendering.

**Status:** integrated source visuals and uninstalled app themes are saved.
The complete Settings bay is verified in `build/ui008/final-shell` and saved
as `../SettingsBay.patch`; its production file is still locked by Claude's
SHELL-008 handoff. No edit to the locked file, no commit, no installation of
app themes, and no dispatch of another agent has occurred. The pending lock
must be released or explicitly cleared before `design_complete` can be
published truthfully.

## Unit and contract checks

| Exact command | Result |
| --- | --- |
| `node tests/js/run-node.mjs` | 104 passed, 0 failed; `node-tests.txt` |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 104 passed, 0 failed; `qt-tests.txt` |
| `python3 -m pytest -q tests/py` | 71 passed, 1 skipped; `python-tests.txt` |
| `python3 build/ui008/contract-audit.py` | 32 checks passed; `contract-audit.json` |
| `git diff --check` | exit 0 |

The contract audit compares protected Settings functions and key handlers,
Command Core functions/keys, lock/session/OSD functions and keys, AI systems
prefix and functions, and all protected hosts/config/schema against HEAD.
Settings functions and handlers are byte-identical. `enabled: bay.editing`
is a presentation-only TextInput property outside them; repeated editing
and navigation after saving are tested. The frozen final-shell source
hashes match before/after runs, avoiding source hot reload during testing.

## Required production regression scenarios

Both intensities pass smoke, full, deck, notify and default-provider AI.
The exact matrix command is `bash build/ui008/final-scenarios.sh <intensity>`;
its saved implementation is `final-scenarios.sh`. It expands to:

```bash
SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/<intensity>.json \
  tools/headless/run.sh tests/scenarios/smoke.sh build/ui008/final-<intensity>-smoke
AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
  SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/<intensity>.json \
  tools/headless/run.sh tests/scenarios/full.sh build/ui008/final-<intensity>-full
AUDIO=1 HYPR_MOCK_ARGS='--mode 2560x1440 --scale 1.5 --transform 1' \
  SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/<intensity>.json \
  tools/headless/run.sh tests/scenarios/deck.sh build/ui008/final-<intensity>-deck
SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/notify-<intensity>.json \
  tools/headless/run.sh tests/scenarios/notify.sh build/ui008/final-<intensity>-notify
AUDIO=1 AI=1 SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/<intensity>.json \
  tools/headless/run.sh tests/scenarios/ai.sh build/ui008/final-<intensity>-ai
```

Every result is copied under `runs/`, with raw QML logs under `logs/`.
The full scenario verifies live PipeWire volume and routine/workspace side
effects. Deck verifies demand release, rapid changes, immediate motion-off
unmap, logical scaled/rotated monitor geometry, and failed-save rollback.

## Settings live integration

```bash
SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/saturated.json \
  tools/headless/run.sh build/ui008/settings-live.sh build/ui008/final-saturated-live
SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/insane.json \
  tools/headless/run.sh build/ui008/settings-live.sh build/ui008/final-insane-live-retry
```

Both pass. Real keyboard input opens with `ipc open settings`, navigates the
schema-generated rows and verifies persisted `config.json` values. Boolean
`ground.enabled` also changes IPC status live; enum `strip.edge` moves the
actual strip and updates status; numeric `telemetry.stripIntervalMs` changes
5000→6000 and the live sample interval, using the original step function.
Text `theme.fontSans` changes Inter→Noto Sans, applying the actual font in
the visible bay. A literal markup draft remains plain text and Escape
cancels it; 129-character text is refused without replacing the saved value.
Paging reaches the final logging section. Intensity changes in the open
bay and is restored; Ctrl+7, F1 and the Command Core `set` alias work.
Final config/status copies are saved beside this report.

## Pointer, tabs, motion and compact layouts

`pointer.sh` passes in both intensities. A verification-only Wayland virtual
pointer client (`pointer-client.c`, official `virtual-pointer.xml`) clicks the
Deck rail, scopes and each Settings control. It asserts persisted bool,
choice, number and text values, checks Systems demand after clicking its
rail entry, and records keyboard navigation after a text save. It introduces
no production input service. `swaymsg cursor` alone was insufficient without
a pointer device; that failed exploratory harness run is retained.

`tabs-capture.sh` records the same before/after framing in both intensities,
with Tab/Shift+Tab, Ctrl+3, Ctrl+7, F1 and a real foot process. Original views
come from `build/ui008/before-tabs-shell`. Final views use the immutable
`final-shell`; accepted Saturated output is `tabs-after-saturated-verified`
and Insane is `tabs-after-insane-final`. Both pass. `tabs-motion.sh` captures
full, reduced and off selection changes in both intensities. Compact checks
run `RES=1280x720`, `theme.uiScale=1.25`, Noto fonts, off/lowEffects, and pass
in both intensities; all labels, choices, selected descriptions and hints
remain reachable. Lock/session/OSD rounded previews use the existing fixture
hosts copied into `build/ui008/rounded-views/<view>` with final components;
`rounded-views.sh` captures representative states in both intensities plus
scaled literal text. All three pass, with no host/secure-lock integration.

The real foot launch uses `themes/foot/aerolith.ini` directly, with temporary
sway placement/border commands confined to the harness. No user theme is
installed. Sway cannot show Hyprland's rounded decoration; that is documented
rather than simulated. No real Hyprland/GPU/VRAM result is claimed.

## App theme validation

`theme-parser-final.txt` records native `foot --check-config` and
`Hyprland --verify-config --config` for both Lua and hyprlang fragments,
run as unprivileged pilot in the dev image: all pass. Python `tomllib` parses
Alacritty's TOML; `configparser` parses foot's INI. Kitty's options were
checked against its upstream reference. All 42 btop theme keys are present
in its upstream theme/parser source. Native rendering of kitty, Alacritty
and btop is not claimed. `theme-contrast.json` records 16 ANSI foregrounds,
shell text roles and selection; every foreground passes 4.5:1 on obsidian,
and selection is 14.45:1. References and integration notes are in
`themes/README.md` at repository root.

## Single systems review and revision

**P2 — hidden Settings text editor retained focus after commit.** Affected:
`shell/modules/settings/SettingsBay.qml`. Reproduced on the unchanged merged
source: save Noto Sans, press Enter again and type Inter; the visible draft
state does not open, but another Enter writes the hidden buffer. Evidence:
`build/ui008/text-focus-baseline/02-second-edit.png`, final config and saved
review script. The minimal correction is disabling the editor outside its
visible editing state. The one visual revision adds only
`enabled: bay.editing`; protected functions and key blocks remain unchanged.
`text-focus-revised` and both pointer runs show visible repeated editing and
working navigation after save. No further review cycle is requested.

## Exploratory failures retained

The first numeric assertion expected 5100; the existing power-of-ten step
correctly yields 6000. The assertion was corrected. Earlier text checks
revealed the baseline focus problem above. One Insane key run under concurrent
capture failed before the ground boolean was saved; the accepted retry uses
longer focus settling and 15 ms event spacing without resending actions.
Initial foot placement used an invalid compound `for_window` command; the
accepted runs issue placement after the real window exists. Early Hyprland
parser invocation as root was rejected; unprivileged parser runs pass.
None was a QML engine error or a changed production service.

## Performance and final log audit

```bash
AUDIO=1 MEDIA=1 SHELL_PATH=build/ui008/final-shell CONFIG=build/ui008/<intensity>.json \
  tools/headless/run.sh tests/scenarios/perf.sh build/ui008/final-<intensity>-perf
```

Both runs pass with the default 120 s idle / 30 s open and after-use windows.
They ran concurrently with each other after the interaction capture runs ended.
The earlier verified UI-007 Saturated result is retained as the comparison,
not re-run. These are software-renderer observations, not GPU/VRAM readings.

| Metric | Previous UI-007 | Saturated | Insane |
| --- | ---: | ---: | ---: |
| Initial idle CPU, % core | 0.25 | 0.25 | 0.3 |
| After-use idle CPU, % core | 0.23 | 0.3 | 0.3 |
| Initial idle context switches/s | 5.1 | 5.0 | 6.3 |
| Initial idle RSS, MiB | 119.3 | 120.4 | 120.9 |
| After-use idle RSS, MiB | 122.6 | 123.7 | 124.6 |
| Peak RSS, MiB | 179.2 | 172.8 | 180.9 |

No idle loop, sampling timer or shader was added. Idle CPU remains near zero;
retained bay demand and unmap behavior pass the Deck scenario.

**All 52 QML logs were audited, including exploratory failed harness runs:**
no parse, type, reference, assignment, component-load or binding-loop errors.
`log-audit.json` preserves the full diagnostics. Known headless messages remain:
unsupported Hyprland global-shortcut protocols under sway, absent system bus
and RTKit, PipeWire connection errors in runs without audio, and Qt Wayland
focus warnings during synthetic key delivery. The deck scenario intentionally
logs an unsuccessful config save and verifies rollback. These are distinct
from QML engine regressions.
