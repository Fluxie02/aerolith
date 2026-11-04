# Sourced in a throwaway container by tools/headless/run.sh. No host state.
fail() { echo "FAIL: $*"; exit 1; }
qs -p "$SHELL_DIR" ipc call tour skip >/dev/null
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/visual-shell"
SHELL_DIR="$HOME/visual-shell"
python3 "$SRC/docs/design/network-tour/fixture.py" "$SHELL_DIR"
# Reuse the reviewed mock definitions, without executing its scenario.
python3 - "$SRC/tests/scenarios/network.sh" "$OUT/mock.py" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().split('cat >"$OUT/network-mock.py" <<\'PY\'\n',1)[1].split('\nPY\n',1)[0]
# Add a secured unknown AP and a paired/battery device. No real credentials.
s=s.replace("('Strong',60)", "('Strong',60),('Studio locked',82),('Guest open',64)")
s=s.replace("strength,0))", "strength,1 if name == 'Studio locked' else 0))")
s=s.replace("bluez.AddDevice('hci0','AA:BB:CC:DD:EE:02','Alpha phone')", "phone = str(bluez.AddDevice('hci0','AA:BB:CC:DD:EE:02','Alpha phone'))\n    update('org.bluez',phone,'org.bluez.Device1',{'Paired':True})\n    dbus.Interface(b.get_object('org.bluez',device), MOCK_IFACE).AddProperties('org.bluez.Battery1', {'Percentage':dbus.Byte(76)})")
Path(sys.argv[2]).write_text(s)
PY
python3 "$OUT/mock.py" seed
if [ "${OUTPUTS:-1}" = 2 ]; then
  # Keep OLED visible for the capture and make it the primary tour destination.
  # These changes apply only to the disposable user's copy of the seed fixture.
  python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PYCONFIG'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]); c=json.loads(p.read_text())
c['display']['primary']='HEADLESS-2'; c['display']['oled']['idleDimAfter']=300
p.write_text(json.dumps(c))
PYCONFIG
fi
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!; PIDS+=("$QS_PID")
sleep 3
python3 "$OUT/mock.py" connect
sleep .3
probe() { qs -p "$SHELL_DIR" ipc call visualTest "$@"; }
snap() { probe snapshot >"$OUT/ui.json"; }
check() {
  for _ in $(seq 40); do
    snap
    if python3 - "$OUT/ui.json" "$1" <<'PY' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2],{}, {'s':s}),s
PY
    then return 0; fi
    sleep .1
  done
  cat "$OUT/ui.json"; caller 0; fail "$1"
}
# Real pointer clicks use measured logical target bounds; vp accepts physical.
click_part() {
  snap
  read -r cx cy < <(python3 - "$OUT/ui.json" "$1" "${SCALE:-1}" "${2:-HEADLESS-1}" "${OUTPUTS:-1}" "$RES" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); name=sys.argv[2]; scale=float(sys.argv[3]); output=sys.argv[4]
w=next(w for w in s['strips'] if w['output']==output)
parts=w['popup']['controls'] if w['popup'] and name not in ['networkIndicator','bluetoothIndicator'] else w['parts']
p=next(p for p in parts if p['name']==name and p['visible'])
print(round((p['x']+p['w']/2)*scale), round((p['y']+min(p['h'],64)/2)*scale))
PY
)
  if [ "${OUTPUTS:-1}" = 2 ]; then swaymsg input type:pointer map_to_output "${2:-HEADLESS-1}" >/dev/null; fi
  click "$cx" "$cy"
}
# OLED capture targets the second strip, while the tour remains on primary.
output=HEADLESS-1
[ "${OUTPUTS:-1}" = 2 ] && output=HEADLESS-2
check 's["scan"] == 0 and s["discovery"] == 0 and len(s["devices"]) == 2'
key Shift_L
sleep .2
shot 01-ethernet
python3 "$OUT/mock.py" wifi
python3 "$OUT/mock.py" unplug
sleep .5
shot 02-wifi
click_part networkIndicator "$output"
check 's["scan"] == 1 and any(w["popup"] for w in s["strips"]) and len(s["network"]) == 5'
check 'any(w["popup"] and w["popup"]["output"] == "'"$output"'" for w in s["strips"])'
shot 03-network
cp "$OUT/ui.json" "$OUT/network-ui.json"
click_part 'pickerRow-Studio locked' "$output"
typ 'example-only'
sleep .2
shot 04-password
check 'any(c["name"] == "networkPasswordInput" and c["length"] > 0 for w in s["strips"] if w["popup"] for c in w["popup"]["controls"])'
typed_length=$(python3 - "$OUT/ui.json" <<'PYLENGTH'
import json,sys
s=json.load(open(sys.argv[1])); print(next(c['length'] for w in s['strips'] if w['popup'] for c in w['popup']['controls'] if c['name']=='networkPasswordInput'))
PYLENGTH
)
python3 "$OUT/mock.py" signal
check 'any(c["name"] == "networkPasswordInput" and c["length"] == '"$typed_length"' for w in s["strips"] if w["popup"] for c in w["popup"]["controls"])'
# Esc must close even with a password field focused.
key Escape
check 's["scan"] == 0 and all(w["popup"] is None for w in s["strips"])'
click_part networkIndicator "$output"
check 's["scan"] == 1'
# Same indicator toggles closed through the outside catcher.
click_part networkIndicator "$output"
check 's["scan"] == 0'
click_part networkIndicator "$output"
sleep .7
key Down
sleep .2
key Return
sleep .5
key Escape
check 's["scan"] == 0'
click_part bluetoothIndicator "$output"
check 's["discovery"] == 1 and s["discovering"]'
shot 05-bluetooth
cp "$OUT/ui.json" "$OUT/bluetooth-ui.json"
click "$(( ${RES%x*} - 80 ))" "$(( ${RES#*x} - 80 ))"
check 's["discovery"] == 0 and not s["discovering"]'
# Every real tour step. Retry an injected key only if the state did not move.
# Software-rendered 4K surfaces may not have keyboard focus on their first frame.
tour_key() {
  local keyname=$1 want=$2
  for _ in $(seq 4); do
    sleep .6
    key "$keyname"
    sleep .4
    snap
    if python3 - "$OUT/ui.json" "$want" <<'PYTEST' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2],{}, {'s':s})
PYTEST
    then return 0; fi
  done
  fail "tour key $keyname: $want"
}
qs -p "$SHELL_DIR" ipc call tour start
for step in 0 1 2 3 4; do
  check "s[\"tour\"] is not None and s[\"tour\"][\"step\"] == $step"
  sleep .4
  shot "tour-$step"
  cp "$OUT/ui.json" "$OUT/tour-$step-ui.json"
  # Check bounds and target/card separation using actual rendered geometry.
  python3 - "$OUT/ui.json" "$RES" "$SCALE" <<'PYTEST'
import json,sys
s=json.load(open(sys.argv[1])); w,h=[int(x)/float(sys.argv[3]) for x in sys.argv[2].split('x')]
t=s['tour']; c=next(p for p in t['parts'] if p['name']=='tourCard'); r=t['target']
assert c['x']>=0 and c['y']>=0 and c['x']+c['w']<=w+1 and c['y']+c['h']<=h+1,c
assert c['x']+c['w']<=r['x'] or c['x']>=r['x']+r['width'] or c['y']+c['h']<=r['y'] or c['y']>=r['y']+r['height'], (c,r)
if t['step']==2:
    strip=next(w for w in s['strips'] if w['output']==t['output'])
    actual=next(p for p in strip['parts'] if p['name']=='stripSearchButton')
    assert abs(actual['x']-r['x'])<.5 and abs(actual['w']-r['width'])<.5,(actual,r)
PYTEST
  if [ "$step" = 4 ]; then tour_key Return 's["tour"] is None'
  else tour_key Return "s[\"tour\"] is not None and s[\"tour\"][\"step\"] == $((step+1))"; fi
done
# Reopen / Back / Esc, then verify the keyboard returns to ordinary UI.
qs -p "$SHELL_DIR" ipc call tour start
tour_key Right 's["tour"]["step"] == 1'
tour_key Left 's["tour"]["step"] == 0'
tour_key Escape 's["tour"] is None'
ipc open command
sleep .7
typ 'settings'
sleep .4
ipc status >"$OUT/after-tour.json"
ipc close
# Destroying an output with a picker open must release its demand too.
if [ "${OUTPUTS:-1}" = 2 ]; then
  for kind in network bluetooth; do
    probe picker HEADLESS-2 "$kind"
    if [ "$kind" = network ]; then check 's["scan"] == 1'; else check 's["discovery"] == 1'; fi
    swaymsg output HEADLESS-2 disable >/dev/null
    check 'len(s["strips"]) == 1 and s["scan"] == 0 and s["discovery"] == 0'
    swaymsg output HEADLESS-2 enable >/dev/null
    check 'len(s["strips"]) == 2'
  done
fi
# Missing radios are ordinary; removed backend devices hide both indicators.
python3 - "$OUT/mock-paths.json" <<'PY'
import dbus,json,sys
from dbusmock import MOCK_IFACE
p=json.load(open(sys.argv[1])); b=dbus.SystemBus()
n=dbus.Interface(b.get_object('org.freedesktop.NetworkManager','/org/freedesktop'),MOCK_IFACE)
manager=dbus.Interface(b.get_object('org.freedesktop.NetworkManager','/org/freedesktop/NetworkManager'),dbus.PROPERTIES_IFACE)
manager.Set('org.freedesktop.NetworkManager','Devices',dbus.Array([],signature='o'))
for path in [p['wifi'],p['wire']]:
    dbus.Interface(b.get_object('org.freedesktop.NetworkManager','/org/freedesktop/NetworkManager'),MOCK_IFACE).EmitSignal('org.freedesktop.NetworkManager','DeviceRemoved','o',[dbus.ObjectPath(path)])
dbus.Interface(b.get_object('org.bluez','/org/bluez'),'org.bluez.Mock').RemoveAdapterWithDevices('hci0')
PY
check 'not any(p["visible"] for w in s["strips"] for p in w["parts"] if p["name"] in ["networkIndicator","bluetoothIndicator"])'
shot 06-unavailable
if grep -nE 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|is not a type|Error loading QML' "$OUT/qs.log"; then fail 'QML runtime errors'; fi
echo 'visuals: ok (pointer, keyboard, demand, password, tour bounds and lifecycle)'
