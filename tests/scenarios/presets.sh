# shellcheck shell=bash
# Service/transaction probes exist only in a throwaway shell copy. List arguments
# are base64, matching config.sh and avoiding qs ipc's list argument splitting.
fail() { echo "FAIL: $*"; exit 1; }
# Audit the production shell's lifetime before stopping it (as smoke.sh and
# welcome.sh do); Qt's engine teardown is kept separately for reference.
cp "$OUT/qs.log" "$OUT/startup-qs.log"
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-teardown-qs.log"
cp -r "$SHELL_DIR" "$HOME/presets-shell"
SHELL_DIR="$HOME/presets-shell"
python3 - "$SHELL_DIR" "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1]); config=Path(sys.argv[2])
config.write_text(json.dumps({'theme':{'scheme':'iris','density':'compact'}, 'future':{'keep':42}}))
p=root/'core/Config.qml'
s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport qs.services\n',1)
s=s.replace('    id: root\n','    id: root\n    property int testWrites: 0\n    property string testBackupAtWrite: ""\n',1)
s=s.replace('        onSaved: {','        onSaved: {\n            root.testWrites++;',1)
s=s.replace('        fresh.setText(writeText);','        root.testBackupAtWrite = Presets.lastBackup;\n        fresh.setText(writeText);',1)
p.write_text(s)
p=root/'shell.qml'
s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
probe='''
    property var presetResult: ({pending:false, error:""})
    property var backupRelease: null
    IpcHandler {
        target: "presetTest"
        function snapshot(): string {
            return JSON.stringify({ready:Presets.ready,busy:Presets.busy,error:Presets.error,list:Presets.list(),
                result:shell.presetResult,active:Config.previewActive,dirty:Config.previewDirty,
                applying:Config.previewApplying,previewError:Config.previewError,data:Config.data,
                writes:Config.testWrites,backup:Presets.lastBackup,backupAtWrite:Config.testBackupAtWrite,
                queued:Config.saves.length,phase:Config.savePhase,loaded:Config.loaded});
        }
        function invoke(action: string, encoded: string): void {
            const args = JSON.parse(Qt.atob(encoded));
            shell.presetResult = {pending:true,error:""};
            let result;
            switch (action) {
            case "preview": result = Presets.preview(args[0]); break;
            case "save": result = Presets.saveCurrent(args[0]); break;
            case "remove": result = Presets.remove(args[0]); break;
            case "import": result = Presets.importFile(args[0]); break;
            case "export": result = Presets.exportFile(args[0], args[1] === true); break;
            case "cancel": Config.cancelPreview(); result = ""; break;
            case "apply": result = Config.applyPreview(); break;
            case "draft": result = Config.setPreviewValues(args); break;
            case "holdBackup": Config.previewBeforeWrite = () => new Promise(resolve => shell.backupRelease = resolve); result = ""; break;
            case "releaseBackup": if (shell.backupRelease) shell.backupRelease(""); result = ""; break;
            default: result = "Unknown action";
            }
            Promise.resolve(result).then(message => shell.presetResult = {pending:false,error:message || ""},
                error => shell.presetResult = {pending:false,error:String(error)});
        }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call presetTest "$@"; }
b64() { printf %s "$1" | base64 -w0; }
check() {
  for _ in $(seq 80); do
    if probe snapshot >"$OUT/presets.json" 2>/dev/null && python3 - "$OUT/presets.json" "$1" <<'PY' 2>"$OUT/check-error.txt"
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2]), s
PY
    then return 0; fi
    sleep .1
  done
  cat "$OUT/check-error.txt"; fail "$1"
}
act() { probe invoke "$1" "$(b64 "${2:-[]}")"; check 'not s["result"]["pending"]'; }
check 's["ready"] and s["loaded"] and not s["busy"]'
config="$XDG_CONFIG_HOME/aerolith/config.json"
cp "$config" "$OUT/original.json"
# Built-ins preview the effective appearance, with no write; Cancel restores it.
act preview '["default"]'
check 's["active"] and s["dirty"] and s["data"]["theme"]["density"] == "standard" and s["writes"] == 0'
act cancel
check 'not s["active"] and s["data"]["theme"]["density"] == "compact" and s["data"]["theme"]["scheme"] == "iris"'
act preview '["readable"]'
check 's["data"]["theme"]["density"] == "comfortable" and s["data"]["theme"]["motion"] == "reduced" and s["writes"] == 0'
cmp "$config" "$OUT/original.json" || fail 'preview wrote config'
act save '["My readable"]'
check 'len(s["list"]) == 3 and s["writes"] == 0 and not s["result"]["error"]'
cp "$XDG_CONFIG_HOME/aerolith/presets.json" "$OUT/saved-presets.json"
act apply
check 'not s["active"] and not s["applying"] and s["writes"] == 1 and s["data"]["future"]["keep"] == 42'
# Saved preset is persistent, immutable built-ins cannot be removed.
act remove '["default"]'
check '"Only user" in s["result"]["error"] and len(s["list"]) == 3'
act preview '["default"]'; act cancel
id=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["list"][2]["id"])' "$OUT/presets.json")
act preview "[\"$id\"]"
check 's["data"]["theme"]["density"] == "comfortable" and not s["result"]["error"]'
act cancel
# Import refuses forbidden/unknown/invalid/oversized input without a draft or writes.
cp "$config" "$OUT/before-invalid.json"
python3 - "$OUT" <<'PY'
from pathlib import Path
import json,sys
out=Path(sys.argv[1])
for name,value in {'ai':{'ai':{}},'routines':{'routines':{}},'binds':{'binds':[]},
 'direction':{'direction':'thears'},'startup':{'startup':{}},'unknown':{'theme':{'typo':True}},
 'invalid':{'theme':{'uiScale':100}},'wildcard':{'display':{'outputs':{'*':{'profile':'oled'}}}},
 'future':{'formatVersion':2,'name':'Future','values':{'theme':{'motion':'off'}}}}.items():
 (out/(name+'.json')).write_text(json.dumps(value))
(out/'unsafe.json').write_text('{"theme":{"palette":{"__proto__":"#ffffff"}}}')
(out/'oversize.json').write_text(' '*65537)
(out/'broken.json').write_text('{broken')
PY
for name in ai routines binds direction startup unknown invalid wildcard future unsafe oversize broken; do
  act import "[\"$OUT/$name.json\"]"
  check 's["result"]["error"] and not s["active"] and s["writes"] == 1'
  cp "$OUT/presets.json" "$OUT/refused-$name.json"
done
cmp "$config" "$OUT/before-invalid.json" || fail 'refused import wrote config'
cmp "$XDG_CONFIG_HOME/aerolith/presets.json" "$OUT/saved-presets.json" || fail 'refused import wrote presets'
[ ! -e "$XDG_STATE_HOME/aerolith/backups" ] || fail 'preview/invalid import created backup'
# Valid imports preview; absent leaves and unrelated raw keys survive.
cat >"$OUT/valid.json" <<'JSON'
{"formatVersion":1,"name":"Imported","values":{"theme":{"scheme":"cinder"},"display":{"outputs":{"DP.1":{"profile":"oled"}}}}}
JSON
act import "[\"$OUT/valid.json\"]"
check 'not s["result"]["error"] and s["active"] and s["data"]["theme"]["scheme"] == "cinder" and s["data"]["display"]["outputs"]["DP.1"]["profile"] == "oled" and s["writes"] == 1'
cmp "$config" "$OUT/before-invalid.json" || fail 'valid import wrote before Apply'
# Portable export: only appearance, no output assignments or preserved future key.
act export "[\"$OUT/export.json\"]"
check 'not s["result"]["error"] and s["writes"] == 1'
python3 - "$OUT/export.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); assert p['formatVersion']==1
assert set(p['values']) <= {'theme','strip','ground','workspaces'}
assert p['values']['theme']['scheme']=='cinder'
PY
act export "[\"$OUT/export-specific.json\",true]"
python3 - "$OUT/export-specific.json" <<'PY'
import json,sys
v=json.load(open(sys.argv[1]))['values']['display']; assert set(v)=={'outputs'}; assert v['outputs']['DP.1']['profile']=='oled'
PY
# Export path aliases cannot overwrite configuration.
act export "[\"$XDG_CONFIG_HOME/aerolith/../aerolith/config.json\"]"
check 's["result"]["error"] and s["writes"] == 1'
cmp "$config" "$OUT/before-invalid.json" || fail 'export overwrote config'
# Cancel imports creates no backup. Re-import then Apply must back up first.
act cancel
[ ! -e "$XDG_STATE_HOME/aerolith/backups" ] || fail 'cancelled import created backup'
act import "[\"$OUT/valid.json\"]"
act apply
check 's["writes"] == 2 and not s["active"] and not s["applying"] and s["backup"] and s["backupAtWrite"] == s["backup"]'
backup=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["backup"])' "$OUT/presets.json")
cmp "$backup" "$OUT/before-invalid.json" || fail 'backup does not match config before Apply'
python3 - "$backup" "$config" <<'PY'
from pathlib import Path
import sys
b,c=map(Path,sys.argv[1:]); assert b.stat().st_mtime_ns <= c.stat().st_mtime_ns
assert b.name=='config.json' and b.parent.parent.name=='backups'
PY
# A failed backup refuses the write and leaves a retryable draft.
cat >"$OUT/second.json" <<'JSON'
{"theme":{"scheme":"iris"}}
JSON
cp "$config" "$OUT/before-backup-failure.json"
chmod 500 "$XDG_STATE_HOME/aerolith/backups"
act import "[\"$OUT/second.json\"]"; act apply
check 's["writes"] == 2 and s["active"] and not s["applying"] and "back up" in s["previewError"]'
cmp "$config" "$OUT/before-backup-failure.json" || fail 'backup failure wrote config'
chmod 700 "$XDG_STATE_HOME/aerolith/backups"
# Apply retries must also retry the backup and use a fresh collision-safe folder.
act apply
check 's["writes"] == 3 and not s["active"] and not s["applying"]'
[ "$(find "$XDG_STATE_HOME/aerolith/backups" -name config.json | wc -l)" = 2 ] || fail 'backup retry/collision count'
# Cancel while an asynchronous guard is pending must not submit a write.
act preview '["default"]'; act holdBackup; act apply
check 's["applying"] and s["phase"] == "writing"'
act cancel; act releaseBackup
check 'not s["active"] and not s["applying"] and s["queued"] == 0 and s["writes"] == 3'
act remove "[\"$id\"]"
check 'len(s["list"]) == 2 and not s["result"]["error"]'
# Read-only/corrupt user store is never replaced by a failed operation.
printf '{broken' >"$XDG_CONFIG_HOME/aerolith/presets.json"
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/presets-runtime-qs.log"
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!; PIDS+=("$QS_PID")
check 'not s["busy"] and s["error"] and not s["ready"]'
act save '["Refused"]'
check 's["result"]["error"]'
[ "$(cat "$XDG_CONFIG_HOME/aerolith/presets.json")" = '{broken' ] || fail 'corrupt store overwritten'
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log" "$OUT/startup-qs.log" "$OUT/presets-runtime-qs.log"; then fail 'QML errors'; fi
alive || fail 'quickshell died'
echo 'presets: ok'
