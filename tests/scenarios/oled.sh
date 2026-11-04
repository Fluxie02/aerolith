# shellcheck shell=bash
# OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh
# Probes/test overrides live only in a throwaway shell copy, never production IPC.
fail() { echo "FAIL: $*"; exit 1; }
[ "${OUTPUTS:-1}" = 2 ] || fail 'OLED scenario requires OUTPUTS=2'
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-qs.log"
cp -r "$SHELL_DIR" "$HOME/oled-shell"
SHELL_DIR="$HOME/oled-shell"
python3 - "$SHELL_DIR" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); p=root/'shell.qml'
s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
s=s.replace('model: Displays.groundScreens','id: oledGrounds\n        model: Displays.groundScreens')
s=s.replace('model: Displays.stripScreens','id: oledStrips\n        model: Displays.stripScreens')
s=s.replace('active: !!Ui.overlayScreen','id: oledDeck\n        active: !!Ui.overlayScreen')
s=s.replace('active: !!Ui.noticeScreen','id: oledNotices\n        active: !!Ui.noticeScreen')
s=s.replace('OsdHost {}','OsdHost { id: oledOsd }').replace('SessionHost {}','SessionHost { id: oledSession }')
probe='''
    IpcHandler {
        target: "oledTest"
        function activity(): void { Idle.testIdle = -1; }
        function idle(value: bool): void { Idle.testIdle = value ? 1 : 0; }
        function resume(): string {
            Idle.testIdle = 0;
            const surfaces = JSON.parse(snapshot());
            return JSON.stringify({ roots: surfaces.grounds.concat(surfaces.strips).map(w => w.opacity),
                ground: oledGrounds.instances.map(l => l.item.contentItem.children[0].children[0].opacity),
                tapes: surfaces.strips.map(w => w.parts.filter(c => c.type.indexOf("WorkspaceTape") === 0).map(c => c.opacity)) });
        }
        function notice(): void { Ui.notify("OLED profile check", "info", "Transient notice"); }
        function osd(): void { oledOsd.armed = true; oledOsd.show("volume"); }
        function dismiss(): void { Ui.sessionOpen = false; }
        function snapshot(): string {
            function children(item, found, opacity) {
                if (!item) return;
                opacity *= item.opacity === undefined ? 1 : item.opacity;
                const type = item.toString().split("(")[0];
                const required = ["Ground", "InstrumentField", "Instrumentation", "Hatch", "Counterphase", "Material", "WorkspaceOrbit", "NowPlaying", "AppContinuity", "AppGlyph", "WorkspaceTape", "Annunciator", "Bezel", "ChordSlot", "InstrumentTabs", "ScrollMark", "NoticeStack", "OsdView", "SessionView", "DeckView", "CommandCore", "ResultRow", "SpatialNavigator", "Sector", "SystemsBay", "CoreBus", "SignalRack", "DeviceRow", "StreamRow", "PlayerCard", "RoutineConsole", "HelpBay", "SettingsBay", "SettingControl", "SchemePicker", "Label", "KeyHint", "StatusLine", "Trace", "TapeGauge", "StripClock", "AiConsole"];
                if ((item.profile !== undefined && item.profile !== null) || required.indexOf(type.split("_QMLTYPE")[0]) >= 0)
                    found.push({ type: type, visible: item.visible, opacity: opacity,
                        color: item.color === undefined ? "" : String(item.color),
                        appLink: item.profile ? String(item.profile.appLink) : "",
                        time: item.timeText, seconds: item.seconds,
                        texts: type.indexOf("StripClock") === 0 ? item.children[0].children.map(t => ({text: t.text, color: String(t.color), opacity: t.opacity, visible: t.visible})) : [],
                        profile: item.profile ? (item.profile.profile || "standard-default") : "missing",
                        bg: item.profile ? String(item.profile.bg) : "", grid: item.profile ? String(item.profile.grid) : "" });
                for (const child of item.children || []) children(child, found, opacity);
            }
            function surface(w) {
                if (!w || !w.profile) return null;
                const parts = []; children(w.contentItem, parts, 1);
                const slot = w.slotA ? (w.slotA.current ? w.slotA : w.slotB) : null;
                return { output: w.screen ? w.screen.name : "", visible: w.visible,
                    bayType: slot && slot.item ? slot.item.toString().split("(")[0] : "",
                    bayReady: !!slot && !!slot.item, bay: slot ? slot.bay : "",
                    bayProfile: slot && slot.item && slot.item.profile ? (slot.item.profile.profile || "standard-default") : "missing",
                    profile: w.profile.profile, bg: String(w.profile.bg),
                    surface: String(w.profile.surface), grid: String(w.profile.grid),
                    textDim: String(w.profile.textDim), hide: w.profile.hideContent, decoration: w.profile.decorationOpacity, dimmed: w.profile.idleDimmed,
                    opacity: (w.dimItem || w.contentItem).opacity, frames: w.testFrames, parts: parts };
            }
            const extras = [surface(oledOsd.testWindow), surface(oledSession.testWindow)].filter(w => w !== null);
            return JSON.stringify({ timeout: Idle.timeout, idle: Idle.idle, fadeMs: Theme.normal, animates: Theme.animate,
                grounds: oledGrounds.instances.map(l => surface(l.item)),
                strips: oledStrips.instances.map(l => surface(l.item)),
                deck: surface(oledDeck.item), notices: surface(oledNotices.item), extras: extras });
        }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
# Observe lazy single-instance windows through a test-owned alias.
for name in ['osd/OsdHost','session/SessionHost']:
    q=root/('modules/'+name+'.qml'); code=q.read_text()
    code=code.replace('    id: host','    id: host\n    readonly property alias testWindow: oledWindowLoader.item',1)
    code=code.replace('    LazyLoader {','    LazyLoader {\n        id: oledWindowLoader',1)
    q.write_text(code)
# Count real scene-graph swaps without adding a production render callback.
for name,ident in [('ground/GroundSurface','ground'),('strip/FlightStrip','strip')]:
    q=root/('modules/'+name+'.qml'); code=q.read_text()
    code=code.replace('    id: '+ident+'\n','    id: '+ident+'''
    property int testFrames: 0
    Connections {
        target: '''+ident+'''.contentItem.Window.window
        function onFrameSwapped() { '''+ident+'''.testFrames++; }
    }
''',1)
    q.write_text(code)
# Sway versions without ext-idle-notify can exercise the SAME production
# bindings with this test-owned input. The scenario records any fallback.
p=root/'services/Idle.qml'; s=p.read_text().replace('id: root','id: root\n    property int testIdle: -1',1).replace('monitor.isIdle','(testIdle < 0 ? monitor.isIdle : testIdle === 1)'); p.write_text(s)
# Keep pixel comparisons independent of wall-clock minutes and live memory.
p=root/'components/Instrumentation.qml'; p.write_text(p.read_text().replace('Telemetry.cpu', '({total:null, cores:[]})').replace('readonly property string mem: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)', 'readonly property string mem: "50%"'))
# Freeze the clock display, while still checking its real precision policy.
p=root/'modules/strip/StripClock.qml'; p.write_text(p.read_text().replace('text: root.timeText','text: "12:34"').replace('text: root.dateText','text: "WED 04 NOV"'))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call oledTest "$@"; }
config() {
  # Only HEADLESS-2 opts in, and all changes use the real live config watcher.
  python3 - "$SRC/tests/fixtures/oled-config.json" "$XDG_CONFIG_HOME/aerolith/config.json" "$1" "${2:-0}" "${3:-true}" "${4:-off}" <<'PY'
import json,sys,os
fixture,path,profile,after,hide,motion=sys.argv[1:]
c=json.load(open(fixture)); c['display']['outputs']['HEADLESS-2']['profile']=profile
c['strip']['showSeconds']=True
c['display']['oled']['idleDimAfter']=int(after); c['display']['oled']['hideDecorationWhenIdle']=hide=='true'; c['theme']['motion']=motion
with open(path+'.tmp','w') as f: json.dump(c,f)
os.replace(path+'.tmp',path)
PY
}
check() {
  ipc status >"$OUT/status.json" 2>/dev/null && probe snapshot >"$OUT/profiles.json" 2>/dev/null &&
    python3 - "$OUT/status.json" "$OUT/profiles.json" "$1" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); p=json.load(open(sys.argv[2])); o={x['name']:x for x in s['outputs']}
g={x['output']:x for x in p['grounds'] if x}; t={x['output']:x for x in p['strips'] if x}
assert eval(sys.argv[3]), (sys.argv[3],s,p)
PY
}
wait_check() {
  for _ in $(seq 60); do
    if check "$1" 2>"$OUT/check-error.txt"; then return 0; fi
    sleep .1
  done
  cat "$OUT/check-error.txt" >&2
  fail "$1"
}
capture() {
  for n in 1 2; do
    grim -o "HEADLESS-$n" -s .5 "$OUT/$1-$n.png"
    grim -o "HEADLESS-$n" -t ppm "$OUT/$1-$n.ppm"
  done
}
config standard
wait_check 'len(g)==len(t)==2 and all(x["profile"]=="standard" and x["opacity"]==1 for x in list(g.values())+list(t.values())) and p["timeout"]==0'
sleep 1
capture standard
config oled
wait_check 'o["HEADLESS-2"]["profile"]=="oled" and not o["HEADLESS-2"]["idleDimmed"] and g["HEADLESS-2"]["bg"]==t["HEADLESS-2"]["bg"]=="#000000" and g["HEADLESS-1"]["profile"]=="standard"'
wait_check 'all(c["profile"]=="oled" for x in [g["HEADLESS-2"],t["HEADLESS-2"]] for c in x["parts"])'
sleep .3
capture oled
cmp "$OUT/standard-1.ppm" "$OUT/oled-1.ppm" || fail 'standard output pixels changed'
python3 - "$OUT/oled-2.ppm" "$OUT/standard-2.ppm" <<'PY'
import sys
# grim emits P6 RGB, no metadata or comments.
def pixels(path):
    with open(path,'rb') as f:
        assert f.readline().strip()==b'P6'; w,h=map(int,f.readline().split()); assert f.readline().strip()==b'255'
        data=f.read(); assert len(data)==w*h*3; return w,h,data
w,h,oled=pixels(sys.argv[1]); _,_,standard=pixels(sys.argv[2])
assert oled!=standard, 'OLED must change its own output'
# A blank corner stays true black; the corresponding standard pixel keeps Theme.bg.
i=(min(60,h-1)*w+2)*3
assert oled[i:i+3]==b'\0\0\0', oled[i:i+3]
assert standard[i:i+3]!=b'\0\0\0', standard[i:i+3]
PY
# Let the actual compositor deliver idle; only fall back if it cannot.
config oled 2
probe activity
click 2 60
sleep 3
if check 'p["idle"] and g["HEADLESS-2"]["dimmed"]'; then
  echo 'Wayland IdleMonitor delivered idle notifications' | tee "$OUT/idle-source.txt"
else
  echo 'Headless compositor did not deliver idle: disposable test hook drives production idle bindings' | tee "$OUT/idle-source.txt"
  probe idle true
fi
wait_check 'o["HEADLESS-2"]["idleDimmed"] and not o["HEADLESS-1"]["idleDimmed"] and g["HEADLESS-2"]["opacity"]==t["HEADLESS-2"]["opacity"]==1 and g["HEADLESS-2"]["decoration"]==0 and g["HEADLESS-1"]["opacity"]==t["HEADLESS-1"]["opacity"]==1'
wait_check 'g["HEADLESS-2"]["hide"] and all(not c["visible"] or c["opacity"]==0 for c in g["HEADLESS-2"]["parts"] if not c["type"].startswith("Ground"))'
wait_check 'all(not c["visible"] or c["opacity"]==0 for c in t["HEADLESS-2"]["parts"] if c["type"].startswith("WorkspaceTape"))'
wait_check 'any(c["type"].startswith("StripClock") and c["visible"] and c["opacity"]==1 and not c["seconds"] and c["texts"][-1]["color"]==t["HEADLESS-2"]["textDim"] and c["texts"][-1]["opacity"]==1 and c["texts"][0]["opacity"]==0 for c in t["HEADLESS-2"]["parts"])'
capture idle
cmp "$OUT/standard-1.ppm" "$OUT/idle-1.ppm" || fail 'LCD changed at OLED idle'
! cmp -s "$OUT/oled-2.ppm" "$OUT/idle-2.ppm" || fail 'OLED did not visibly dim'
cp "$OUT/profiles.json" "$OUT/idle-profiles.json"
probe snapshot >"$OUT/frames-before.json"
sleep 3
probe snapshot >"$OUT/frames-after.json"
python3 - "$OUT/frames-before.json" "$OUT/frames-after.json" <<'PYFRAME'
import json,sys
a,b=[json.load(open(p)) for p in sys.argv[1:]]
for kind in ['grounds','strips']:
    assert [x['frames'] for x in a[kind]]==[x['frames'] for x in b[kind]], (kind,a,b)
print('OLED/LCD idle: zero scene-graph swaps over 3s')
PYFRAME
# Real activity must restore immediately, including decoration. Hook fallback
# uses a test-owned input reset plus compositor activity, never production IPC.
probe activity
click 2 60
if ! check 'not p["idle"]' 2>/dev/null; then
  echo 'Virtual input did not resume the headless idle monitor; disposable test override tests resume bindings' | tee -a "$OUT/idle-source.txt"
  probe idle false
fi
wait_check 'not p["idle"] and g["HEADLESS-2"]["opacity"]==t["HEADLESS-2"]["opacity"]==1 and g["HEADLESS-2"]["decoration"]>0'
capture resumed
cmp "$OUT/oled-2.ppm" "$OUT/resumed-2.ppm" || fail 'OLED did not restore its exact pixels'
# Keeping decoration is independent of dimming; zero timeout restores both.
config oled 2 false
probe idle true
wait_check 'g["HEADLESS-2"]["opacity"]==1 and not g["HEADLESS-2"]["hide"] and g["HEADLESS-2"]["decoration"]==0.55*0.4'
wait_check 'any(c["type"].startswith("StripClock") and c["texts"][0]["opacity"]==1 and c["opacity"]==1 for c in t["HEADLESS-2"]["parts"])'
# Reduced motion uses its existing shorter fade. Interrupting the fade with
# activity must restore every root synchronously, without an upward fade.
config oled 2 true reduced
probe idle false
wait_check 'p["fadeMs"]==80 and p["animates"] and g["HEADLESS-2"]["opacity"]==1'
probe idle true
probe resume >"$OUT/immediate-resume.json"
python3 - "$OUT/immediate-resume.json" <<'PYRESUME'
import json,sys
p=json.load(open(sys.argv[1]))
assert p=={'roots':[1,1,1,1], 'ground':[1,1], 'tapes':[[1],[1]]}, ('activity must restore at once, including during a fade',p)
PYRESUME
config oled 0
wait_check 'p["timeout"]==0 and not p["idle"] and g["HEADLESS-2"]["opacity"]==1'
probe activity
# Single-instance surfaces follow placement live (no compositor lookup below
# their boundary). Exercise their actual components as well as the root.
mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null
ipc open command
wait_check 'p["deck"] and p["deck"]["visible"] and p["deck"]["profile"]=="oled" and p["deck"]["bg"]=="#000000"'
probe notice
wait_check 's["notices"]>0 and p["notices"]["profile"]=="oled"'
wait_check 'p["deck"]["bayReady"] and p["deck"]["bayProfile"]=="oled" and all(c["profile"]=="oled" for c in p["deck"]["parts"])'
capture deck-oled
# Every actual bay, including selected rows/inputs/nested instruments, follows
# the destination live. Keep a record of each interior for review.
for bay in command navigator systems signal routines help settings ai; do
  case "$bay" in
    command) bay_type=CommandCore;; navigator) bay_type=SpatialNavigator;;
    systems) bay_type=SystemsBay;; signal) bay_type=SignalRack;;
    routines) bay_type=RoutineConsole;; help) bay_type=HelpBay;;
    settings) bay_type=SettingsBay;; ai) bay_type="";; # inline console/fallback has an engine-generated class name
  esac
  ipc open "$bay"
  wait_check "p['deck'] and p['deck']['bayReady'] and p['deck']['bay']=='$bay' and p['deck']['bayType'].startswith('$bay_type') and p['deck']['bayProfile']=='oled' and all(c['profile']=='oled' for c in p['deck']['parts'])"
  probe snapshot >"$OUT/bay-$bay.json"
  capture "bay-$bay"
  mock '{"op":"focus_monitor","name":"HEADLESS-1"}' >/dev/null
  wait_check 'p["deck"]["profile"]=="standard" and all(c["profile"]=="standard" for c in p["deck"]["parts"])'
  mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null
  wait_check 'p["deck"]["profile"]=="oled" and all(c["profile"]=="oled" for c in p["deck"]["parts"])'
done
# Transient foregrounds and Deck retain full opacity while persistent content hides.
probe notice
wait_check 's["notices"]>0'
config oled 2
probe idle true
wait_check 'g["HEADLESS-2"]["hide"] and not p["deck"]["dimmed"] and p["deck"]["decoration"]==0.55 and p["deck"]["opacity"]==1 and not p["notices"]["dimmed"] and p["notices"]["opacity"]==1'
mock '{"op":"screencast","active":true,"owner":0}' >/dev/null
wait_check 'any(c["type"].startswith("Annunciator") and c["visible"] and c["opacity"]==1 for c in t["HEADLESS-2"]["parts"])'
mock '{"op":"screencast","active":false,"owner":0}' >/dev/null
probe idle false
config oled 0
mock '{"op":"focus_monitor","name":"HEADLESS-1"}' >/dev/null
wait_check 'p["deck"] and p["deck"]["profile"]=="standard"'
ipc close
mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null
probe osd
ipc session
wait_check 's["session"] and len(p["extras"])==2 and all(x["profile"]=="oled" and all(c["profile"]=="oled" for c in x["parts"]) for x in p["extras"])'
config oled 2
probe idle true
wait_check 'all(not x["dimmed"] and x["opacity"]==1 and x["decoration"]==0.55 for x in p["extras"])'
probe idle false
config oled 0
probe dismiss
ipc close
mock '{"op":"focus_monitor","name":"HEADLESS-1"}' >/dev/null
# A live profile toggle returns output 2 to exactly its standard pixels.
config standard
wait_check 'g["HEADLESS-2"]["profile"]==t["HEADLESS-2"]["profile"]=="standard" and not o["HEADLESS-2"]["idleDimmed"]'
# Notices expire naturally; avoid changing their lifecycle to take this shot.
sleep 5
capture restored
cmp "$OUT/standard-2.ppm" "$OUT/restored-2.ppm" || fail 'live standard restore differs'
alive || fail 'quickshell died'
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then fail 'QML errors'; fi
rm "$OUT/"*.ppm
echo 'oled: ok'
