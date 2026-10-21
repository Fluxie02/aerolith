#!/usr/bin/env bash
# Run AEROLITH inside a headless Wayland session for automated checks.
#
# Runs INSIDE the development container (tools/devcontainer/Containerfile),
# as an unprivileged user. It starts:
#   - a D-Bus session bus
#   - the Hyprland IPC mock (tools/mock-hyprland), unless HYPR_MOCK=0
#   - sway with the headless backend and the pixman software renderer
#     (Hyprland itself needs a DRM device; see docs/RESEARCH.md)
#   - optionally PipeWire + WirePlumber with a null sink (AUDIO=1)
#   - optionally mpv as a real MPRIS player (MEDIA=1)
#   - AEROLITH via `qs -p shell`
# then sources the scenario script given as $1 with helper functions.
#
# This is a test harness. It is not a supported way to run AEROLITH.
set -euo pipefail

SRC=${SRC:-/src}
OUT=${OUT:-/out}
SCENARIO=${1:?usage: session.sh <scenario.sh>}
RES=${RES:-1920x1080}
SCALE=${SCALE:-1}

export XDG_RUNTIME_DIR=/run/user/$(id -u)
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/.local/state
export QT_FORCE_STDERR_LOGGING=1 QT_QUICK_BACKEND=software
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
mkdir -p "$OUT" "$XDG_CONFIG_HOME/aerolith" "$XDG_STATE_HOME"

dbus-daemon --session --address="unix:path=$XDG_RUNTIME_DIR/bus" --fork --nopidfile >/dev/null
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

PIDS=()
cleanup() {
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
}
trap cleanup EXIT

if [ "${HYPR_MOCK:-1}" = 1 ]; then
  python3 "$SRC/tools/mock-hyprland/mock_hyprland.py" --seed --log "$OUT/hypr-requests.jsonl" ${HYPR_MOCK_ARGS:-} >"$OUT/mock.log" 2>&1 &
  PIDS+=($!)
  export HYPRLAND_INSTANCE_SIGNATURE=aerolith_mock
  for _ in $(seq 50); do [ -S "$XDG_RUNTIME_DIR/hypr/aerolith_mock/.socket.sock" ] && break; sleep 0.1; done
fi

printf 'output HEADLESS-1 resolution %s scale %s\n' "$RES" "$SCALE" >"$OUT/sway.conf"
sway -c "$OUT/sway.conf" >"$OUT/sway.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 50); do
  WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1 || true)
  [ -n "$WAYLAND_DISPLAY" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY
export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1 || true)

if [ "${AUDIO:-0}" = 1 ]; then
  PIPEWIRE_DEBUG="${PIPEWIRE_DEBUG:-2}" pipewire >"$OUT/pipewire.log" 2>&1 &
  PIDS+=($!)
  for _ in $(seq 50); do [ -S "$XDG_RUNTIME_DIR/pipewire-0" ] && break; sleep 0.1; done
  WIREPLUMBER_DEBUG="${WIREPLUMBER_DEBUG:-W}" wireplumber >"$OUT/wireplumber.log" 2>&1 &
  PIDS+=($!)
  # WirePlumber loads its policy components asynchronously; nodes created
  # before that finishes are not picked up as default candidates. A fixed
  # settle time matched the standalone measurement in docs/TESTING.md.
  sleep 1.5
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=aerolith-speakers node.description="Test Speakers" media.class=Audio/Sink object.linger=true audio.position=[FL FR] }' >/dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=aerolith-headphones node.description="Test Headphones" media.class=Audio/Sink object.linger=true audio.position=[FL FR] }' >/dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=aerolith-mic node.description="Test Microphone" media.class=Audio/Source object.linger=true audio.position=[MONO] }' >/dev/null
  sleep 1
fi

if [ "${MEDIA:-0}" = 1 ]; then
  # Arch's mpv-mpris loads itself from /etc/mpv/scripts.
  mpv --no-video --ao="${MPV_AO:-null}" --idle=no --loop=inf --force-media-title="AEROLITH Test Tone" \
    "av://lavfi:sine=frequency=440:sample_rate=48000" >"$OUT/mpv.log" 2>&1 &
  PIDS+=($!)
  if [ "${MPV_AO:-null}" = pipewire ]; then
    for _ in $(seq 50); do pw-link -l 2>/dev/null | grep -q "mpv:output" && break; sleep 0.1; done
    pw-link -l 2>/dev/null | grep -q "mpv:output" || echo "warning: mpv stream not linked" >&2
  else
    sleep 1
  fi
fi

qs -p "$SRC/shell" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=($QS_PID)

# --- helpers for scenarios ----------------------------------------------------
ipc() { qs -p "$SRC/shell" ipc call aerolith "$@"; }
shot() { grim "$OUT/$1.png"; }
# Each wtype invocation uploads a fresh keymap and Qt drops the first key
# event that follows it (measured; a physical keyboard is unaffected), so
# lead with a harmless modifier tap inside the same invocation.
typ() { wtype -k Shift_L -- "$1"; }
key() { wtype -k Shift_L -k "$1"; }
mock() { python3 "$SRC/tools/mock-hyprland/mock_hyprland.py" --control "$1"; }
wait_for_log() {
  local pattern=$1 timeout=${2:-10}
  for _ in $(seq $((timeout * 10))); do grep -q -- "$pattern" "$OUT/qs.log" && return 0; sleep 0.1; done
  echo "timeout waiting for log pattern: $pattern" >&2
  return 1
}
alive() { kill -0 "$QS_PID" 2>/dev/null; }

wait_for_log "Configuration Loaded" 20
# shellcheck source=/dev/null
source "$SCENARIO"
