# Phase 1 — Astra

5 November 2026 · P1-ASTRA · base d73aaff. No commit made.
Owner-authorized parallel work used Opus's delegated P1-ASTRA locks; shared
workflow still belongs to Claude. Only assigned UI files and this evidence
folder changed. P1-SOL files were read for peer review, never edited.

## Changes and rationale

- `CommandCore.qml`, `DeckView.qml`, `SignalRack.qml`, `RoutineConsole.qml`,
  `SettingsBay.qml`, `HelpBay.qml`, `AiModule.qml`: remove obsolete rail numbers.
  Search reads SEARCH; Signal and Routines use the SYSTEMS designation while
  retaining their specific titles. Deck's code labels use plain bay names.
- `DeckView.qml`, `SchemePicker.qml`: replace direction/intensity inscriptions
  with close/help guidance and the active scheme. Saturated / Insane remain
  the intensity choices, explained as the **decoration level** in Settings.
- `RoutineConsole.qml`: direct people to Commands in the AEROLITH documentation
  (Help), without a repository-relative documentation path.
- `HelpBay.qml`, `SettingsBay.qml`: pointer, keyboard and accessibility actions
  call `Tour.start()` and close the bay on success. No `tour.enabled` UI gate.
  Help honestly labels global action names and lists the session, scratch and
  park combinations from `hypr.py` DEFAULT_BINDS as installer defaults.
- `TourHost.qml`, `TourCard.qml`: named “n of 5” progress; configured-edge status
  strip copy and hidden-strip alternatives; final Open Settings action finishes
  the tour and executes `shell.open.settings` through Registry.
- `SettingsBay.qml`: persistent, bounded, scrollable diagnostics show path and
  message, with errors first and separately labelled warning/error roles. A
  single row uses only its needed height; the list has keyboard access. Change
  feedback says REQUESTED to remain truthful with P1-SOL's queued saves.

Bezel housings, typography tokens, profile colours and the three-bay rail are
preserved. No new animation, timer, core integration or resource logic.

## Captures

Full-resolution JPEGs, quality 85, no resizing: **2,721,431 bytes (2.60 MiB)**
total, below 3 MiB. Both use the bottom strip and `warning-config.json`, whose
unknown `theme.decorationLevel` produces one warning and zero errors.

| View | 1920×1080, scale 1 | 3840×2160, scale 1.5 |
|---|---|---|
| Help | [JPEG](1080-help.jpg) | [JPEG](4k-help.jpg) |
| Settings warning | [JPEG](1080-settings-warning.jpg) | [JPEG](4k-settings-warning.jpg) |
| Deck / Search designation | [JPEG](1080-deck.jpg) | [JPEG](4k-deck.jpg) |
| Tour step 1 | [JPEG](1080-tour-1.jpg) | [JPEG](4k-tour-1.jpg) |
| Tour step 5 | [JPEG](1080-tour-5.jpg) | [JPEG](4k-tour-5.jpg) |

Visually inspected all ten: labels fit, actions stay in their housings, warning
text stays readable, and tour cards clear the bottom strip. Help references and
Settings spectra scroll rather than overlap. At 4K all twelve specimens fit.
`instrument.py` adds read-only probes only to a disposable container shell copy;
`capture.sh` checks actual keyboard activation of both tour entry actions,
final-step pointer navigation to Settings, named progress, bottom-edge wording
and warning persistence after reopening Settings.

## Checks

Docker was already running (`docker info --format '{{.ServerVersion}}'` →
29.9.1); no daemon or host changes. Required scenarios ran **one at a time**,
using CI's invocations and output paths. All exited 0; no scenario needed retry.

```sh
tools/headless/run.sh tests/scenarios/smoke.sh build/ci/smoke
# smoke: ok
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/ci/deck
# deck: exit ended early (motion off 118 ms after close); deck: ok
TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/ci/tour
# tour: ok (state persistence, primary surface/focus, real navigation,
# fullscreen lifetime, keyboard returned to foot)
tools/headless/run.sh tests/scenarios/app-links.sh build/ci/app-links
# app-links: ok
AI=1 tools/headless/run.sh tests/scenarios/catalogue.sh build/ci/catalogue
# 67 commands; catalogue: ok
python3 tools/gen-commands-doc.py build/ci/catalogue/commands.json
git diff --exit-code -- docs/COMMANDS.md
# regenerated; docs/COMMANDS.md unchanged; both exit 0
node tests/js/run-node.mjs
# passed 238, failed 0
CONFIG=docs/design/phase1/warning-config.json RES=1920x1080 tools/headless/run.sh docs/design/phase1/capture.sh build/phase1/1080
CONFIG=docs/design/phase1/warning-config.json RES=3840x2160 SCALE=1.5 HYPR_MOCK_ARGS='--mode 3840x2160 --scale 1.5' tools/headless/run.sh docs/design/phase1/capture.sh build/phase1/4k
# both: phase1 capture: ok
bash -n docs/design/phase1/capture.sh
python3 -m py_compile docs/design/phase1/instrument.py
git diff --check
# all exit 0
```

Initial 1080p capture failed at the Settings keyboard replay sequence. Explicit
Tab/Backtab traversal and paced input fixed the sequence; both final capture
runs pass. The single-warning panel was also reduced after visual inspection.
No QML engine errors in either final capture's running lifetime. The standard
tour harness excludes teardown-only undefined bindings; Sway's unsupported
Hyprland shortcuts, PipeWire RTKit absence and Qt focus teardown warnings remain
expected harness limitations.

## Integration risks and peer review

Manual replay when automatic onboarding is disabled depends on **P1-SOL's
Tour.qml/tour.mjs changes**. This branch calls the service directly without a
preference gate; its standard tour test still tests the pre-merge service.
Installed documentation depends on P1-SOL. Actual user key combinations remain
unavailable; displayed combinations are explicitly defaults.

Reviewed P1-SOL's source once in worktree 607e9e1e: profile substitutions and
manual-tour gate preserve the intended visual contracts. **Medium — premature
save success:** Config.setValue now queues and returns before onSaved, while
ShellCommands.setting reports “saved to config.json” immediately. Evidence:
`Config.qml` setValue/saveNext/onSaved and `ShellCommands.qml` setting(). Minimal
correction: report “change requested” on acceptance or await successful-save
notification. Published a sync review note requesting one systems revision;
Astra's Settings feedback already uses REQUESTED. Remaining runtime checks of
lock/PAM, mixed-output profiles, and the merged disabled-tour/doc flow belong to
integration acceptance. All screenshots here are Sway/software-rendered with
mock Hyprland, not hardware/GPU evidence.
