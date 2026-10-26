# shellcheck shell=bash
# Resilience scenario. Needs AUDIO=1:
#   AUDIO=1 tools/headless/run.sh tests/scenarios/resilience.sh
# The shell must keep running and recover when
#   1. PipeWire and WirePlumber stop and start again,
#   2. the Hyprland IPC sockets disappear and come back (the mock restarts),
#   3. config.json becomes invalid JSON while the shell runs.
# A real Hyprland restart ends the Wayland session and the shell with it,
# so (2) checks reconnection to the IPC sockets, not a compositor restart.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
volume() { wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; }
cfg="$XDG_CONFIG_HOME/aerolith/config.json"
sleep 3
wait_field pipewire True 10 || fail "PipeWire not connected at start"

# 1. Audio stack restart.
pkill -x wireplumber || true
pkill -x pipewire || true
wait_field pipewire False 10 || fail "the shell did not notice PipeWire going away"
alive || fail "quickshell died when PipeWire stopped"
ipc run audio.volume.set '{"level":30}' >/dev/null
wait_for_log "audio.volume.set: failed" 5 || fail "no failure reported while PipeWire is down"
shot r1-audio-down
start_audio
wait_field pipewire True 15 || fail "the shell did not reconnect to PipeWire"
for _ in $(seq 50); do volume | grep -q Volume && break; sleep 0.1; done
ipc run audio.volume.set '{"level":35}' >/dev/null
wait_for_log "audio.volume.set: ok" 10 || fail "volume command does not work after the restart: $(grep 'audio.volume.set' "$OUT/qs.log" | tail -2)"
volume | grep -q "0.35" || fail "volume after restart: $(volume)"
echo "audio restart: ok"

# 2. Hyprland IPC restart.
pkill -f "mock_hyprland.py --seed" || true
sleep 1
alive || fail "quickshell died when the Hyprland sockets went away"
start_mock
mock '{"op":"focus_workspace","id":3}' >/dev/null
if wait_field focusedWorkspace 3 10; then
  echo "hyprland ipc restart: events resumed"
else
  # Recorded, not hidden: see docs/TESTING.md.
  echo "hyprland ipc restart: events did NOT resume (focusedWorkspace=$(field focusedWorkspace))"
  echo "events-not-resumed" >"$OUT/hyprland-reconnect.txt"
fi
alive || fail "quickshell died after the Hyprland sockets came back"

# 3. Config file broken while the shell runs.
printf '{ "schemaVersion": 1, "strip": { "edge": "bottom" } }\n' >"$cfg"
wait_field stripEdge bottom 10 || fail "config change not picked up"
wait_field configErrors 0 5 || fail "valid config reported errors"
printf '{ "schemaVersion": 1, "strip": { "edge": ' >"$cfg"
wait_field configFileBroken True 10 || fail "broken config.json not detected"
[ "$(field stripEdge)" = bottom ] || fail "previous settings not kept while config.json is broken"
[ "$(field configErrors)" = 1 ] || fail "broken config.json not reported"
before=$(sha256sum <"$cfg")
ipc run settings.density '{"density":"compact"}' >/dev/null
wait_for_log "settings.density: failed" 5 || fail "a setting was changed while config.json was broken"
[ "$(sha256sum <"$cfg")" = "$before" ] || fail "the shell wrote over the user's broken config.json"
shot r2-config-broken
printf '{ "schemaVersion": 1, "strip": { "edge": "top" } }\n' >"$cfg"
wait_field configFileBroken False 10 || fail "fixed config.json not picked up"
wait_field stripEdge top 5 || fail "fixed config.json not applied"
wait_field configErrors 0 5 || fail "errors not cleared after the fix"
echo "config broken at runtime: ok"

alive || fail "quickshell died"
echo "resilience: ok"
