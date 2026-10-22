# shellcheck shell=bash
# Deck lifecycle scenario. Needs AUDIO=1:
#   AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh
# Run it a second time with a scaled mock monitor to check that monitor
# geometry is logical (2560x1440 at scale 1.5 must arrive as 1707x960):
#   AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5" \
#     tools/headless/run.sh tests/scenarios/deck.sh build/headless/deck-scaled
# Checks that
#   1. telemetry and audio demand end the moment a bay stops being requested,
#      while the Deck may stay mapped briefly for its exit,
#   2. rapid opening, switching and closing leaves no demand or surface behind,
#   3. a bay reopened during an exit takes keys from the first one,
#   4. with motion off the Deck unmaps at once,
#   5. notices are not duplicated by a quiet result and expire at a time
#      fixed on arrival,
#   6. monitor geometry reaches the shell in logical units.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
volume() { wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; }
sleep 3
wait_field pipewire True 10 || fail "PipeWire not connected at start"

# 1. Demand follows the request, not the pixels.
ipc open systems >/dev/null
wait_field telemetryIntervalMs 1000 5 || fail "Systems Bay did not raise sampling"
ipc close
[ "$(field telemetryIntervalMs)" = 5000 ] || fail "telemetry demand outlived the closed bay"
wait_field deckMapped False 3 || fail "the Deck did not unmap after its exit"

ipc open signal >/dev/null
wait_field audioDetail 1 5 || fail "Signal Rack did not take audio detail demand"
ipc open command >/dev/null
[ "$(field audioDetail)" = 0 ] || fail "audio detail outlived the replaced bay"
ipc close
wait_field deckMapped False 3 || fail "the Deck did not unmap after a switch and close"

# 2. Rapid changes leave nothing behind.
for _ in 1 2 3 4 5; do
  ipc open systems >/dev/null
  ipc open signal >/dev/null
  ipc open navigator >/dev/null
  ipc close
done
wait_field deckMapped False 3 || fail "the Deck stayed mapped after rapid changes"
[ "$(field audioDetail)" = 0 ] || fail "audio detail leaked after rapid changes"
[ "$(field telemetryIntervalMs)" = 5000 ] || fail "telemetry demand leaked after rapid changes"
alive || fail "quickshell died during rapid changes"

# 3. Reopen during the exit and type at once.
ipc open command >/dev/null
sleep 0.8
ipc close
ipc open command >/dev/null
sleep 0.5
typ "vol 33"
sleep 0.4
key Return
for _ in $(seq 30); do volume | grep -q "0.33" && break; sleep 0.1; done
volume | grep -q "0.33" || fail "keys typed into a reopened Command Core were lost ($(volume))"
wait_field deckMapped False 3 || fail "the Deck stayed mapped after running a command"

# 4. Motion off: no exit, the surface goes at once.
ipc run settings.motion '{"motion":"off"}' >/dev/null
wait_field motion off 5 || fail "could not switch motion off"
ipc open systems >/dev/null
wait_field telemetryIntervalMs 1000 5 || fail "Systems Bay did not open with motion off"
ipc close
[ "$(field deckMapped)" = False ] || fail "the Deck kept an exit with motion off"
ipc run settings.motion '{"motion":"full"}' >/dev/null
wait_field motion full 5 || fail "could not switch motion back on"

# 5. Notices: one per request, expiry fixed on arrival (info lives 3.5 s).
# Start clean: the settings commands above left their own result notices.
wait_field notices 0 10 || fail "earlier notices did not expire"
ipc run shell.notify '{"message":"First notice"}' >/dev/null
wait_field notices 1 5 || fail "shell.notify showed no notice"
sleep 0.5
[ "$(field notices)" = 1 ] || fail "shell.notify also reported its own result as a notice"
sleep 1.5
ipc run shell.notify '{"message":"Second notice"}' >/dev/null
wait_field notices 2 3 || fail "second notice missing"
shot d1-notices
sleep 1.8
[ "$(field notices)" = 1 ] || fail "the first notice's life was extended by the second ($(field notices) shown)"
wait_field notices 0 4 || fail "notices did not expire"

# 6. Logical monitor geometry.
case "${HYPR_MOCK_ARGS:-}" in
  "") expect=1920x1080 ;;
  *"--mode 2560x1440 --scale 1.5"*) expect=1707x960 ;;
  *) expect="" ;;
esac
if [ -n "$expect" ]; then
  got=$(python3 -c 'import json,sys; m=json.loads(sys.argv[1])["monitor"]; print("%dx%d" % (m["width"], m["height"]))' "$(ipc status)")
  [ "$got" = "$expect" ] || fail "monitor geometry is $got, expected $expect"
fi

# Settings changed from the shell stay applied and saved.
[ "$(field motion)" = full ] || fail "the motion setting reverted to $(field motion)"
grep -q '"motion": "full"' "$XDG_CONFIG_HOME/aerolith/config.json" || fail "the motion setting was not saved"

alive || fail "quickshell died"
echo "deck: ok"
