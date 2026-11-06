# shellcheck shell=bash
# Real input on production UI; observational probes in a disposable shell copy.
# WELCOME=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/welcome-ui.sh build/ci/welcome-ui
fail() { echo "FAIL: $*"; exit 1; }
# Audit the production shell's lifetime before stopping it (as smoke.sh and
# welcome.sh do); Qt's engine teardown is kept separately for reference.
cp "$OUT/qs.log" "$OUT/startup-qs.log"
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-teardown-qs.log"
cp -r "$SHELL_DIR" "$HOME/welcome-ui-shell"
SHELL_DIR="$HOME/welcome-ui-shell"
mkdir -p "$HOME/welcome-ui-bin" "$HOME/docs"
printf '# Getting started fixture\n' >"$HOME/docs/README.md"
cat >"$HOME/welcome-ui-bin/aerolith" <<'FAKE'
#!/usr/bin/env python3
import json,pathlib,sys,time
args=sys.argv[1:]
with open('/out/cli-calls.jsonl','a') as log: log.write(json.dumps(args)+'\n')
if args == ['doctor','--json']:
    time.sleep(.7)
    if pathlib.Path('/out/doctor-fail').exists():
        print('fixture diagnostics unavailable',file=sys.stderr); sys.exit(2)
    print(json.dumps({'checks':[{'name':'fixture','status':'ok','detail':'verified fixture'}]}))
elif args == ['status','--json'] or args[:1] == ['startup']:
    if pathlib.Path('/out/startup-unavailable').exists():
        print('fixture startup unavailable',file=sys.stderr); sys.exit(2)
    state=pathlib.Path('/out/startup-enabled')
    if args[:2] == ['startup','enable']: state.touch()
    if args[:2] == ['startup','disable']: state.unlink(missing_ok=True)
    enabled=state.exists()
    print(json.dumps({'startupState':{'method':'hyprland','enabled':enabled,'state':'enabled' if enabled else 'disabled','error':None}}))
elif args[:2] == ['themes','refresh']: print(json.dumps({'apps':[]}))
else: raise SystemExit('unexpected argv: '+repr(args))
FAKE
cat >"$HOME/welcome-ui-bin/xdg-open" <<'FAKE'
#!/usr/bin/env python3
import json,sys
open('/out/doc-open.json','w').write(json.dumps(sys.argv[1:]))
FAKE
chmod +x "$HOME/welcome-ui-bin/aerolith" "$HOME/welcome-ui-bin/xdg-open"
export PATH="$HOME/welcome-ui-bin:$PATH"
python3 - "$SHELL_DIR" "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1]); config=Path(sys.argv[2])
seed=json.loads(config.read_text()) if config.exists() else {}
seed.setdefault('theme',{}).update(density='standard',scheme='limb')
config.write_text(json.dumps(seed))
p=root/'core/Config.qml'; s=p.read_text().replace('    id: root\n','    id: root\n    property int testWrites: 0\n',1).replace('        onSaved: {','        onSaved: {\n            root.testWrites++;',1); p.write_text(s)
p=root/'shell.qml';s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
s=s.replace('        active: !!Ui.overlayScreen','        id: uiTestDeck\n        active: !!Ui.overlayScreen',1)
probe='''
    IpcHandler {
        target: "welcomeUiTest"
        function snapshot(): string {
            const parts = [];
            function walk(item, surface, ox, oy) {
                if (!item) return;
                if (item.objectName) {
                    const p = item.mapToItem(null,0,0);
                    parts.push({name:item.objectName,x:p.x+ox,y:p.y+oy,w:item.width,h:item.height,
                        surface:surface,visible:item.visible,enabled:item.enabled,focus:item.focus,activeFocus:item.activeFocus,
                        text:item.text === undefined ? "" : item.text});
                }
                for (const child of item.children || []) walk(child,surface,ox,oy);
            }
            const welcome = welcomeSurface.item, deck = uiTestDeck.item;
            if (welcome) walk(welcome.contentItem,"welcome",(welcome.screen.width-welcome.width)/2,(welcome.screen.height-welcome.height)/2);
            if (deck) walk(deck.contentItem,"deck",0,0);
            return JSON.stringify({parts:parts,welcome:Welcome.active,primary:Displays.primary ? Displays.primary.name : "",
                output:welcome && welcome.screen ? welcome.screen.name : (deck && deck.screen ? deck.screen.name : "HEADLESS-1"),
                window:welcome ? {w:welcome.width,h:welcome.height,bg:String(welcome.color),profile:welcome.profile.profile} : null,
                checklist:Welcome.checklist,startup:Welcome.startup,diagnostics:Welcome.diagnostics,
                tour:Tour.active,bay:Ui.activeBay,active:Config.previewActive,dirty:Config.previewDirty,applying:Config.previewApplying,
                writes:Config.testWrites,data:Config.data,committed:Config.committedData,presets:Presets.list(),presetsReady:Presets.ready,
                error:Config.previewError});
        }
        function reveal(encoded: string): void {
            const names = JSON.parse(Qt.atob(encoded));
            function find(item,name) {
                if (!item) return null;
                if (item.objectName === name && item.visible) return item;
                for (const child of item.children || []) { const result = find(child,name); if (result) return result; }
                return null;
            }
            for (const name of names) {
                const root = Welcome.active && welcomeSurface.item ? welcomeSurface.item.contentItem : uiTestDeck.item ? uiTestDeck.item.contentItem : null;
                const item = find(root,name);
                if (!item) continue;
                let parent = item.parent;
                while (parent && parent.objectName !== "welcomeScroll" && parent.objectName !== "personalizeScroll") parent = parent.parent;
                if (parent) {
                    const point = item.mapToItem(parent.contentItem,0,0);
                    parent.contentY = Math.max(0,Math.min(parent.contentHeight-parent.height,point.y));
                }
            }
        }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!; PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call welcomeUiTest "$@"; }
b64() { printf %s "$1" | base64 -w0; }
snapshot() { probe snapshot >"$OUT/ui.json"; }
check() {
  for _ in $(seq 80); do
    if snapshot 2>/dev/null && python3 - "$OUT/ui.json" "$1" <<'PY' 2>"$OUT/check-error.txt"
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2]), {k:s[k] for k in ('welcome','bay','active','dirty','writes','error')}
PY
    then return 0; fi
    sleep .1
  done
  cat "$OUT/check-error.txt"; fail "$1"
}
ui_click() {
  probe reveal "$(b64 "[\"$1\"]")"
  sleep .3
  snapshot
  local point cx cy output
  point=$(python3 - "$OUT/ui.json" "$1" "$SCALE" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); p=next(p for p in s['parts'] if p['name']==sys.argv[2] and p['visible']); assert p['enabled'],p
scale=float(sys.argv[3]); print(round((p['x']+p['w']/2)*scale),round((p['y']+p['h']/2)*scale))
PY
  ) || fail "No clickable $1"
  read -r cx cy <<<"$point"
  output=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["output"])' "$OUT/ui.json")
  swaymsg input type:pointer map_to_output "$output" >/dev/null
  click "$cx" "$cy"
}
# The headless seat can drop the first keys while focus moves (seen at 4K x1.5),
# so wait for focus, then retry until the field holds exactly the typed text.
# field_is NAME focus   -> the field has active focus
# field_is NAME text T  -> the field holds exactly T
field_is() {
  python3 - "$OUT/ui.json" "$@" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); p=next(p for p in s['parts'] if p['name']==sys.argv[2] and p['visible'])
assert p['activeFocus'] if sys.argv[3]=='focus' else p['text']==sys.argv[4], p
PY
}
ui_type() {
  local attempt
  for attempt in 1 2 3; do
    ui_click "$1"
    for _ in $(seq 30); do snapshot; field_is "$1" focus 2>/dev/null && break; sleep .1; done
    # One virtual keyboard for the whole edit: a new wtype device per call can
    # lose its first key while the seat re-enters the surface.
    wtype -k Shift_L -s 150 -M ctrl -k a -m ctrl -k BackSpace -- "$2"; sleep .3
    snapshot; field_is "$1" text "$2" 2>/dev/null && return 0
    echo "ui_type $1: attempt $attempt did not land; retrying"
  done
  fail "could not type into $1"
}
ui_shot() { snapshot; grim -o "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["output"])' "$OUT/ui.json")" "$OUT/$1.png"; }
section() {
  snapshot
  if python3 - "$OUT/ui.json" "$1" <<'PY' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert any(p['name']=='personalizeSection_'+sys.argv[2] and p['visible'] for p in s['parts'])
PY
  then ui_click "personalizeSection_$1"; else ui_click "personalizeCompactSection_$1"; fi
}
check 's["welcome"] and s["output"]==s["primary"] and not s["tour"] and s["presetsReady"]'
# Every service state is rendered truthfully, including unknown and attention.
check 'all(any(p["name"]=="welcomeCheck_"+c["id"] and p["visible"] and ({"passed":"Passed","attention":"Needs attention","unknown":"Unknown"}[c["state"]] in p["text"]) and c["label"] in p["text"] for p in s["parts"]) for c in s["checklist"])'
check 's["writes"]==0 and s["diagnostics"]["ok"] is None'
python3 - "$OUT/ui.json" "$RES" "$SCALE" <<'PYFIT'
import json,sys
s=json.load(open(sys.argv[1])); rw,rh=map(int,sys.argv[2].split('x')); scale=float(sys.argv[3]); width,height=rw/scale,rh/scale
for name in ('welcomeClose','welcomeShowStartup','welcomeStartUsing','welcomeScroll'):
 p=next(p for p in s['parts'] if p['name']==name and p['visible'])
 assert 0 <= p['x'] < p['x']+p['w'] <= width+1,(name,p,width)
 assert 0 <= p['y'] < p['y']+p['h'] <= height+1,(name,p,height)
PYFIT
ui_shot 01-welcome
# Keyboard traverses the header and activates Take tour.
key Tab
check 'any(p["name"]=="welcomeTakeTour" and p["focus"] for p in s["parts"])'
key Return
check 'not s["welcome"] and s["tour"]'
qs -p "$SHELL_DIR" ipc call tour skip
qs -p "$SHELL_DIR" ipc call welcome open
check 's["welcome"]'
ui_click welcomeStartUsing
check 'not s["welcome"] and not s["tour"]'
qs -p "$SHELL_DIR" ipc call welcome open
check 's["welcome"]'
ui_click welcomeShowStartup
check 's["data"]["welcome"]["showOnStartup"] and s["writes"]==1'
ui_click welcomeLaunchStartup
check 's["startup"]["enabled"] is True and s["writes"]==1'
ui_click welcomeRunDiagnostics
check 's["diagnostics"]["running"]'
check 'not s["diagnostics"]["running"] and s["diagnostics"]["ok"] is True'
ui_click welcomePreviewReport
check 'any(p["name"]=="welcomeReport" and "fixture: verified fixture" in p["text"] for p in s["parts"])'
ui_click welcomeCopyReport
ui_click welcomeDoc_readme
[ -f "$OUT/doc-open.json" ] || fail 'local docs did not open'
touch "$OUT/doctor-fail"
ui_click welcomeRunDiagnostics
check 'not s["diagnostics"]["running"] and s["diagnostics"]["ok"] is None and any(p["name"]=="welcomeDiagnosticsState" and "Unavailable" in p["text"] for p in s["parts"])'
python3 - "$OUT/cli-calls.jsonl" <<'PY'
import json,sys
calls=[json.loads(l) for l in open(sys.argv[1])]
assert calls.count(['doctor','--json'])==2,calls
assert len([c for c in calls if c[:2]==['startup','enable']])==1,calls
assert not any(c[:2]==['startup','disable'] for c in calls),calls
PY
key Escape
check 'not s["welcome"]'
# Welcome opens Settings explicitly in Personalize.
qs -p "$SHELL_DIR" ipc call welcome open
ui_click welcomePersonalize
check 's["bay"]=="settings" and s["active"] and not s["welcome"] and any(p["name"]=="personalizePane" and p["visible"] for p in s["parts"])'
section 5
ui_shot 02-presets
ui_click presetPreview_readable
check 's["dirty"] and s["data"]["theme"]["density"]=="comfortable" and s["committed"]["theme"]["density"]=="standard" and s["writes"]==1'
ui_click personalizeCancel
check 'not s["dirty"] and s["data"]["theme"]["density"]=="standard" and s["writes"]==1'
ui_click presetPreview_readable
ui_click personalizeApply
check 'not s["dirty"] and not s["applying"] and s["data"]["theme"]["density"]=="comfortable" and s["writes"]==2'
ui_type presetName 'My current desktop'
ui_click presetSave
check 'any(p["name"]=="My current desktop" and not p["builtin"] for p in s["presets"]) and s["writes"]==2'
user_id=$(python3 -c 'import json,sys;print(next(p["id"] for p in json.load(open(sys.argv[1]))["presets"] if p["name"]=="My current desktop"))' "$OUT/ui.json")
ui_click "presetRemove_$user_id"
check 'any(p["name"]=="presetRemoveConfirm" and p["visible"] for p in s["parts"])'
ui_click presetRemoveConfirm
check 'not any(p["name"]=="My current desktop" for p in s["presets"]) and s["writes"]==2'
printf '{"theme":{"notASetting":true}}' >"$OUT/invalid-preset.json"
ui_type presetPath "$OUT/invalid-preset.json"
ui_click presetImport
check 'any(p["name"]=="presetMessage" and "notASetting" in p["text"] for p in s["parts"]) and not s["dirty"] and s["writes"]==2'
# A valid import stays in memory, exports the draft, and Cancel restores it.
printf '{"formatVersion":1,"name":"Imported","values":{"theme":{"textSize":125}}}' >"$OUT/valid-preset.json"
ui_type presetPath "$OUT/valid-preset.json"
ui_click presetImport
check 's["dirty"] and s["data"]["theme"]["textSize"]==125 and s["writes"]==2'
printf '{"theme":{"palette":{"text":"#222222"}}}' >"$OUT/low-contrast-preset.json"
ui_type presetPath "$OUT/low-contrast-preset.json"
ui_click presetImport
check 's["dirty"] and s["data"]["theme"]["textSize"]==125 and "text" not in s["data"]["theme"]["palette"] and any(p["name"]=="presetMessage" and "requires 4.5:1" in p["text"] for p in s["parts"]) and s["writes"]==2'
ui_type presetPath "$OUT/exported-preset.json"
ui_click presetExport
check 'any(p["name"]=="presetMessage" and p["text"]=="Preset exported" for p in s["parts"])'
python3 - "$OUT/exported-preset.json" <<'PYEXPORT'
import json,sys
v=json.load(open(sys.argv[1])); assert v['formatVersion']==1 and v['values']['theme']['textSize']==125
assert set(v['values']) <= {'theme','strip','ground','workspaces'}
PYEXPORT
ui_click personalizeCancel
check 'not s["dirty"] and s["data"]["theme"]["textSize"]==100 and s["writes"]==2'
# Terra controls use the schema transaction, never an independent model.
section 1
ui_click personalizeField_theme.textSize
key Right
check 's["data"]["theme"]["textSize"]==112 and s["dirty"] and s["writes"]==2'
ui_click personalizeCancel
section 4
ui_click personalizeField_display_outputs_HEADLESS-1_blackBackground
key Space
check 's["data"]["display"]["outputs"]["HEADLESS-1"]["blackBackground"] and s["dirty"]'
ui_click personalizeCancel
section 3
probe reveal "$(b64 '["personalizeField_strip.showNetwork"]')"
sleep .3
ui_shot 03-strip-ground
probe reveal "$(b64 '["personalizeField_ground.showNowPlaying"]')"
sleep .3
ui_shot 03b-ground-widgets
ui_click personalizeField_strip.showNetwork
key Space
check 'not s["data"]["strip"]["showNetwork"] and s["dirty"]'
ui_click personalizeField_ground.showTelemetry
key Space
check 'not s["data"]["ground"]["showTelemetry"] and s["dirty"]'
ui_type workspaceName_1 'Writing'
key Return
check 's["data"]["workspaces"]["names"]["1"]=="Writing" and s["writes"]==2'
# Actual host bay switch retains the dirty editor and offers all three choices.
ipc open systems >/dev/null
check 's["bay"]=="settings" and s["dirty"] and all(any(p["name"]==name and p["visible"] for p in s["parts"]) for name in ("personalizeLeaveApply","personalizeLeaveDiscard","personalizeKeepEditing"))'
ui_shot 04-deck-dirty-leave
ui_click personalizeKeepEditing
check 's["bay"]=="settings" and s["dirty"] and s["data"]["workspaces"]["names"]["1"]=="Writing" and not any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
ipc open systems >/dev/null
ui_click personalizeLeaveDiscard
check 's["bay"]=="systems" and not s["active"] and not s["dirty"] and s["writes"]==2'
ipc open settings >/dev/null
section 5
ui_click presetPreview_default
check 's["dirty"]'
ipc open systems >/dev/null
ui_click personalizeLeaveApply
check 's["bay"]=="systems" and not s["active"] and not s["dirty"] and not s["applying"] and s["writes"]==3'
# Closing the Deck also uses the owner adapter.
ipc open settings >/dev/null
section 5
ui_click presetPreview_readable
check 's["dirty"]'
ipc close >/dev/null
check 's["bay"]=="settings" and s["dirty"] and any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
ui_click personalizeLeaveDiscard
check 's["bay"]=="" and not s["active"] and s["writes"]==3'
# Nonallowlisted output permissions save normally and advertise that boundary.
ipc open settings >/dev/null
section 4
check 'any(p["name"]=="personalizeField_display_outputs_HEADLESS-1_strip" and p["visible"] for p in s["parts"])'
ui_click personalizeField_display_outputs_HEADLESS-1_strip
key Space
check 'not s["data"]["display"]["outputs"]["HEADLESS-1"]["strip"] and not s["dirty"] and s["writes"]==4'
ipc close >/dev/null
check 's["bay"]=="" and not s["active"]'
# An unavailable startup adapter is unknown, never a passing checklist row.
touch "$OUT/startup-unavailable"
qs -p "$SHELL_DIR" ipc call welcome open
check 's["welcome"] and s["startup"]["enabled"] is None and any(p["name"]=="welcomeCheck_startup" and "Unknown" in p["text"] for p in s["parts"]) and any(p["name"]=="welcomeLaunchStartup" and not p["enabled"] and "Unavailable" in p["text"] for p in s["parts"]) and s["writes"]==4'
ui_click welcomeCheckAction_startup
check 'all(a["y"] >= v["y"]-1 and a["y"]+a["h"] <= v["y"]+v["h"]+1 for a in s["parts"] if a["name"]=="welcomeStartupState" for v in s["parts"] if v["name"]=="welcomeScroll")'
key Escape
check 'not s["welcome"]'
alive || fail 'quickshell died'
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log" "$OUT/startup-qs.log"; then fail 'QML errors'; fi
echo 'welcome-ui: ok (real input, first-run primary, truthful checklist, tour, separate startup actions, diagnostics, docs/report, Escape, presets and Terra controls, deferred Deck bay/close choices)'
