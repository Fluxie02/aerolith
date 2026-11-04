# shellcheck shell=bash
# OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh
fail() { echo "FAIL: $*"; exit 1; }
# Add read-only probes to a disposable shell. Observe real Variants/loader
# instances and mapped PanelWindows; policy/status alone cannot prove release.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-qs.log"
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
            function collect(item, found) {
                if (!item) return;
                if (item.outputName !== undefined && item.ambient !== undefined)
                    found.push({ type: item.toString().split("(")[0], output: item.outputName,
                        ambient: item.ambient, driving: item.driving, motionAllowed: item.motionAllowed });
                if (item.toString().indexOf("NoticeStack") === 0)
                    found.push({ type: "notices", visible: item.visible, content: item.hasContent });
                const children = item.children || [];
                for (let i = 0; i < children.length; i++) collect(children[i], found);
            }
            function contents(window) {
                const found = [];
                if (window) collect(window.contentItem, found);
                return found;
            }
            function surface(loader) {
                const w = loader.item;
                return { output: loader.modelData.name, loaded: w !== null,
                    visible: !!w && w.visible, screen: w && w.screen ? w.screen.name : "", consumers: contents(w) };
            }
            const deck = overlayLoader.item;
            const notices = noticeLoader.item;
            return JSON.stringify({ stripDemand: Telemetry.stripDemand, samples: Telemetry.samplesTaken,
                covered: Theme.coveredOutputs,
                notificationServer: Notifications.server !== null, popupHeld: Notifications.held, noticesInDeck: ShellState.noticesInDeck,
                deckContents: contents(deck),
                grounds: grounds.instances.map(surface),
                strips: strips.instances.map(surface),
                deck: deck && deck.visible && deck.screen ? deck.screen.name : "",
                notices: notices && notices.visible && notices.screen ? notices.screen.name : "" });
        }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
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
wait_check 'p["stripDemand"]==2 and s["telemetryIntervalMs"]==5000'
# Clear seeded clients so coverage can be exercised independently on each output.
mock '{"op":"state"}' | python3 -c 'import json,sys;print("\n".join(c["address"] for c in json.load(sys.stdin)["clients"]))' >"$OUT/seed-clients.txt"
while read -r address; do
  [ -z "$address" ] || mock "{\"op\":\"close\",\"address\":\"$address\"}" >/dev/null
done <"$OUT/seed-clients.txt"
# One singleton ticker: two strips must not double the sample frequency.
probe >"$OUT/samples-before.json"
sleep 5.3
probe >"$OUT/samples-after.json"
python3 - "$OUT/samples-before.json" "$OUT/samples-after.json" <<'PYCOUNT'
import json,sys
before,after=(json.load(open(p))['samples'] for p in sys.argv[1:])
assert 1 <= after-before <= 2, (before,after)
PYCOUNT
# Coverage holds the actual ambient consumers on one output, then the other.
for spec in 'HEADLESS-1:1' 'HEADLESS-2:4'; do
  output=${spec%:*}; workspace=${spec#*:}
  covered=$(mock "{\"op\":\"open\",\"class\":\"mm1b-cover\",\"title\":\"Cover\",\"workspace\":$workspace}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
  wait_check "all(len(x['consumers'])>=3 and all(c['ambient']==(x['output']!='$output') for c in x['consumers']) for x in p['grounds'])"
  mock "{\"op\":\"close\",\"address\":\"$covered\"}" >/dev/null
  wait_check "all(all(c['ambient'] for c in x['consumers']) for x in p['grounds'])"
done
shot 01-two-outputs
mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null
wait_check 'o["HEADLESS-2"]["focused"] and s["overlayOutput"]=="HEADLESS-2"'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-2"'
wait_check 'all(all(c.get("driving") is not False and c.get("motionAllowed") is not False for c in x["consumers"]) for x in p["grounds"] if x["output"]=="HEADLESS-1")'
shot 02-focused-overlay
ipc close
wait_check 'not s["deckMapped"]'
ipc run shell.notify '{"message":"Primary output notice"}' >/dev/null
wait_check 'p["notices"]=="HEADLESS-1"'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-2" and p["notices"]=="HEADLESS-1" and not p["noticesInDeck"] and any(c["type"]=="notices" and not c["visible"] for c in p["deckContents"])'
mock '{"op":"focus_monitor","name":"HEADLESS-1"}' >/dev/null
wait_check 'p["deck"]=="HEADLESS-1" and not p["notices"] and p["noticesInDeck"] and any(c["type"]=="notices" and c["visible"] for c in p["deckContents"])'
mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null
ipc close
wait_check 'not s["deckMapped"]'

# Second monitor's own workspace, not the primary's active workspace.
game=$(mock '{"op":"open","class":"mm1-game","title":"MM1 game","workspace":4}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_check 'o["HEADLESS-2"]["released"] and not o["HEADLESS-1"]["released"] and all(x["loaded"]==(x["output"]=="HEADLESS-1") for x in p["grounds"]+p["strips"])'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-2" and o["HEADLESS-2"]["released"]'
wait_check 'p["stripDemand"]==1 and not p["popupHeld"]'
# Changing noticesOn immediately retargets the expiry hold, independent of primary.
config '{"display":{"noticesOn":"HEADLESS-2"}}'
wait_check 'p["noticesInDeck"] and not p["popupHeld"]'
ipc close
wait_check 'p["popupHeld"]'
# Real notification lifetime: held while its output is released, then it
# gets its full time when notices move to a visible output.
config '{"display":{"noticesOn":"HEADLESS-2"},"notifications":{"server":true,"popupTimeoutMs":1000}}'
wait_check 'p["notificationServer"] and p["popupHeld"]'
python3 "$SRC/tools/headless/notify_client.py" --summary "Held on secondary" --wait 12 >"$OUT/held-notice.txt" 2>"$OUT/held-notice.log" &
PIDS+=("$!")
wait_check 's["popups"]==1'
sleep 1.3
wait_check 's["popups"]==1 and p["popupHeld"]'
config '{"notifications":{"server":true,"popupTimeoutMs":1000}}'
wait_check 'not p["popupHeld"] and s["popups"]==1'
wait_check 's["popups"]==0'
ipc open command >/dev/null
wait_check 'p["deck"]=="HEADLESS-2"'
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
wait_check "p['stripDemand']==1 and all(all(c['ambient'] for c in x['consumers']) for x in p['grounds'] if x['output']=='$second')"
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
config '{"display":{"outputs":{"HEADLESS-1":{"strip":false}}}}'
wait_check 'p["stripDemand"]==0 and s["telemetryIntervalMs"]==0 and len(p["strips"])==0'
sleep 0.2
probe >"$OUT/no-demand-before.json"
sleep 5.3
probe >"$OUT/no-demand-after.json"
python3 - "$OUT/no-demand-before.json" "$OUT/no-demand-after.json" <<'PYSTOP'
import json,sys
before,after=(json.load(open(p))['samples'] for p in sys.argv[1:])
assert after==before, (before,after)
PYSTOP
config '{}'
wait_check 'p["stripDemand"]==1 and s["telemetryIntervalMs"]==5000'
shot 04-single-output
alive || fail "quickshell died"
if grep -nEi 'dangling|destroyed screen|ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then fail "QML errors"; fi
echo 'multimonitor: ok'
