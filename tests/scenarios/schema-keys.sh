# shellcheck shell=bash
# CONFIG may seed any valid fixture; all writes/probes stay in this container.
fail() { echo "FAIL: $*"; exit 1; }
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-qs.log"
cp -r "$SHELL_DIR" "$HOME/schema-keys-shell"
SHELL_DIR="$HOME/schema-keys-shell"
python3 - "$SHELL_DIR" "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
from pathlib import Path
import json,re,sys
root=Path(sys.argv[1]); config=Path(sys.argv[2])
seed=json.loads(config.read_text()) if config.exists() else {}
seed.setdefault('theme',{}).update(motion='off')
seed.setdefault('strip',{}).update(visible=True,telemetry='always')
seed.setdefault('ground',{})['enabled']=True
seed.setdefault('tour',{})['enabled']=False
seed.setdefault('display',{}).setdefault('outputs',{})['HEADLESS-1']={'profile':'standard'}
config.write_text(json.dumps(seed))
# Deterministic service fixtures, not visibility overrides in the consumers.
for file,props in {
 'Power.qml':{'hasBattery':('bool','true'),'batteryPercent':('real','root.testBattery'),'charging':('bool','false')},
 'Network.qml':{'available':('bool','true')},
 'Bluetooth.qml':{'_adapter':('var','({enabled:true,name:"Fixture",discovering:false,devices:{values:[]}})')},
 'Media.qml':{'players':('var','[{identity:"Fixture",trackTitle:"Fixture track",trackArtist:"Artist",trackArtUrl:"",isPlaying:true,canTogglePlaying:false,canGoNext:false}]')},
 'Notifications.qml':{'count':('int','1'),'enabled':('bool','true')},
 'Audio.qml':{'sourceMuted':('bool','true')},
 'Telemetry.qml':{'tempState':('string','root.testTempState')},
}.items():
 p=root/'services'/file;s=p.read_text()
 for name,(kind,value) in props.items():
  s,n=re.subn(r'(?:readonly )?property '+kind+' '+name+r': [^\n]+', 'readonly property '+kind+' '+name+': '+value,s,count=1)
  assert n,(file,name)
 if file=='Telemetry.qml':s=s.replace('    id: root','    id: root\n    property string testTempState: "unknown"',1)
 if file=='Power.qml':s=s.replace('    id: root','    id: root\n    property real testBattery: 70',1)
 p.write_text(s)
p=root/'services/Idle.qml';s=p.read_text().replace('    id: root','    id: root\n    property bool testIdle: false',1)
s,n=re.subn(r'readonly property bool idle: [^\n]+','readonly property bool idle: testIdle',s,count=1);assert n;p.write_text(s)
p=root/'shell.qml';s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
s=s.replace('model: Displays.groundScreens','id: schemaGrounds\n        model: Displays.groundScreens',1).replace('model: Displays.stripScreens','id: schemaStrips\n        model: Displays.stripScreens',1)
probe='''
    IpcHandler {
        target: "schemaTest"
        function preview(payload: string): string {
            if (!Config.previewActive) Config.beginPreview();
            return JSON.stringify(Config.setPreviewValues(JSON.parse(Qt.atob(payload))));
        }
        function cancel(): void { Config.cancelPreview(); }
        function warning(critical: bool): void {
            Power.testBattery = critical ? 5 : 70;
            Telemetry.testTempState = critical ? "critical" : "unknown";
            Compositor.screencastActive = true;
            Config.errors = [{path:"fixture",message:"fixture warning"}];
        }
        function idle(value: bool): void { Idle.testIdle = value; }
        function snapshot(): string {
            function visit(item, out) {
                if (!item) return;
                const type = item.toString().split("(")[0];
                out.push({type:type,name:item.objectName || "",visible:item.visible,
                    code:item.code === undefined ? "" : item.code,
                    text:item.text === undefined ? "" : item.text,
                    elide:item.elide === undefined ? -1 : item.elide,
                    format:item.textFormat === undefined ? -1 : item.textFormat,
                    font:item.font === undefined ? 0 : item.font.pixelSize,
                    id:item.workspaceId === undefined ? 0 : item.workspaceId,
                    h:item.height});
                for (const child of item.children || []) visit(child,out);
            }
            const strips = [], grounds = [];
            for (const l of schemaStrips.instances) if (l.item) {
                const w=l.item, parts=[];visit(w.contentItem,parts);
                strips.push({output:w.screen.name,height:w.height,parts:parts});
            }
            for (const l of schemaGrounds.instances) if (l.item) {
                const w=l.item,parts=[];visit(w.contentItem,parts);
                grounds.push({output:w.screen.name,bg:String(w.profile.bg),surface:String(w.profile.surface),
                    surface2:String(w.profile.surface2),profile:w.profile.profile,dim:w.profile.idleDimmed,
                    hide:w.profile.hideContent,decoration:w.profile.decorationOpacity,parts:parts});
            }
            return JSON.stringify({loaded:Config.loaded,errors:Config.errors,data:Config.data,dirty:Config.previewDirty,
                type:Theme.typography,pad:Theme.pad,gap:Theme.gap,unit:Theme.unit,scale:Theme.scale,
                anchors:{apps:Anchors.lookup("HEADLESS-1","apps"),ring:Anchors.lookup("HEADLESS-1","ring")},
                strips:strips,grounds:grounds});
        }
    }
'''
s=s.replace('    ControlSurface {}',probe+'\n    ControlSurface {}',1);p.write_text(s)
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!; PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call schemaTest "$@"; }
snapshot() { probe snapshot >"$OUT/schema-keys.json" 2>/dev/null; }
check() {
  local expression=$1
  for _ in $(seq 60); do
    if snapshot && python3 - "$OUT/schema-keys.json" "$expression" <<'PY' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2]),sys.argv[2]
PY
    then return; fi
    sleep .1
  done
  cp "$OUT/schema-keys.json" "$OUT/failure-snapshot.json"
  fail "$expression"
}
preview() { probe preview "$(printf %s "$1" | base64 -w0)" >"$OUT/preview-result.json"; python3 -c 'import json,sys; error=json.load(open(sys.argv[1])); assert error=="",error' "$OUT/preview-result.json" || fail "preview rejected"; }
check 's["loaded"] and s["strips"] and s["grounds"] and not s["errors"]'
sleep 1
snapshot
cp "$OUT/schema-keys.json" "$OUT/baseline.json"
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/config-before.json"
# Each font and text container responds; spacing and UI scale stay fixed.
for percent in 112 125 150; do
  preview "[{\"path\":\"theme.textSize\",\"value\":$percent}]"
  check "s['data']['theme']['textSize']==$percent and s['type']['factor']==$percent/100"
  python3 - "$OUT/baseline.json" "$OUT/schema-keys.json" "$percent" <<'PY'
import json,sys,math
b,s=map(lambda p:json.load(open(p)),sys.argv[1:3]);factor=int(sys.argv[3])/100
for k,v in b['type'].items():
 if k!='factor':assert s['type'][k]==math.floor(v*factor+.5),(k,s['type'][k],v)
for k in ['pad','gap','scale','unit']:assert s[k]==b[k],k
assert s['strips'][0]['height']==s['type']['stripHeight']
PY
 done
probe cancel
check 's["type"]["factor"]==1 and not s["dirty"]'
preview '[{"path":["display","outputs","HEADLESS-1","blackBackground"],"value":true}]'
check 's["grounds"][0]["bg"]=="#000000" and s["grounds"][0]["profile"]=="standard"'
probe idle true
check 'not s["grounds"][0]["dim"] and not s["grounds"][0]["hide"] and s["grounds"][0]["decoration"]==1'
python3 - "$OUT/baseline.json" "$OUT/schema-keys.json" <<'PY'
import json,sys
b,s=[json.load(open(p)) for p in sys.argv[1:]]
for k in ['surface','surface2']:assert s['grounds'][0][k]==b['grounds'][0][k]
PY
probe idle false
probe cancel
# Toggle each optional item separately; service fixtures ensure it was present.
for pair in 'Network:NETWORK' 'Bluetooth:BLUETOOTH' 'Media:▶' 'Audio:AUD' 'Battery:BAT' 'Notifications:NTF'; do
  setting=${pair%%:*}; code=${pair#*:}
  # Network's code depends on backend capability; inspect its stable object name.
  if [ "$setting" = Network ]; then selector='p["name"]=="networkIndicator"'; else selector="p['code']=='$code'"; fi
  check "any(p['visible'] for p in s['strips'][0]['parts'] if $selector)"
  preview "[{\"path\":\"strip.show$setting\",\"value\":false}]"
  check "any(not p['visible'] for p in s['strips'][0]['parts'] if $selector)"
  probe cancel
  check "any(p['visible'] for p in s['strips'][0]['parts'] if $selector)"
done
for pair in 'NowPlaying:groundNowPlaying' 'Telemetry:groundTelemetry' 'AppRegister:appBar'; do
  setting=${pair%%:*}; name=${pair#*:}
  check "any(p['visible'] for p in s['grounds'][0]['parts'] if p['name']=='$name')"
  preview "[{\"path\":\"ground.show$setting\",\"value\":false}]"
  check "any(not p['visible'] for p in s['grounds'][0]['parts'] if p['name']=='$name')"
  if [ "$setting" = AppRegister ]; then check 's["anchors"]["apps"] is None and s["anchors"]["ring"] is not None'; fi
  probe cancel
  check "any(p['visible'] for p in s['grounds'][0]['parts'] if p['name']=='$name')"
done
# Existing telemetry mode remains the single telemetry visibility policy.
# It is deliberately outside the appearance transaction; use CONFIG reload.
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json,sys
p=sys.argv[1];s=json.load(open(p));s['strip']['telemetry']='off';open(p,'w').write(json.dumps(s))
PY
check 'not any(p["visible"] for p in s["strips"][0]["parts"] if p["code"] in ["CPU","MEM","TMP"])'
probe warning true
check 'any(p["visible"] for p in s["strips"][0]["parts"] if p["code"]=="TMP")'
probe warning false
cp "$OUT/config-before.json" "$XDG_CONFIG_HOME/aerolith/config.json"
check 's["data"]["strip"]["telemetry"]=="always"'
preview '[{"path":"workspaces.names","value":{"1":"Writing <plain> and a long name","2":"Research"}}]'
check 'any(p["text"]=="Writing <plain> and a long name" and p["visible"] and p["elide"]==1 and p["format"]==0 for p in s["strips"][0]["parts"]) and any(p["text"]=="Writing <plain> and a long name" and p["visible"] and p["elide"]==1 and p["format"]==0 for p in s["grounds"][0]["parts"])'
check 'any(p["id"]==1 for p in s["grounds"][0]["parts"])'
shot schema-keys
probe cancel
# Hiding optional indicators must not suppress privacy or critical warnings.
preview '[{"path":"strip.showNetwork","value":false},{"path":"strip.showBluetooth","value":false},{"path":"strip.showMedia","value":false},{"path":"strip.showAudio","value":false},{"path":"strip.showBattery","value":false},{"path":"strip.showNotifications","value":false}]'
probe warning true
check 'all(any(p["visible"] for p in s["strips"][0]["parts"] if p["code"]==code) for code in ["● SHARE","CFG","BAT"])'
probe cancel
cmp "$OUT/config-before.json" "$XDG_CONFIG_HOME/aerolith/config.json" || fail 'preview wrote config'
alive || fail 'shell died'
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log" "$OUT/startup-qs.log"; then fail 'QML errors'; fi
echo 'schema-keys: ok'
