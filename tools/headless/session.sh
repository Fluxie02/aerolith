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

XDG_RUNTIME_DIR=/run/user/$(id -u)
export XDG_RUNTIME_DIR
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

# start_mock / start_audio are also used by scenarios that restart them.
start_mock() {
  read -ra mock_args <<<"${HYPR_MOCK_ARGS:-}"
  python3 "$SRC/tools/mock-hyprland/mock_hyprland.py" --seed --log "$OUT/hypr-requests.jsonl" "${mock_args[@]}" >>"$OUT/mock.log" 2>&1 &
  PIDS+=($!)
  export HYPRLAND_INSTANCE_SIGNATURE=aerolith_mock
  # Ready when it answers (socket files from a previous run may still exist).
  for _ in $(seq 50); do
    python3 "$SRC/tools/mock-hyprland/mock_hyprland.py" --control '{"op":"state"}' >/dev/null 2>&1 && break
    sleep 0.1
  done
}
if [ "${HYPR_MOCK:-1}" = 1 ]; then
  start_mock
fi

printf 'output HEADLESS-1 resolution %s scale %s\n' "$RES" "$SCALE" >"$OUT/sway.conf"
sway -c "$OUT/sway.conf" >"$OUT/sway.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 50); do
  WAYLAND_DISPLAY=
  for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
    case ${sock##*/} in *.lock) continue ;; esac
    [ -S "$sock" ] && WAYLAND_DISPLAY=${sock##*/} && break
  done
  [ -n "$WAYLAND_DISPLAY" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY
SWAYSOCK=
for sock in "$XDG_RUNTIME_DIR"/sway-ipc.*.sock; do [ -S "$sock" ] && SWAYSOCK=$sock && break; done
export SWAYSOCK

start_audio() {
  PIPEWIRE_DEBUG="${PIPEWIRE_DEBUG:-2}" pipewire >>"$OUT/pipewire.log" 2>&1 &
  PIDS+=($!)
  for _ in $(seq 50); do [ -S "$XDG_RUNTIME_DIR/pipewire-0" ] && break; sleep 0.1; done
  WIREPLUMBER_DEBUG="${WIREPLUMBER_DEBUG:-W}" wireplumber >>"$OUT/wireplumber.log" 2>&1 &
  PIDS+=($!)
  # WirePlumber loads its policy components asynchronously; nodes created
  # before that finishes are not picked up as default candidates. A fixed
  # settle time matched the standalone measurement in docs/TESTING.md.
  sleep 1.5
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=aerolith-speakers node.description="Test Speakers" media.class=Audio/Sink object.linger=true audio.position=[FL FR] }' >/dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=aerolith-headphones node.description="Test Headphones" media.class=Audio/Sink object.linger=true audio.position=[FL FR] }' >/dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=aerolith-mic node.description="Test Microphone" media.class=Audio/Source object.linger=true audio.position=[MONO] }' >/dev/null
  sleep 1
}
if [ "${AUDIO:-0}" = 1 ]; then
  start_audio
fi

# BACKLIGHT=1: a fake laptop backlight in sysfs format (the container has
# none) and a brightnessctl stand-in that writes it, for the brightness
# service. logind is absent here, so the service falls back to brightnessctl.
if [ "${BACKLIGHT:-0}" = 1 ]; then
  bl="$HOME/backlight/test_backlight"
  mkdir -p "$bl" "$HOME/fake-bin"
  echo raw >"$bl/type"
  echo 1000 >"$bl/max_brightness"
  echo 500 >"$bl/brightness"
  cat >"$HOME/fake-bin/brightnessctl" <<'FAKE'
#!/bin/sh
# brightnessctl --quiet --device=NAME set VALUE
dev=""; val=""
for a in "$@"; do case $a in --device=*) dev=${a#--device=};; [0-9]*) val=$a;; esac; done
[ -n "$dev" ] && [ -n "$val" ] && [ -d "$AEROLITH_BACKLIGHT_ROOT/$dev" ] || exit 1
echo "$val" >"$AEROLITH_BACKLIGHT_ROOT/$dev/brightness"
FAKE
  chmod +x "$HOME/fake-bin/brightnessctl"
  export AEROLITH_BACKLIGHT_ROOT="$HOME/backlight" PATH="$HOME/fake-bin:$PATH"
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

# AI=1: run a writable copy of the shell with the AI module installed the way
# the installer lays it out, and fake provider CLIs on PATH.
# SHELL_PATH selects another shell directory in the repo (for prototypes).
SHELL_SRC="$SRC/${SHELL_PATH:-shell}"
[ -f "$SHELL_SRC/shell.qml" ] || { echo "no shell.qml in $SHELL_SRC" >&2; exit 1; }
SHELL_DIR="$SHELL_SRC"
if [ "${AI:-0}" = 1 ]; then
  SHELL_DIR="$HOME/aerolith-shell"
  cp -r "$SHELL_SRC" "$SHELL_DIR"
  mkdir -p "$SHELL_DIR/modules/ai/bridge" "$HOME/.local/bin"
  cp "$SRC"/ai-bridge/qml/*.qml "$SHELL_DIR/modules/ai/"
  cp -r "$SRC/ai-bridge/aerolith_ai" "$SRC/ai-bridge/aerolith-ai-bridge" "$SHELL_DIR/modules/ai/bridge/"
  cp "$SRC"/tests/fixtures/fake-providers/* "$HOME/.local/bin/"
  export PATH="$HOME/.local/bin:$PATH" FAKE_LOG="$OUT/fake-provider.jsonl"
  printf '{"schemaVersion":1,"provider":"%s","enabled":true,"timeoutSeconds":20}\n' "${AI_PROVIDER:-claude}" >"$XDG_CONFIG_HOME/aerolith/ai.json"
fi
# INSTALL="<installer flags>": install AEROLITH from the checkout with the
# real installer (or, with PACKAGED=1, set up the pacman-installed tree with
# /usr/bin/aerolith) into this user's home (seeded with a minimal hyprland.lua)
# and run the shell from the installed location. Fake provider CLIs are put
# on PATH first so an AI choice finds a "Claude" or "Codex" without network.
if [ -n "${INSTALL:-}" ]; then
  mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME/hypr"
  cp "$SRC"/tests/fixtures/fake-providers/* "$HOME/.local/bin/"
  export PATH="$HOME/.local/bin:$PATH" FAKE_LOG="$OUT/fake-provider.jsonl"
  printf -- '-- test hyprland.lua\nhl.config({ general = { gaps_in = 4 } })\n' >"$XDG_CONFIG_HOME/hypr/hyprland.lua"
  cp "$XDG_CONFIG_HOME/hypr/hyprland.lua" "$OUT/hyprland.lua.orig"
  read -ra install_args <<<"$INSTALL"
  if [ "${PACKAGED:-0}" = 1 ]; then
    # Arch packages already installed by run.sh: per-user setup only.
    installer=(/usr/bin/aerolith install)
    SHELL_DIR=/usr/share/aerolith/shell
  else
    installer=(sh "$SRC/install.sh")
    SHELL_DIR="$HOME/.local/share/aerolith/shell"
  fi
  "${installer[@]}" "${install_args[@]}" --yes --no-start </dev/null >"$OUT/install.log" 2>&1 || {
    echo "FAIL: installer exited $?"; cat "$OUT/install.log"; exit 1; }
fi
export SHELL_DIR
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")

# --- helpers for scenarios ----------------------------------------------------
ipc() { qs -p "$SHELL_DIR" ipc call aerolith "$@"; }
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
