# shellcheck shell=bash
# OSD scenario (roadmap D01). Needs AUDIO=1:
#   AUDIO=1 tools/headless/run.sh tests/scenarios/osd.sh
# Changes go straight through PipeWire (wpctl), as a key binding or another
# application would make them. Checks that
#   1. nothing is shown for the values PipeWire reports at startup,
#   2. a volume change shows the volume OSD, which expires on its own,
#   3. a burst of changes keeps one OSD and restarts its expiry,
#   4. output mute shows the volume OSD and microphone mute the mic OSD,
#   5. a change made while the Deck is open shows no OSD.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
sleep 3
wait_field pipewire True 10 || fail "PipeWire not connected"
[ "$(field osd)" = "" ] || fail "an OSD was shown at startup: $(field osd)"
sleep 1.5

# 2. One change.
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
wait_field osd volume 3 || fail "a volume change showed no OSD"
shot 01-volume
wait_field osd "" 3 || fail "the volume OSD did not expire"

# 3. A burst keeps one OSD alive past its single lifetime.
for v in 0.42 0.44 0.46 0.48 0.50 0.52; do wpctl set-volume @DEFAULT_AUDIO_SINK@ $v; sleep 0.4; done
[ "$(field osd)" = volume ] || fail "the OSD expired during a burst of changes"
wait_field osd "" 3 || fail "the OSD did not expire after the burst"

# 4. Mute and microphone mute.
wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
wait_field osd volume 3 || fail "muting showed no OSD"
shot 02-muted
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
wait_field osd "" 4 || fail "the mute OSD did not expire"
# The harness creates a "Test Microphone" source, but WirePlumber does not
# make it the default input in this session (neither wpctl set-default nor
# the default.configured.audio.source metadata take effect), so the shell
# has no input device here and this case runs only where one exists.
if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q Volume; then
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
  wait_field osd mic 3 || fail "microphone mute showed no OSD"
  shot 03-mic
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
  wait_field osd "" 4 || fail "the mic OSD did not expire"
else
  echo "osd: no default input in this session; microphone case skipped (harness limit)"
fi

# 5. The open Deck shows the level itself.
ipc open signal >/dev/null
wait_field deckMapped True 3 || fail "the Deck did not open"
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30
sleep 1
[ "$(field osd)" = "" ] || fail "an OSD was shown over the open Deck"
ipc close
wait_field deckMapped False 3 || fail "the Deck did not close"

alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "osd: ok"
