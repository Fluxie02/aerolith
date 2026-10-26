# UI-005 verification

Working copy: `/home/user/aerolith-astra`; source base `0d614e5`.
Rendering: Quickshell 0.3.2, Qt software backend, headless sway/pixman.
Source is fixed for all final runs. No commits attempted.

Unit checks (exit 0):

```bash
node tests/js/run-node.mjs
# 104 passed, 0 failed

docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
# 104 passed, 0 failed

python3 -m pytest -q tests/py
# 71 passed, 1 skipped in 14.90s
```

Each command below ran with default Saturated, then with
`CONFIG=build/ui005/insane.json`, containing exactly
`{"schemaVersion":1,"theme":{"intensity":"insane"}}`.
Each final scenario exits 0. `run-scenarios.sh` retains the exact environment
selection and output-directory mapping.

```bash
tools/headless/run.sh tests/scenarios/smoke.sh build/ui005/<intensity>-smoke
AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json \
  tools/headless/run.sh tests/scenarios/full.sh build/ui005/<intensity>-full
AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh tests/scenarios/signal.sh build/ui005/<intensity>-signal
AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" \
  tools/headless/run.sh tests/scenarios/deck.sh build/ui005/<intensity>-deck
CONFIG=tests/fixtures/notify-config.json \
  tools/headless/run.sh tests/scenarios/notify.sh build/ui005/saturated-notify
CONFIG=build/ui005/notify-insane.json \
  tools/headless/run.sh tests/scenarios/notify.sh build/ui005/insane-notify
AI=1 AUDIO=1 \
  tools/headless/run.sh tests/scenarios/ai.sh build/ui005/<intensity>-ai
```

The Insane notify configuration merges the notification fixture and intensity;
both seed JSON files are retained here. Signal reports the known skip:
mpv's audio stream is unlinked in the container, so stream routing cannot be
verified. Configured default-sink preference and honest failure reporting,
media controls and mute are verified. Full verifies typed commands, dispatch,
audio volume, routines and telemetry demand/release. Deck verifies immediate
demand release, rapid switching, keyboard input, notice expiry, 960×1707 logical
monitor geometry, motion off and failed-save rollback. Notify verifies actual
D-Bus action/closed signals. AI verifies request isolation, approval and removal.

Additional live check (exit 0):

```bash
AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh build/ui005/live-switch.sh build/ui005/live-switch-final
```

The retained `live-switch.sh` runs the required
`ipc run settings.intensity '{"intensity":"insane"}'`, screenshots, switches
back with a bay open, executes `vol 37`, rapidly changes intensities, then
unmaps/remaps Ground and Strip in each intensity using their supported config.
Immediate and settled return screenshots show complete geometry and no startup
replay. It switches again with motion off and lowEffects, then verifies `vol 38`.
The shell PID stays alive; no source reload appears. Reduced travel is gated in
Theme; all assembly work is bounded and lives outside the surface views.

Two development retries are retained for transparency. The first Saturated
signal run collided with a source hot reload during the last visual edit and
failed its initial command; the fixed-source `saturated-signal-final` passes.
The first extra live script supplied an unsupported parameter to the no-argument
lowEffects toggle and did not allow the harness typing helper to settle at its
last command. The corrected script uses the actual command API and normal
scenario timing; `live-switch-final` passes. Neither retry has QML errors.

All `qs.log` files, including retries and performance runs, are read and audited
in `log-audit.json`. Expected container warnings include missing UPower/system
bus, unsupported Hyprland shortcuts/mapping protocols and PipeWire real-time
privileges. Sway also emits occasional Wayland keyboard-leave/text-input focus
warnings; both required key-driven scenarios and the final live input check pass.
The Deck failed-save test deliberately logs a configuration-save error; the
routines fixture deliberately rejects its broken example. Neither is a QML
engine error. No QML parse/type/reference/assignment or binding errors occurred.

Performance uses unmodified `tests/scenarios/perf.sh`, once per intensity,
sequentially and with no concurrent headless render: 120 s initial idle and 30 s
per subsequent state after the standard startup/settle periods. Results follow
in `saturated-perf.json` and `insane-perf.json`.

```bash
AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/ui005/saturated-perf
CONFIG=build/ui005/insane.json AUDIO=1 MEDIA=1 \
  tools/headless/run.sh tests/scenarios/perf.sh build/ui005/insane-perf
```

Limit: these hosts predate Claude's fullscreen feature. Config visibility tests
exercise real layer-surface unmap/remap, but true fullscreen detection, real
Hyprland game transitions and GPU-memory reclamation remain systems integration
checks. No host/visibility binding was changed by Astra. No new setting needed.
One review of Claude's available integration is recorded in `review.txt`.
