# UI-006 verification

Final source fingerprints are in `source-hashes.json`. Tests use Quickshell
0.3.2 / Qt 6.12 under headless sway, software Qt rendering and pixman.
All commands ran from the repository root. No production source changed after
the final captures except AI busy/cancelled copy, which was verified again in
the final AI runs. The normal and unavailable layouts, not only their startup
frames, were inspected.

## Unit checks

```bash
node tests/js/run-node.mjs
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
python3 -m pytest -q tests/py
git diff --check
```

Node: **104 passed, 0 failed**. Qt V4: **104 passed, 0 failed**.
Python: **71 passed, 1 skipped**. Diff whitespace check: **passed**.
Exact outputs are in `runs/{node,qt,python}-tests-final.txt`.

## Required headless scenarios

Every row below passed for both intensities. `CONFIG` selects
`build/ui006/{saturated,insane}-normal.json` (archived under `configs/`).
Notifications are enabled in these configs; all other production settings use
their defaults except intensity and strip telemetry `always`.

| Scenario | Exact invocation after `CONFIG=<config>` | Saturated output | Insane output |
|---|---|---|---|
| smoke | `tools/headless/run.sh tests/scenarios/smoke.sh build/ui006/<intensity>-smoke` | `runs/saturated-smoke.txt` | `runs/insane-smoke.txt` |
| full | `AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/ui006/<dir>` | `runs/saturated-full-verified.txt` | `runs/insane-full.txt` |
| signal | `AUDIO=1 MEDIA=1 MPV_AO=pipewire tools/headless/run.sh tests/scenarios/signal.sh build/ui006/<intensity>-signal` | `runs/saturated-signal.txt` | `runs/insane-signal.txt` |
| deck | `AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" tools/headless/run.sh tests/scenarios/deck.sh build/ui006/<dir>` | `runs/saturated-deck-verified.txt` | `runs/insane-deck.txt` |
| notify | `tools/headless/run.sh tests/scenarios/notify.sh build/ui006/<dir>` | `runs/saturated-notify-verified.txt` | `runs/insane-notify.txt` |
| ai | `AI=1 AUDIO=1 tools/headless/run.sh tests/scenarios/ai.sh build/ui006/<intensity>-ai-verified` | `runs/saturated-ai-verified.txt` | `runs/insane-ai-verified.txt` |

`<dir>` is respectively `saturated-full-verified`, `insane-full`,
`saturated-deck-verified`, `insane-deck`, `saturated-notify-verified`,
`insane-notify`. Each command exited 0. The signal scenario explicitly skips
stream routing because mpv's stream is unlinked in this container. Default
selection, media pause/resume and mute checks pass; stream routing on a healthy
graph remains an integration check.

The mandatory Codex invocations were also run for each intensity:

```bash
CONFIG=build/ui006/<intensity>-normal.json AI=1 AUDIO=1 AI_PROVIDER=codex \
  tools/headless/run.sh tests/scenarios/ai.sh build/ui006/<intensity>-codex-required
```

Both exit **1**, `FAIL: no answer with 2 proposals`. This is an existing
provider-specific scenario mismatch: the fake Codex returns one media proposal;
`ai.sh` expects the Claude fixture's two proposals, then Claude's `--tools`
argument and volume 25. Evidence: `runs/*-codex-required.txt` and matching logs.

A separate native Codex scenario passes in both intensities:

```bash
CONFIG=build/ui006/<intensity>-small.json RES=1280x720 AI=1 AUDIO=1 MEDIA=1 AI_PROVIDER=codex \
  tools/headless/run.sh build/ui006/codex-console.sh build/ui006/<intensity>-codex-verified
```

It asserts no request before Enter, `exec --sandbox read-only --ephemeral`,
feature disables, prompt via stdin with desktop context absent, dismissal
without a media change, and A approving the selected media pause. Both exit 0.
The scenario, fixture setup and exact outputs are archived in `scripts/` and
`runs/`. This does not turn the failing required Codex scenario into a pass.

## Visual and interaction matrix

`scripts/run-edges.sh` runs each intensity with these commands/configs:

```bash
CONFIG=build/ui006/<intensity>-<small|reduced|low>.json RES=1280x720 \
  HYPR_MOCK=0 ROUTINES=build/ui006/broken-routines.json \
  tools/headless/run.sh build/ui006/sweep.sh build/ui006/<intensity>-<variant>
CONFIG=build/ui006/<intensity>-small.json RES=1280x720 AUDIO=1 MEDIA=1 \
  ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh build/ui006/edge-states.sh build/ui006/<intensity>-edges
```

All eight runs exit 0. Small uses **uiScale 1.5, Noto Sans / Noto Sans Mono,
motion off**; reduced and lowEffects use scale 1. All bays are opened, including
AI not installed; Help and Systems are paged, as are Signal and routines. The
edge scenario adds a sway output and native DND/sharing events, empty workspace,
no-match query and a literal-markup notice. Notification lifecycle and popup
actions/expiry are covered by the required notify/deck scenarios. The additional
`insane-small-full-final` run passes the full interaction scenario at 720p and
uiScale 1.5 with audio, media and the routines fixture.

The all-annunciator layout is exercised by a copied presentation file:

```bash
python build/ui006/make-gallery.py
CONFIG=build/ui006/<intensity>-small.json RES=1280x720 MEDIA=1 \
  SHELL_PATH=build/ui006/gallery-shell tools/headless/run.sh build/ui006/gallery.sh \
  build/ui006/<intensity>-gallery-verified
```

Both exit 0. CPU, memory, temperature, battery, DND, config errors, multiple
outputs, sharing, media, mic mute and AUD N/A coexist. Sensor/battery alert
values are forced only in that copied visual file; no claim of real hardware
coverage is made.

AI state runs:

```bash
CONFIG=build/ui006/<intensity>-small.json RES=1280x720 AI=1 AUDIO=1 \
  tools/headless/run.sh build/ui006/ai-states.sh build/ui006/<intensity>-ai-states-complete
```

Both exit 0, with asserted `not_authenticated` faults. Captures cover ready,
busy with elapsed time, Escape cancellation, long literal `<b>`/`<img>` output,
five proposals, arrow navigation to the last one, D dismiss and a recoverable
authentication fault. The fake CLI is changed only in the container's writable
home. Model output, warnings, proposal titles, arguments and reasons all use
`Text.PlainText`. Real Tab/A approval is also covered by required ai.sh; native
Codex verifies D separately. No automatic action runs.

The startup probe (`scripts/boot-probe.sh`) passes: **85 finite startup progress
events, none on intensity change or ground/strip unmap-remap**. Its copied shell
root only observes Theme; the production startup latch is untouched. Captures
show retained input on intensity switching and the restored desktop.

## Performance

Exact final commands, with immutable copies to prevent source hot reload:

```bash
CONFIG=build/ui006/saturated-normal.json AUDIO=1 MEDIA=1 SHELL_PATH=build/ui006/baseline-shell \
  tools/headless/run.sh tests/scenarios/perf.sh build/ui006/baseline-perf-frozen
CONFIG=build/ui006/<intensity>-normal.json AUDIO=1 MEDIA=1 SHELL_PATH=build/ui006/final-shell \
  tools/headless/run.sh tests/scenarios/perf.sh build/ui006/<intensity>-perf-verified
```

The baseline is the HEAD shell; final-shell contains the final core QML. All
measurements use 120 seconds of initial idle and 30 seconds for each later
state. Software rendering, not a GPU/VRAM measurement.

| Metric | Baseline | Saturated | Insane |
|---|---:|---:|---:|
| Initial idle, % of one core | 0.29 | 0.29 | 0.32 |
| Idle after use, % of one core | 0.23 | 0.27 | 0.33 |
| Initial idle context switches/s | 8.3 | 7.6 | 8.9 |
| Idle after use context switches/s | 7.0 | 5.2 | 6.4 |
| Initial idle RSS, MiB | 118.5 | 119.7 | 119.8 |
| Idle after use RSS, MiB | 121.6 | 130.7 | 123.1 |
| Peak RSS, MiB | 170.0 | 171.3 | 179.7 |

Idle stays near zero. No new sampling, timers, looping motion or effects were
introduced. Existing sample/audio demand checks pass immediately after close.
Raw data: `baseline-perf-frozen.json`, `saturated-perf-verified.json`,
`insane-perf-verified.json`.

## Log and contract audit

**All 63 qs.log files were read**, including exploratory failures. No QML
parse/type/reference/assignment/binding-loop regression was found. Full raw
logs are in `logs/`; `log-audit.json` records every run and diagnostic.
Known headless diagnostics also occur in the baseline: missing UPower/system
bus and RTKit, unsupported Hyprland protocols under sway, Qt Wayland focus
warnings, and PipeWire connection failure when audio is intentionally absent.

Exploratory failures remain visible: heavy concurrent harness runs sometimes
dropped the beginning of `vol 40` (one capture contains only `40`); isolated
final retries pass. One earlier saturated matrix runner exited 143 during deck;
the isolated deck retry passes. Initial `before-perf` data includes four source
hot reloads and is discarded. `insane-full-final` also reloaded source; it is
not the accepted final full result. Earlier state fixtures that did not assert
the authentication fault are superseded by the `*-ai-states-complete` runs.

`runs/contract-audit.txt` and source comparisons confirm the AI systems prefix
and console key/completion/timer block are byte-for-byte unchanged, as are the
three protected hosts, services, configuration/schema and Theme startup latch.
FlightStrip's PanelWindow `visible:` binding remains identical. Only design
presentation and visual paging were changed. Git was used read-only.

## Single systems review for Claude

**P2 — provider-specific AI scenario.** Affected:
`tests/scenarios/ai.sh`, `tests/fixtures/fake-providers/codex`. Evidence: both
Codex required runs fail at the two-proposal expectation; native Codex runs
pass. Minimal correction: choose expected proposal count, lockdown arguments
and approved side effect by provider. One revision is available. No production
systems correction was needed for the visual design. Real Hyprland, GPU/VRAM
release, session transitions, live batteries and a healthy stream-routing graph
remain integration checks, consistent with ARCHITECTURE.md.
