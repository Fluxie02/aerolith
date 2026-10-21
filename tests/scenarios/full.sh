# Full interaction scenario. Needs AUDIO=1 MEDIA=1 MPV_AO=pipewire and the
# routines fixture (ROUTINES=tests/fixtures/routines.json).
# Sourced by tools/headless/session.sh.
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
shot 01-strip
ipc status >"$OUT/status.json"

# Command Core: typed alias invocation, verified against PipeWire.
ipc open command; sleep 1
typ "vol 40"; sleep 0.6
shot 02-command-vol
key Return; sleep 1.5
wpctl get-volume @DEFAULT_AUDIO_SINK@ >"$OUT/volume-after.txt"
grep -q "0.40" "$OUT/volume-after.txt" || fail "volume not 0.40: $(cat "$OUT/volume-after.txt")"

# Workspace dispatch through Hyprland's socket protocol (mock).
ipc open command; sleep 0.6
typ "ws 2"; sleep 0.3; key Return; sleep 1
mock '{"op":"state"}' >"$OUT/mock-after-ws.json"
grep -q '"active_workspace": 2' "$OUT/mock-after-ws.json" || fail "workspace 2 not focused"

# Fuzzy app search
ipc open command; sleep 0.6
typ "foot"; sleep 0.6
shot 03-command-search
ipc close; sleep 0.4

ipc open navigator; sleep 1.5; shot 04-navigator; ipc close; sleep 0.4
ipc open systems; sleep 5; shot 05-systems
ipc status >"$OUT/status-systems.json"
python3 - "$OUT/status-systems.json" <<'PY' || fail "telemetry not sampling in the Systems Bay"
import json, sys
s = json.load(open(sys.argv[1]))
assert s["telemetryIntervalMs"] == 1000, s
assert s["telemetrySamples"] >= 3, s
assert s["cpuPercent"] is not None and s["memoryPercent"] is not None, s
PY
ipc close; sleep 1
ipc status >"$OUT/status-idle.json"
python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["telemetryIntervalMs"]==5000, s' "$OUT/status-idle.json" || fail "sampling did not drop back after closing the Systems Bay"
wpctl status >"$OUT/wpctl-status.txt" 2>&1
ipc open signal; sleep 2; shot 06-signal; ipc close; sleep 0.4

# Routine: preview then run, verified by side effects.
ipc open routines; sleep 1; shot 07-routines
key Return; sleep 2.5
shot 08-routine-ran
ipc close; sleep 0.4
mock '{"op":"state"}' >"$OUT/mock-after-routine.json"
grep -q '"active_workspace": 3' "$OUT/mock-after-routine.json" || fail "routine did not focus workspace 3"
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.30" || fail "routine did not set volume 30"

ipc open help; sleep 1; shot 09-help; ipc close; sleep 0.4

alive || fail "quickshell died"
echo "full: ok"
