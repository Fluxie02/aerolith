# shellcheck shell=bash
# Signal Rack scenario: device default switching, stream routing and media
# control, each verified against PipeWire / MPRIS state from outside the
# shell. Needs AUDIO=1 MEDIA=1 MPV_AO=pipewire.
#
# Checks that need a healthy PipeWire graph (a default sink chosen by
# WirePlumber, mpv's stream linked to it) print SKIP with the reason when
# the container's audio graph is not healthy, instead of passing silently.
# See docs/TESTING.md, "Known limitations of the headless audio graph".
fail() { echo "FAIL: $*"; exit 1; }
skip() { echo "SKIP: $*"; }
sleep 3
ipc open signal; sleep 1.5
shot s1-rack

HAVE_DEFAULT=0
wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && HAVE_DEFAULT=1
LINKED=0
pw-link -l 2>/dev/null | grep -q "mpv:output" && LINKED=1
echo "graph: default-sink=$HAVE_DEFAULT mpv-linked=$LINKED"

# Default output. AEROLITH writes WirePlumber's default.configured.audio.sink
# preference (the key `wpctl set-default` writes) and reports success only if
# the effective default changes.
ipc run audio.output.set '{"device":"aerolith-headphones"}'; sleep 4
pw-metadata -n default 0 | grep -q "default.configured.audio.sink' value:'{\"name\":\"aerolith-headphones\"}'" || fail "default sink preference not written"
if wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q 'node.name = "aerolith-headphones"'; then
  grep -q "audio.output.set: ok" "$OUT/qs.log" || fail "default changed but success not reported"
  echo "default output: switched and reported"
else
  grep -q "audio.output.set: failed:" "$OUT/qs.log" || fail "default unchanged but failure not reported (false success)"
  echo "default output: WirePlumber kept the old default; AEROLITH reported the failure"
fi

# Per-application routing.
if [ "$LINKED" = 1 ]; then
  SID=$(pw-dump | python3 -c 'import json,sys; d=json.load(sys.stdin); print([o["id"] for o in d if o.get("type")=="PipeWire:Interface:Node" and o["info"]["props"].get("media.class")=="Stream/Output/Audio"][0])')
  CUR=$(pw-link -l | grep -B1 "mpv:output_FL" | head -1 | cut -d: -f1)
  DEST=aerolith-headphones; [ "$CUR" = aerolith-headphones ] && DEST=aerolith-speakers
  ipc run audio.stream.route "{\"stream\":$SID,\"device\":\"$DEST\"}"; sleep 4
  pw-link -l | grep -A1 "$DEST:playback_FL" | grep -q "mpv" || fail "stream not routed to $DEST"
  grep -q "audio.stream.route: ok" "$OUT/qs.log" || fail "route succeeded but not reported"
  shot s2-routed
else
  skip "stream routing: mpv's stream is not linked in this container's PipeWire graph"
fi

# MPRIS play/pause, confirmed with playerctl.
ipc run media.play-pause ''; sleep 1.5
[ "$(playerctl -p mpv status)" = "Paused" ] || fail "player not paused: $(playerctl -p mpv status)"
ipc run media.play-pause ''; sleep 1.5
[ "$(playerctl -p mpv status)" = "Playing" ] || fail "player not resumed"
grep -q "media.play-pause: ok: Paused" "$OUT/qs.log" || fail "pause not reported as confirmed"

# Mute, reflected in PipeWire.
if wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1; then
  ipc run audio.mute.toggle ''; sleep 1.5
  wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED || fail "mute not applied"
  shot s3-muted
  ipc run audio.mute.toggle ''; sleep 1
  wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && fail "unmute not applied"
else
  skip "mute: WirePlumber selected no default sink in this container"
fi

ipc close
alive || fail "quickshell died"
echo "signal: ok"
