# shellcheck shell=bash
# OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh
fail() { echo "FAIL: $*"; exit 1; }
# Add read-only probes to a disposable shell. Observe real Variants/loader
# instances and mapped PanelWindows; policy/status alone cannot prove release.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/multimonitor-shell"
SHELL_DIR="$HOME/multimonitor-shell"
python3 - "$SHELL_DIR/shell.qml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
s=s.replace('model: Displays.groundScreens','id: grounds\n        model: Displays.groundScreens')
s=s.replace('model: Displays.stripScreens','id: strips\n        model: Displays.stripScreens')
s=s.replace('active: !!Ui.overlayScreen', 'id: overlayLoader\n        active: !!Ui.overlayScreen')
s=s.replace('active: !!Ui.noticeScreen', 'id: noticeLoader\n        active: !!Ui.noticeScreen')
probe='''
    IpcHandler {
        target: "multimonitor"
        function snapshot(): string {
            function surface(loader) {
                const w = loader.item;
                return { output: loader.modelData.name, loaded: w !== null,
                    visible: !!w && w.visible, screen: w && w.screen ? w.screen.name : "" };
            }
            const deck = overlayLoader.item;
            const notices = noticeLoader.item;
            return JSON.stringify({ grounds: grounds.instances.map(surface),
                strips: strips.instances.map(surface),
                deck: deck && deck.visible && deck.screen ? deck.screen.name : "",
                notices: notices && notices.visible && notices.screen ? notices.screen.name : "" });
        }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
PY
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call multimonitor snapshot; }
# Expressions run over both the public status and the read-only live probe.
check() {
  local expression=$1
  ipc status >"$OUT/status.json" 2>/dev/null && probe >"$OUT/surfaces.json" 2>/dev/null &&
    python3 - "$OUT/status.json" "$OUT/surfaces.json" "$expression" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); p=json.load(open(sys.argv[2]))
o={x['name']:x for x in s['outputs']}
assert eval(sys.argv[3]), (sys.argv[3], s, p)
PY
}
wait_check() {
  local expression=$1
  for _ in $(seq 60); do
    if check "$expression" 2>"$OUT/check-error.txt"; then return 0; fi
    sleep 0.1
  done
  cat "$OUT/check-error.txt" >&2
  fail "$expression"
}
config() {
  # Atomic replacement exercises the actual config watcher (no shell reload).
  printf '%s\n' "$1" >"$XDG_CONFIG_HOME/aerolith/config.json.tmp"
  mv "$XDG_CONFIG_HOME/aerolith/config.json.tmp" "$XDG_CONFIG_HOME/aerolith/config.json"
}
wait_check 'len(o)==2 and all(x["loaded"] and x["visible"] and x["screen"]==x["output"] for x in p["grounds"]+p["strips"]) and len(p["grounds"])==2 and len(p["strips"])==2'
wait_check 's["display"]=="HEADLESS-1" and s["noticeOutput"]=="HEADLESS-1"'
shot 01-two-outputs
mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null
wait_check 'o["HEADLESS-2"]["focused"] and s["overlayOutput"]=="HEADLESS-2"'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-2"'
shot 02-focused-overlay
ipc close
wait_check 'not s["deckMapped"]'
ipc run shell.notify '{"message":"Primary output notice"}' >/dev/null
wait_check 'p["notices"]=="HEADLESS-1"'

# Second monitor's own workspace, not the primary's active workspace.
game=$(mock '{"op":"open","class":"mm1-game","title":"MM1 game","workspace":4}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_check 'o["HEADLESS-2"]["released"] and not o["HEADLESS-1"]["released"] and all(x["loaded"]==(x["output"]=="HEADLESS-1") for x in p["grounds"]+p["strips"])'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-2" and o["HEADLESS-2"]["released"]'
shot 03-output-fullscreen
# Removing the focused fullscreen output destroys its delegates, and the
# existing overlay moves to the surviving primary without reopening it.
swaymsg output HEADLESS-2 unplug >/dev/null
mock '{"op":"remove_monitor","name":"HEADLESS-2"}' >/dev/null
wait_check 'len(o)==1 and len(p["grounds"])==1 and len(p["strips"])==1 and p["deck"]=="HEADLESS-1"'
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
ipc close
wait_check 'not s["deckMapped"]'
# Replug uses a fresh lifecycle.
swaymsg create_output >/dev/null
# wlroots gives re-created outputs a new name. Read it instead of guessing.
second=$(swaymsg -t get_outputs -r | python3 -c 'import json,sys;print(next(o["name"] for o in json.load(sys.stdin) if o["name"]!="HEADLESS-1"))')
swaymsg "output $second mode $RES scale $SCALE pos ${RES%x*} 0" >/dev/null
mock "{\"op\":\"add_monitor\",\"name\":\"$second\",\"workspace\":5}" >/dev/null
wait_check 'len(o)==2 and all(not x["released"] for x in o.values()) and len(p["grounds"])==2'
# The inverse fullscreen case: the primary releases while the secondary
# remains mapped, then both restore independently.
primary_game=$(mock '{"op":"open","class":"mm1-primary-game","title":"Primary game","workspace":1}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
mock "{\"op\":\"fullscreen\",\"address\":\"$primary_game\",\"mode\":2}" >/dev/null
wait_check "o['HEADLESS-1']['released'] and not o['$second']['released'] and all(x['loaded']==(x['output']=='$second') for x in p['grounds']+p['strips'])"
mock "{\"op\":\"fullscreen\",\"address\":\"$primary_game\",\"mode\":0}" >/dev/null
wait_check 'all(not x["released"] for x in o.values()) and all(x["loaded"] for x in p["grounds"]+p["strips"])'
config "{\"display\":{\"primary\":\"$second\",\"overlayOn\":\"primary\"}}"
wait_check "s['display']=='$second' and s['noticeOutput']=='$second' and o['$second']['primary']"
ipc open command >/dev/null
wait_check "p['deck']=='$second'"
ipc close
wait_check 'not s["deckMapped"]'
# Disable one surface on each output. Disabled surfaces must be destroyed.
config "{\"display\":{\"primary\":\"$second\",\"outputs\":{\"HEADLESS-1\":{\"strip\":false},\"$second\":{\"ground\":false,\"profile\":\"oled\"}}}}"
wait_check "len(p['strips'])==1 and p['strips'][0]['output']=='$second' and len(p['grounds'])==1 and p['grounds'][0]['output']=='HEADLESS-1' and o['$second']['profile']=='oled'"
# A stale configured primary/notice name falls back when unplugged.
swaymsg "output $second unplug" >/dev/null
mock "{\"op\":\"remove_monitor\",\"name\":\"$second\"}" >/dev/null
config "{\"display\":{\"primary\":\"$second\",\"noticesOn\":\"$second\"}}"
wait_check 'len(o)==1 and s["display"]=="HEADLESS-1" and s["noticeOutput"]=="HEADLESS-1" and len(p["grounds"])==1 and len(p["strips"])==1 and all(x["loaded"] and x["visible"] for x in p["grounds"]+p["strips"])'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-1"'
ipc close
wait_check 'not s["deckMapped"]'
shot 04-single-output
alive || fail "quickshell died"
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then fail "QML errors"; fi
echo 'multimonitor: ok'
