# shellcheck shell=bash
# Deck lifecycle scenario. Needs AUDIO=1:
#   AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh
# Run it a second time with a scaled, rotated mock monitor to check that
# monitor geometry is logical (2560x1440 at scale 1.5, rotated 90 degrees,
# must arrive as 960x1707):
#   AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" \
#     tools/headless/run.sh tests/scenarios/deck.sh build/headless/deck-scaled
# Checks that
#   1. telemetry and audio demand end the moment a bay stops being requested,
#      while the Deck may stay mapped briefly for its exit, and the surface
#      is mapped exactly once per open-to-closed cycle (no remap on close),
#   2. rapid opening, switching and closing leaves no demand or surface behind,
#   3. a bay reopened during an exit takes keys from the first one,
#   4. with motion off the Deck unmaps at once, and switching motion off
#      during an exit ends it in the same event turn,
#   5. notices are not duplicated by a quiet result and expire at a time
#      fixed on arrival,
#   6. monitor geometry reaches the shell in logical units,
#   7. a setting that cannot be saved is reverted and reported.
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
maps=$(field deckMaps)
ipc open systems >/dev/null
wait_field telemetryIntervalMs 1000 5 || fail "Systems Bay did not raise sampling"
ipc close
[ "$(field telemetryIntervalMs)" = 5000 ] || fail "telemetry demand outlived the closed bay"
wait_field deckMapped False 3 || fail "the Deck did not unmap after its exit"
[ "$(field deckMaps)" = $((maps + 1)) ] || fail "the Deck surface was mapped $(( $(field deckMaps) - maps )) times for one open and close"

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

# 4b. Motion switched off during an exit ends the exit at once (SR-016-2).
#     The full exit lasts 160 ms, shorter than reading the status back, so the
#     Deck's own log line (written in the event turn that releases the slot)
#     is the evidence. When the switch lands after the exit has finished there
#     is nothing to end; that run is reported and retried.
ended=0
for attempt in 1 2 3 4 5 6 7 8; do
  ipc open systems >/dev/null
  wait_field deckMapped True 3 || fail "the Deck did not map for the exit test"
  before=$(grep -c "exit ended early" "$OUT/qs.log" || true)
  t0=$(date +%s%3N)
  ipc close
  ipc run settings.motion '{"motion":"off"}' >/dev/null
  elapsed=$(( $(date +%s%3N) - t0 ))
  wait_field deckMapped False 2 || fail "the Deck stayed mapped after motion went off"
  if [ "$(grep -c "exit ended early" "$OUT/qs.log" || true)" -gt "$before" ]; then ended=1; echo "deck: exit ended early (motion off ${elapsed} ms after close)"; fi
  ipc run settings.motion '{"motion":"full"}' >/dev/null
  wait_field motion full 5 || fail "could not switch motion back on after the exit test"
  [ "$ended" = 1 ] && break
  echo "deck: attempt $attempt landed after the exit (${elapsed} ms); retrying"
done
[ "$ended" = 1 ] || fail "motion off never landed during an exit in 8 attempts"
ipc run settings.motion '{"motion":"full"}' >/dev/null
wait_field motion full 5 || fail "could not switch motion back on after the exit test"
maps=$(field deckMaps)
ipc open command >/dev/null
ipc close
wait_field deckMapped False 3 || fail "the Deck did not unmap after the exit test"
[ "$(field deckMaps)" = $((maps + 1)) ] || fail "one open and close after the exit test mapped $(( $(field deckMaps) - maps )) times"

# 5. Notices: one per request, expiry fixed on arrival (info lives 3.5 s).
# Start clean: the settings commands above left their own result notices.
wait_field notices 0 10 || fail "earlier notices did not expire"
ipc run shell.notify '{"message":"First notice"}' >/dev/null
wait_field notices 1 5 || fail "shell.notify showed no notice"
sleep 0.5
[ "$(field notices)" = 1 ] || fail "shell.notify also reported its own result as a notice"
sleep 2
ipc run shell.notify '{"message":"Second notice"}' >/dev/null
wait_field notices 2 3 || fail "second notice missing"
shot d1-notices
sleep 2
[ "$(field notices)" = 1 ] || fail "the first notice's life was extended by the second ($(field notices) shown)"
wait_field notices 0 4 || fail "notices did not expire"

# 6. Logical monitor geometry.
case "${HYPR_MOCK_ARGS:-}" in
  "") expect=1920x1080 ;;
  *"--mode 2560x1440 --scale 1.5 --transform 1"*) expect=960x1707 ;;
  *"--mode 2560x1440 --scale 1.5"*) expect=1707x960 ;;
  *) expect="" ;;
esac
if [ -n "$expect" ]; then
  got=$(python3 -c 'import json,sys; m=json.loads(sys.argv[1])["monitor"]; print("%dx%d" % (m["width"], m["height"]))' "$(ipc status)")
  [ "$got" = "$expect" ] || fail "monitor geometry is $got, expected $expect"
fi

# 7. A setting that cannot be saved is reverted and reported.
cfg="$XDG_CONFIG_HOME/aerolith/config.json"
wait_field notices 0 10 || fail "earlier notices did not expire"
chmod 444 "$cfg"
ipc run settings.motion '{"motion":"reduced"}' >/dev/null
wait_for_log "could not save" 5 || fail "a failed save was not noticed"
wait_field motion full 5 || fail "an unsaved setting stayed applied"
# The command's own report plus the error notice about the failed save.
wait_field notices 2 3 || fail "the failed save was not reported ($(field notices) notices)"
chmod 644 "$cfg"

# Settings changed from the shell stay applied and saved.
[ "$(field motion)" = full ] || fail "the motion setting reverted to $(field motion)"
grep -q '"motion": "full"' "$XDG_CONFIG_HOME/aerolith/config.json" || fail "the motion setting was not saved"

alive || fail "quickshell died"
echo "deck: ok"

# 8. Optional leave protocol. A deliberately deferring test bay lives only in
# a disposable copy; production Settings wiring belongs to the Settings owner.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-qs.log"
cp -r "$SHELL_DIR" "$HOME/deck-leave-shell"
SHELL_DIR="$HOME/deck-leave-shell"
python3 - "$SHELL_DIR" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); p=root/'modules/deck/Deck.qml'
s=p.read_text().replace('SettingsBay { profile: deck.profile }','''FocusScope {
            property var profile: deck.profile
            property bool active: true
            property int requests: 0
            property string destination: ""
            signal leaveResolved(string destination)
            function requestLeave(target) { requests++; destination = target; return false; }
        }''',1)
p.write_text(s)
p=root/'shell.qml'
s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
s=s.replace('        active: !!Ui.overlayScreen','        id: leaveTestDeck\n        active: !!Ui.overlayScreen',1)
probe='''
    IpcHandler {
        target: "deckLeaveTest"
        function state(): string {
            const d = leaveTestDeck.item;
            const slot = d ? (d.slotA.current ? d.slotA : d.slotB.current ? d.slotB : null) : null;
            return JSON.stringify({bay:Ui.activeBay,mapped:Ui.deckMapped,current:slot ? slot.bay : "",
                active:slot && slot.item ? slot.item.active !== false : false,
                requests:slot && slot.bay === "settings" ? slot.item.requests : 0,
                destination:slot && slot.bay === "settings" ? slot.item.destination : ""});
        }
        function resolve(destination: string): void {
            const d=leaveTestDeck.item;
            const slot=d.slotA.current ? d.slotA : d.slotB.current ? d.slotB : null;
            if (slot && slot.item) slot.item.leaveResolved(destination);
        }
        function forcedClose(): void { leaveTestDeck.item.forceClose(); }
        function lockedClose(): void { Ui.locked=true; Ui.close(); Ui.locked=false; }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!; PIDS+=("$QS_PID")
leave_probe() { qs -p "$SHELL_DIR" ipc call deckLeaveTest "$@"; }
check_leave() {
  for _ in $(seq 60); do
    if leave_probe state >"$OUT/leave-state.json" 2>/dev/null && python3 - "$OUT/leave-state.json" "$1" <<'PY' 2>"$OUT/leave-error.txt"
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2]), s
PY
    then return 0; fi
    sleep .1
  done
  cat "$OUT/leave-error.txt"; fail "$1"
}
check_leave 's["bay"] == ""'
ipc open settings >/dev/null
check_leave 's["current"] == "settings" and s["active"] and s["requests"] == 0'
ipc open help >/dev/null
check_leave 's["bay"] == "settings" and s["current"] == "settings" and s["active"] and s["mapped"] and s["requests"] == 1 and s["destination"] == "deck:help"'
# A stale resolution cannot authorize a superseding navigation.
ipc open command >/dev/null
check_leave 's["requests"] == 2 and s["destination"] == "deck:command"'
leave_probe resolve deck:help
check_leave 's["bay"] == "settings" and s["requests"] == 2'
leave_probe resolve deck:command
check_leave 's["bay"] == "command" and s["current"] == "command"'
ipc close
check_leave 's["bay"] == ""'
ipc open settings >/dev/null
check_leave 's["current"] == "settings" and s["requests"] == 0'
# Real backdrop click takes the same path and retains input until resolution.
click 4 500
check_leave 's["bay"] == "settings" and s["requests"] == 1 and s["destination"] == "deck:close" and s["mapped"]'
leave_probe resolve deck:close
check_leave 's["bay"] == ""'
wait_field deckMapped False 3 || fail 'resolved close left Deck mapped'
# Host Esc and compositor/lock close bypass the hook, including a pending leave.
ipc open settings >/dev/null
check_leave 's["current"] == "settings"'
key Escape
check_leave 's["bay"] == ""'
ipc open settings >/dev/null
check_leave 's["current"] == "settings"'
ipc open help >/dev/null
check_leave 's["requests"] == 1'
leave_probe forcedClose
check_leave 's["bay"] == ""'
ipc open settings >/dev/null
check_leave 's["current"] == "settings"'
leave_probe lockedClose
check_leave 's["bay"] == ""'
# Fullscreen suspension also bypasses deferral using the real mock lifecycle.
ipc open settings >/dev/null
check_leave 's["current"] == "settings"'
game=$(python3 -c 'import json,sys;print(json.loads(sys.argv[1])["address"])' "$(mock '{"op":"open","class":"steam_app_1","title":"Leave test","workspace":1}')")
mock '{"op":"focus_workspace","workspace":1}' >/dev/null
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
check_leave 's["bay"] == ""'
wait_field deckMapped False 3 || fail 'fullscreen left deferring Deck mapped'
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log" "$OUT/startup-qs.log"; then fail 'QML errors'; fi
alive || fail 'quickshell died during leave protocol'
echo 'deck leave: ok (defer, supersede, stale resolution, continue, backdrop, Esc, compositor close, lock, fullscreen)'
