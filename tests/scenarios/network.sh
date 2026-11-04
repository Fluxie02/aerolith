# shellcheck shell=bash
# NET=1: private dbusmock system bus. NET=0: absent optional backends.
fail() { echo "FAIL: $*"; exit 1; }
status_is() {
  ipc status >"$OUT/status.json"
  python3 - "$OUT/status.json" "$1" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert eval(sys.argv[2], {"__builtins__": {}}, {"s": s}), s
PY
}
wait_status() {
  for _ in $(seq 80); do if status_is "$1" 2>/dev/null; then return 0; fi; sleep 0.1; done
  status_is "$1" || fail "status did not converge: $1"
}
clean_log() {
  if grep -nE 'WARN.*scene|ERROR.*scene|ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign|Error loading|is not a type|Cannot assign' "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
  alive || fail "quickshell died"
}
wait_status 's["network"]["available"] == False and s["bluetooth"]["available"] == False'
if [ "${NET:-0}" != 1 ]; then
  status_is 's["network"] == {"available":False,"kind":"none","state":"unavailable","connectionName":"","signal":-1,"wifiEnabled":False,"networks":0} and s["bluetooth"] == {"available":False,"powered":False,"connectedCount":0,"devices":0}'
  ipc run network.wifi.toggle '{}' >/dev/null
  ipc run network.disconnect '{}' >/dev/null
  ipc run bluetooth.toggle '{}' >/dev/null
  wait_for_log 'network.wifi.toggle: failed:.*Network backend unavailable'
  wait_for_log 'bluetooth.toggle: failed:.*Bluetooth adapter unavailable'
  clean_log
  echo 'network NET=0: ok (optional backends absent)'
  return
fi

# Probe only in a disposable copy, as oled.sh/app-links.sh do. Production IPC
# exposes counts, never the network/device list or credentials.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/network-shell"
SHELL_DIR="$HOME/network-shell"
python3 "$SRC/docs/design/network-tour/fixture.py" "$SHELL_DIR" --behavior
source "$SRC/docs/design/network-tour/ui-input.sh"
python3 - "$SHELL_DIR/modules/ControlSurface.qml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
probe = '''
    IpcHandler {
        target: "network-test"
        function snapshot(): string {
            return JSON.stringify({networks:Network.networks, devices:Bluetooth.devices,
                scanning:Network._wifi.map(d => d.scannerEnabled), discovering:Bluetooth.discovering,
                online:Network.online, wifiAvailable:Network.wifiAvailable});
        }
        function demand(action: string): void {
            if (action === "acquire") { Network.requestScan(); Bluetooth.requestDiscovery(); }
            else { Network.releaseScan(); Bluetooth.releaseDiscovery(); }
        }
    }
'''
p.write_text(s.replace('    id: root\n', '    id: root\n' + probe, 1))
PY
probe() { qs -p "$SHELL_DIR" ipc call network-test "$@"; }
wait_probe() {
  for _ in $(seq 80); do
    if probe snapshot >"$OUT/probe.json" 2>/dev/null && python3 - "$OUT/probe.json" "$1" <<'PY' 2>/dev/null
import json,sys
p=json.load(open(sys.argv[1]))
assert eval(sys.argv[2], {"__builtins__":{}}, {"p":p}), p
PY
    then return 0; fi
    sleep 0.1
  done
  cat "$OUT/probe.json"
  fail "probe did not converge: $1"
}

cat >"$OUT/network-mock.py" <<'PY'
import dbus, json, os, sys
from dbusmock import MOCK_IFACE
b = dbus.SystemBus()
NM = 'org.freedesktop.NetworkManager'
NP = '/org/freedesktop/NetworkManager'
DI = NM + '.Device'
WI = DI + '.Wireless'
SI = NM + '.Settings'
AI = NM + '.AccessPoint'
BI = 'org.bluez.Adapter1'
nm = dbus.Interface(b.get_object(NM, '/org/freedesktop'), MOCK_IFACE)
bluez = dbus.Interface(b.get_object('org.bluez', '/org/bluez'), 'org.bluez.Mock')
def update(name, path, iface, props):
    # This dbusmock calls .conjugate() on ObjectPath in UpdateProperties;
    # Properties.Set emits the same change signal without that template bug.
    obj = dbus.Interface(b.get_object(name, path), dbus.PROPERTIES_IFACE)
    for key, value in props.items(): obj.Set(iface, key, value)
def connection(ident, kind, ssid=None):
    settings = {'connection':{'id':ident,'type':kind,'autoconnect':False}, 'ipv4':{'method':'auto'}, 'ipv6':{'method':'auto'}}
    if ssid is not None: settings['802-11-wireless']={'ssid':dbus.ByteArray(ssid.encode()), 'mode':'infrastructure'}
    return str(dbus.Interface(b.get_object(NM, NP+'/Settings'), SI).AddConnection(settings))
path = os.path.join(os.path.dirname(__file__), 'mock-paths.json')
op = sys.argv[1]
if op == 'seed':
    wifi = str(nm.AddWiFiDevice('wifi0','wlan0',30))
    # Extra properties used by modern NM clients, absent in the old template.
    dbus.Interface(b.get_object(NM,wifi), MOCK_IFACE).AddProperties(WI, {'ActiveAccessPoint':dbus.ObjectPath('/'), 'LastScan':dbus.Int64(-1)})
    dbus.Interface(b.get_object(NM,wifi), MOCK_IFACE).AddProperties(DI, {'HwAddress':'11:22:33:44:55:66', 'Autoconnect':False, 'InterfaceFlags':dbus.UInt32(3)})
    aps = {}
    for i,(name,strength) in enumerate([('Strong',90),('Known',20),('Active',45),('Strong',60)]):
        aps[str(i)] = str(nm.AddAccessPoint(wifi,'ap'+str(i),name,'00:11:22:33:44:%02d'%i,2,2412,54000,strength,0))
    known = connection('Known','802-11-wireless','Known')
    active = connection('Active','802-11-wireless','Active')
    update(NM,wifi,DI,{'AvailableConnections':dbus.Array([dbus.ObjectPath(known),dbus.ObjectPath(active)],signature='o')})
    wire = str(nm.AddEthernetDevice('wired0','eth0',30))
    dbus.Interface(b.get_object(NM,wire), MOCK_IFACE).AddProperties(DI, {'HwAddress':'78:DD:08:D2:3D:43', 'Autoconnect':False, 'InterfaceFlags':dbus.UInt32(65539)})
    wired = connection('Desk cable','802-3-ethernet')
    update(NM,wire,DI,{'AvailableConnections':dbus.Array([dbus.ObjectPath(wired)],signature='o')})
    update(NM,wire,DI+'.Wired',{'Carrier':True})
    wc = str(nm.AddActiveConnection([wire],wired,'/','wired',2))
    update(NM,wire,DI,{'ActiveConnection':dbus.ObjectPath(wc),'State':dbus.UInt32(100)})
    # The old NM template omits Device.Disconnect. Model its observable
    # device properties so the Registry action can be tested through D-Bus.
    for dev in [wifi, wire]:
        code = "self.Set('%s', 'State', dbus.UInt32(30)); self.Set('%s', 'ActiveConnection', dbus.ObjectPath('/'))" % (DI, DI)
        dbus.Interface(b.get_object(NM,dev), MOCK_IFACE).AddMethod(DI, 'Disconnect', '', '', code)
    adapter = str(bluez.AddAdapter('hci0','Test radio'))
    # The BlueZ template expects a filter before StartDiscovery.
    dbus.Interface(b.get_object('org.bluez',adapter), BI).SetDiscoveryFilter(dbus.Dictionary({},signature='sv'))
    device = str(bluez.AddDevice('hci0','AA:BB:CC:DD:EE:01','Test headphones'))
    bluez.AddDevice('hci0','AA:BB:CC:DD:EE:02','Alpha phone')
    json.dump(dict(wifi=wifi,wire=wire,active=active,ap=aps['2'],wc=wc,adapter=adapter,device=device),open(path,'w'))
else:
    p = json.load(open(path))
    if op == 'wifi':
        ac = str(nm.AddActiveConnection([p['wifi']],p['active'],p['ap'],'wifi',2))
        update(NM,p['wifi'],WI,{'ActiveAccessPoint':dbus.ObjectPath(p['ap'])})
        update(NM,p['wifi'],DI,{'ActiveConnection':dbus.ObjectPath(ac),'State':dbus.UInt32(100)})
        # Keep both active to verify ethernet priority before dropping the wire.
    elif op == 'unplug':
        nm.RemoveActiveConnection(p['wire'],p['wc'])
        update(NM,p['wire'],DI,{'ActiveConnection':dbus.ObjectPath('/'),'State':dbus.UInt32(30)})
    elif op == 'signal': update(NM,p['ap'],AI,{'Strength':dbus.Byte(72)})
    elif op == 'connect':
        dbus.Interface(b.get_object('org.bluez',p['device']),'org.bluez.Device1').Connect()
    elif op == 'secure':
        ap = str(nm.AddAccessPoint(p['wifi'],'secured','NB2 secured','00:11:22:33:44:99',2,2412,54000,82,264))
        # RSN advertises PSK + CCMP so Quickshell recognises WPA2-Personal.
        # The old template's profile builder only understands WpaFlags=256.
        update(NM,ap,AI,{'WpaFlags':dbus.UInt32(256)})
    elif op == 'psk-called':
        # Inspect the actual template call in memory. Never dump its arguments.
        calls = dbus.Interface(b.get_object(NM, NP), MOCK_IFACE).GetMethodCalls('AddAndActivateConnection')
        matches = [args for stamp,args in calls
                   if str(args[0].get('802-11-wireless-security',{}).get('psk','')) == sys.argv[2]]
        assert len(matches) == 1, 'expected exactly one activation carrying the test PSK'
        args = matches[0]
        assert str(args[1]) == p['wifi'] and str(args[2]).endswith('/secured')
        ssid = dbus.Interface(b.get_object(NM,args[2]),dbus.PROPERTIES_IFACE).Get(AI,'Ssid')
        assert bytes(ssid).decode() == 'NB2 secured'
        print('AddAndActivateConnection: exact PSK, SSID, device and AP verified (redacted)')
    elif op == 'discovery':
        actual = dbus.Interface(b.get_object('org.bluez',p['adapter']), dbus.PROPERTIES_IFACE).Get(BI,'Discovering')
        assert bool(actual) == (sys.argv[2] == 'true'), 'mock adapter discovery mismatch'
    elif op == 'remove-adapter': bluez.RemoveAdapterWithDevices('hci0')
    else: raise ValueError(op)
PY
python3 "$OUT/network-mock.py" seed
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
wait_status 's["network"]["available"] and s["network"]["kind"] == "ethernet" and s["network"]["state"] == "connected" and s["network"]["connectionName"] == "Desk cable" and s["network"]["signal"] == -1 and s["network"]["networks"] == 2 and s["bluetooth"]["available"] and s["bluetooth"]["devices"] == 2'
cp "$OUT/status.json" "$OUT/wired.json"
wait_probe 'p["scanning"] == [False] and p["discovering"] == False'
# Quickshell exposes unknown APs only while its scanner is enabled. Saved
# networks remain visible at rest. Simulate a picker for the full list.
probe demand acquire
wait_status 's["network"]["networks"] == 3'
wait_probe 'p["networks"][0]["name"] == "Active" and p["networks"][1]["name"] == "Known" and p["networks"][2]["name"] == "Strong" and p["networks"][2]["signal"] == 90 and p["scanning"] == [True] and p["discovering"] == True'
python3 "$OUT/network-mock.py" wifi
wait_status 's["network"]["kind"] == "ethernet"'
python3 "$OUT/network-mock.py" unplug
wait_status 's["network"]["kind"] == "wifi" and s["network"]["connectionName"] == "Active" and s["network"]["signal"] == 45'
python3 "$OUT/network-mock.py" signal
wait_status 's["network"]["signal"] == 72'
cp "$OUT/status.json" "$OUT/wifi.json"
wait_probe 'p["networks"][0]["connected"] and p["networks"][0]["name"] == "Active"'
probe demand release
wait_probe 'p["scanning"] == [False] and p["discovering"] == False'

ipc run network.wifi.toggle '{}' >/dev/null
wait_status 's["network"]["wifiEnabled"] == False'
ipc run network.wifi.toggle '{}' >/dev/null
wait_status 's["network"]["wifiEnabled"] == True'
ipc run bluetooth.toggle '{}' >/dev/null
wait_status 's["bluetooth"]["powered"] == False'
ipc run bluetooth.toggle '{}' >/dev/null
wait_status 's["bluetooth"]["powered"] == True'
python3 "$OUT/network-mock.py" connect
wait_status 's["bluetooth"]["connectedCount"] == 1'
wait_probe 'p["devices"][0]["name"] == "Test headphones" and p["devices"][0]["connected"]'

# Two consumers: first release keeps demand; last release stops it. Extra
# releases cannot go negative. No production picker or testing IPC is added.
probe demand acquire
probe demand acquire
wait_probe 'p["scanning"] == [True] and p["discovering"] == True'
probe demand release
wait_probe 'p["scanning"] == [True] and p["discovering"] == True'
probe demand release
probe demand release
wait_probe 'p["scanning"] == [False] and p["discovering"] == False'
cp "$OUT/probe.json" "$OUT/idle.json"

# Real picker lifetimes: creation/destruction, scan controller and mock radio.
# No direct picker setters or scan demand calls participate in these checks.
closed='s["scan"] == 0 and s["scanning"] == [False] and s["discovery"] == 0 and not s["discovering"] and all(w["popup"] is None for w in s["strips"])'
wait_ui "$closed"
for output in HEADLESS-1 $([ "${OUTPUTS:-1}" = 2 ] && echo HEADLESS-2); do
  for kind in network bluetooth; do
    if [ "$kind" = network ]; then
      opened='s["scan"] == 1 and s["scanning"] == [True]'
    else
      opened='s["discovery"] == 1 and s["discovering"]'
    fi
    opened="$opened and len([w for w in s[\"strips\"] if w[\"popup\"]]) == 1 and any(w[\"output\"] == \"$output\" and w[\"popup\"] and w[\"popup\"][\"output\"] == \"$output\" and w[\"popup\"][\"name\"] == \"${kind}Picker\" for w in s[\"strips\"])"
    ui_click "${kind}Indicator" "$output"
    wait_ui "$opened"
    if [ "$kind" = bluetooth ]; then python3 "$OUT/network-mock.py" discovery true; fi
    key Escape
    wait_ui "$closed"
    if [ "$kind" = bluetooth ]; then python3 "$OUT/network-mock.py" discovery false; fi
    ui_click "${kind}Indicator" "$output"
    wait_ui "$opened"
    ui_click "${kind}Indicator" "$output"
    wait_ui "$closed"
    ui_click "${kind}Indicator" "$output"
    wait_ui "$opened"
    ui_click pickerOutside "$output"
    wait_ui "$closed"
    ui_click "${kind}Indicator" "$output"
    wait_ui "$opened"
    ipc open command >/dev/null
    wait_status 's["deckMapped"]'
    wait_ui "$closed"
    ipc close >/dev/null
    wait_status 'not s["deckMapped"]'
  done
done
if [ "${OUTPUTS:-1}" != 2 ]; then echo 'SKIP: per-output picker placement (run with OUTPUTS=2)'; fi
echo 'SKIP: picker lock dismissal (requires LOCK=1/PAM fixture); Deck dismissal verified for both pickers'

# A new secured AP must prompt; real text/Enter must reach NM with that PSK.
python3 "$OUT/network-mock.py" secure
ui_click networkIndicator
wait_ui 's["scan"] == 1 and any(n["name"] == "NB2 secured" and n["secured"] and not n["known"] for n in s["network"])'
ui_click 'pickerRow-NB2 secured'
password_ready='any(c["name"] == "networkPasswordInput" and c["focus"] for w in s["strips"] if w["popup"] for c in w["popup"]["controls"])'
wait_ui "$password_ready"
test_psk='NB2-distinctive-psk-7193'
# Retyping is safe before submission; require the full length before Enter.
for _ in 1 2 3; do
  ui_click networkPasswordInput
  wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace -- "$test_psk"
  if ui_is 'any(c["name"] == "networkPasswordInput" and c["length"] == 24 for w in s["strips"] if w["popup"] for c in w["popup"]["controls"])'; then break; fi
done
wait_ui 'any(c["name"] == "networkPasswordInput" and c["length"] == 24 for w in s["strips"] if w["popup"] for c in w["popup"]["controls"])'
key Return
wait_ui 'all(c["name"] != "networkPasswordInput" and not (c["name"] == "networkPasswordRow" and c["loaded"]) for w in s["strips"] if w["popup"] for c in w["popup"]["controls"])'
python3 "$OUT/network-mock.py" psk-called "$test_psk" >"$OUT/psk-call.txt"
key Escape
wait_ui "$closed"

probe demand acquire
wait_probe 'p["scanning"] == [True] and p["discovering"] == True'
python3 "$OUT/network-mock.py" remove-adapter
wait_status 's["bluetooth"]["available"] == False and s["bluetooth"]["connectedCount"] == 0 and s["bluetooth"]["devices"] == 0'
probe demand release
wait_probe 'p["scanning"] == [False] and p["discovering"] == False and p["devices"] == []'
ipc run network.disconnect '{}' >/dev/null
wait_status 's["network"]["state"] == "disconnected" and s["network"]["kind"] == "none" and s["network"]["connectionName"] == "" and s["network"]["signal"] == -1'
ui_snapshot
probe snapshot >"$OUT/probe.json"
python3 - "$test_psk" "$OUT" "$XDG_STATE_HOME/aerolith" <<'PY'
from pathlib import Path
import sys
secret = sys.argv[1].encode(); out, state = map(Path, sys.argv[2:])
files = [out/'qs.log', out/'ui.json', out/'probe.json', *state.rglob('*')]
for path in files:
    if path.is_file():
        assert secret not in path.read_bytes(), f'test PSK leaked into {path.name}'
print('PSK absent from qs.log, probe snapshots and every shell state file')
PY
clean_log
echo 'network NET=1: ok (services, real picker input/lifetimes, Deck dismissal, PSK call and secrecy)'
