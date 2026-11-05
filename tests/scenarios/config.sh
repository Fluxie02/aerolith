# shellcheck shell=bash
# Real Config.setValue against CLI-style atomic replacement; probes only exist
# in a disposable shell copy. No production IPC is added.
fail() { echo "FAIL: $*"; exit 1; }
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-qs.log"
cp -r "$SHELL_DIR" "$HOME/config-shell"
SHELL_DIR="$HOME/config-shell"
python3 - "$SHELL_DIR" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
p = root/'core/Config.qml'
# Reproduce the documented missed-watch-event case deterministically.
config = p.read_text().replace('watchChanges: true', 'watchChanges: root.testWatch')
config = config.replace('    id: root\n', '    id: root\n    property bool testWatch: false\n    property int testWrites: 0\n', 1)
config = config.replace('        onSaved: {', '        onSaved: {\n            root.testWrites++;', 1)
p.write_text(config)
p = root/'shell.qml'
s = p.read_text().replace('import QtQuick\n', 'import QtQuick\nimport Quickshell.Io\nimport "modules/settings"\n', 1)
s = s.replace('model: Displays.stripScreens', 'id: configStrips\n        model: Displays.stripScreens', 1)
probe = '''
    SettingsBay { id: configSettings; visible: false; active: false }
    property var configFailures: []
    Connections {
        target: Config
        function onSaveFailed(message) { shell.configFailures = shell.configFailures.concat([message]); }
    }
    IpcHandler {
        target: "configTest"
        function snapshot(): string {
            return JSON.stringify({loaded: Config.loaded, raw: Config.raw, data: Config.data,
                queued: Config.saves.length, phase: Config.savePhase, failures: shell.configFailures,
                committed: Config.committedData, projected: Config.projectedData,
                active: Config.previewActive, dirty: Config.previewDirty, applying: Config.previewApplying,
                conflicts: Config.previewConflicts, previewError: Config.previewError, writes: Config.testWrites,
                theme: Theme.scheme, signal: String(Theme.signal), stripDemand: Telemetry.stripDemand,
                idleTimeout: Idle.timeout, server: Notifications.enabled,
                strips: configStrips.instances.map(loader => ({output: loader.modelData.name,
                    visible: !!loader.item && loader.item.visible, signal: loader.item ? String(loader.item.profile.signal) : ""})),
                appBusy: AppThemes.busy, appPending: AppThemes.pending});
        }
        function set(path: string, value: string): string { return Config.setValue(path, JSON.parse(value)); }
        function begin(): string { return Config.beginPreview(); }
        function draft(values: string): string { return Config.setPreviewValues(JSON.parse(Qt.atob(values))); }
        function batch(values: string): string { return Config.setValues(JSON.parse(Qt.atob(values))); }
        function apply(): string { return Config.applyPreview(); }
        function cancel(): void { Config.cancelPreview(); }
        function watch(): void { Config.testWatch = true; Config.reload(); }
        function lockPreview(): void { Ui.locked = true; Ui.locked = false; }
        function doubleStep(): void {
            const row = configSettings.rows.filter(r => r.path === "theme.density")[0];
            configSettings.change(row, 1);
            configSettings.change(row, 1);
        }
        function burst(): void {
            Config.setValue("theme.density", "compact");
            Config.setValue("theme.density", "comfortable");
            Config.setValue("strip.edge", "bottom");
        }
    }
'''
p.write_text(s.replace('    id: shell\n', '    id: shell\n'+probe, 1))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call configTest "$@"; }
# qs ipc splits a JSON list argument ("Too many arguments"), so list
# arguments travel base64-encoded and the probe decodes them with Qt.atob.
b64() { printf %s "$1" | base64 -w0; }
check_config() {
  for _ in $(seq 80); do
    if probe snapshot >"$OUT/config-probe.json" 2>/dev/null && python3 - "$OUT/config-probe.json" "$1" <<'PY' 2>"$OUT/config-check-error.txt"
import json,sys
s = json.load(open(sys.argv[1]))
assert eval(sys.argv[2]), s
PY
    then return 0; fi
    sleep .1
  done
  cat "$OUT/config-check-error.txt" >&2
  fail "$1"
}
replace_config() {
  python3 - "$SRC" "$XDG_CONFIG_HOME/aerolith/config.json" "$1" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1]+'/installer')
from aerolith_install.manifest import atomic_write
atomic_write(Path(sys.argv[2]), sys.argv[3])
PY
}
check_config 's["loaded"] and s["queued"] == 0'
# Atomic replacement while Config.raw remains stale (watcher disabled).
replace_config '{"theme":{"scheme":"cinder"},"future":{"preserve":[1,2]}}'
probe set theme.density '"compact"'
check_config 's["queued"] == 0 and s["data"]["theme"]["density"] == "compact" and s["data"]["theme"]["scheme"] == "cinder" and s["raw"]["future"] == {"preserve":[1,2]} and not s["failures"]'
probe burst
check_config 's["queued"] == 0 and s["data"]["theme"]["density"] == "comfortable" and s["data"]["strip"]["edge"] == "bottom" and s["data"]["theme"]["scheme"] == "cinder" and not s["failures"]'
# Same-path edits must refuse instead of silently clobbering the CLI's value.
replace_config '{"theme":{"scheme":"cinder","density":"compact"},"future":{"external":true}}'
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/conflict-before.json"
probe set theme.density '"standard"'
check_config 's["queued"] == 0 and len(s["failures"]) == 1 and "configuration changed at theme.density" in s["failures"][-1] and s["data"]["theme"]["density"] == "compact"'
cmp "$OUT/conflict-before.json" "$XDG_CONFIG_HOME/aerolith/config.json" || fail 'conflict changed disk'
failure_count=1
for text in '{broken' '[]' 'null'; do
  failure_count=$((failure_count + 1))
  replace_config "$text"
  cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/invalid-before.json"
  probe set strip.edge '"top"'
  check_config "s['queued'] == 0 and len(s['failures']) == $failure_count and 'fix it before saving settings' in s['failures'][-1]"
  cmp "$OUT/invalid-before.json" "$XDG_CONFIG_HOME/aerolith/config.json" || fail 'invalid file overwritten'
done
# Recover through another external replacement and preserve unknown data.
replace_config '{"theme":{"scheme":"cinder","density":"compact"},"future":42}'
probe set theme.density '"comfortable"'
check_config 's["queued"] == 0 and len(s["failures"]) == 5 and s["raw"]["future"] == 42'
# The first request adopts the restored path and reports a conflict; retry it.
probe set theme.density '"comfortable"'
check_config 's["queued"] == 0 and s["data"]["theme"]["density"] == "comfortable" and s["raw"]["future"] == 42'
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
assert s['theme']=={'scheme':'cinder','density':'comfortable'}, s
assert s['future']==42, s
PY
# Read failures must not be mistaken for a missing config, and failed atomic
# writes must drain the queue and retain the actual committed settings.
config_path="$XDG_CONFIG_HOME/aerolith/config.json"
cp "$config_path" "$OUT/io-before.json"
chmod 000 "$config_path"
probe set strip.edge '"top"'
check_config 's["queued"] == 0 and len(s["failures"]) == 6 and "Could not read" in s["failures"][-1]'
chmod 600 "$config_path"
cmp "$OUT/io-before.json" "$config_path" || fail 'read failure changed disk'
chmod 500 "$(dirname "$config_path")"
probe set strip.edge '"bottom"'
check_config 's["queued"] == 0 and len(s["failures"]) == 7 and "Could not write" in s["failures"][-1]'
chmod 700 "$(dirname "$config_path")"
cmp "$OUT/io-before.json" "$config_path" || fail 'write failure changed disk'
probe set strip.edge '"bottom"'
check_config 's["queued"] == 0 and s["data"]["strip"]["edge"] == "bottom" and s["data"]["theme"]["scheme"] == "cinder"'
# Two presses in the same QML event step through projected queued values.
probe doubleStep
check_config 's["queued"] == 0 and s["data"]["theme"]["density"] == "standard"'
# A rejected batch is all-or-nothing, even when its first leaf is valid.
cp "$config_path" "$OUT/batch-before.json"
error=$(probe batch "$(b64 '[{"path":"theme.scheme","value":"iris"},{"path":"strip.edge","value":"left"}]')")
[[ "$error" == *strip* ]] || fail 'invalid batch accepted'
cmp "$OUT/batch-before.json" "$config_path" || fail 'partial batch written'

# Every draft stays in memory; real Theme and both mapped output profiles see it.
check_config 'not s["appBusy"] and not s["appPending"]'
count_refreshes() { if [ -f "$OUT/app-theme-calls.jsonl" ]; then wc -l <"$OUT/app-theme-calls.jsonl"; else echo 0; fi; }
refreshes=$(count_refreshes)
cp "$config_path" "$OUT/preview-before.json"
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"iris"},{"path":"theme.density","value":"compact"},{"path":"strip.edge","value":"top"}]')"
check_config "s['active'] and s['dirty'] and s['queued'] == 0 and s['theme'] == 'iris' and s['committed']['theme']['scheme'] == 'cinder' and len(s['strips']) == ${OUTPUTS:-1} and all(o['visible'] and o['signal'] == s['signal'] for o in s['strips'])"
error=$(probe draft "$(b64 '[{"path":"notifications.server","value":true}]')")
[[ "$error" == *"not an appearance setting"* ]] || fail 'non-appearance preview accepted'
error=$(probe draft "$(b64 '[{"path":"theme.scheme","value":"invalid"}]')")
[[ "$error" == *"must be one of"* ]] || fail 'invalid preview accepted'
check_config 's["theme"] == "iris" and not s["server"]'
# Draft visibility/profile changes must not change external probe demand.
probe draft "$(b64 '[{"path":"strip.visible","value":false},{"path":["display","outputs","HEADLESS-1","profile"],"value":"oled"}]')"
check_config "not s['strips'] and s['stripDemand'] == ${OUTPUTS:-1} and s['idleTimeout'] == 0"
probe draft "$(b64 '[{"path":"strip.visible","value":true}]')"
check_config "len(s['strips']) == ${OUTPUTS:-1}"
sleep 2
[ "$(count_refreshes)" = "$refreshes" ] || fail 'draft refreshed app themes'
cmp "$OUT/preview-before.json" "$config_path" || fail 'draft reached disk'
probe cancel
check_config 'not s["active"] and not s["dirty"] and s["theme"] == "cinder" and s["data"]["theme"]["density"] == "standard" and s["data"]["strip"]["edge"] == "bottom"'
cmp "$OUT/preview-before.json" "$config_path" || fail 'cancel wrote disk'

# Apply a multi-leaf draft in ONE atomic write, rebased on an unseen CLI edit.
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"iris"},{"path":"strip.edge","value":"top"}]')"
replace_config '{"theme":{"scheme":"cinder","density":"comfortable"},"strip":{"edge":"bottom"},"future":{"cli":true}}'
probe snapshot >"$OUT/before-apply.json"
writes=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["writes"])' "$OUT/before-apply.json")
probe apply
check_config "s['queued'] == 0 and not s['active'] and not s['applying'] and s['writes'] == $((writes + 1)) and s['theme'] == 'iris' and s['data']['theme']['density'] == 'comfortable' and s['data']['strip']['edge'] == 'top' and s['raw']['future']['cli']"
python3 - "$config_path" <<'PYDISK'
import json,sys
s=json.load(open(sys.argv[1]))
assert s['theme'] == {'scheme':'iris', 'density':'comfortable'}, s
assert s['strip']['edge'] == 'top' and s['future'] == {'cli':True}, s
PYDISK
check_config 'not s["appBusy"] and not s["appPending"]'
if [ "${APP_THEMES:-0}" = 1 ]; then
  [ "$(count_refreshes)" = "$((refreshes + 1))" ] || fail 'Apply did not refresh app themes once'
fi

# A same-path CLI edit refuses the WHOLE Apply and retains the reviewable draft.
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"corona"},{"path":"strip.edge","value":"bottom"}]')"
replace_config '{"theme":{"scheme":"bathyal","density":"comfortable"},"strip":{"edge":"top"},"future":{"conflict":true}}'
cp "$config_path" "$OUT/preview-conflict.json"
probe apply
check_config 's["queued"] == 0 and s["active"] and not s["applying"] and s["theme"] == "corona" and s["committed"]["theme"]["scheme"] == "bathyal" and s["conflicts"] == ["theme.scheme"] and "theme.scheme" in s["previewError"]'
cmp "$OUT/preview-conflict.json" "$config_path" || fail 'conflicted Apply changed disk'
probe cancel
check_config 'not s["active"] and s["theme"] == "bathyal" and s["data"]["strip"]["edge"] == "top"'

# The live watcher updates the base and re-applies the draft, before Apply too.
probe watch
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"corona"}]')"
replace_config '{"theme":{"scheme":"bathyal","density":"compact"},"strip":{"clock":"12h"}}'
check_config 's["active"] and s["theme"] == "corona" and s["data"]["strip"]["clock"] == "12h" and s["data"]["theme"]["density"] == "compact" and not s["conflicts"]'
replace_config '{"theme":{"scheme":"vellum","density":"compact"},"strip":{"clock":"12h"}}'
check_config 's["active"] and s["theme"] == "corona" and s["committed"]["theme"]["scheme"] == "vellum" and s["conflicts"] == ["theme.scheme"]'
probe cancel
check_config 'not s["active"] and s["theme"] == "vellum" and s["data"]["strip"]["clock"] == "12h"'

# Failed Apply preserves the draft for retry; no partial batch escapes to disk.
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"iris"}]')"
cp "$config_path" "$OUT/failed-apply-before.json"
chmod 500 "$(dirname "$config_path")"
probe apply
check_config 's["queued"] == 0 and s["active"] and s["theme"] == "iris" and "Could not write" in s["previewError"]'
chmod 700 "$(dirname "$config_path")"
cmp "$OUT/failed-apply-before.json" "$config_path" || fail 'failed Apply changed disk'
probe cancel

# Lock and physical output loss discard an uncommitted transaction.
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"corona"}]')"
probe lockPreview
check_config 'not s["active"] and s["theme"] == "vellum"'
if [ "${OUTPUTS:-1}" = 2 ]; then
  probe begin
  probe draft "$(b64 '[{"path":"theme.scheme","value":"corona"}]')"
  swaymsg output HEADLESS-2 unplug >/dev/null
  mock '{"op":"remove_monitor","name":"HEADLESS-2"}' >/dev/null
  check_config 'not s["active"] and s["theme"] == "vellum" and len(s["strips"]) == 1'
fi

# Killing a shell with a dirty draft never persists it; a new process is clean.
cp "$config_path" "$OUT/crash-before.json"
probe begin
probe draft "$(b64 '[{"path":"theme.scheme","value":"corona"}]')"
check_config 's["active"] and s["theme"] == "corona"'
kill -KILL "$QS_PID"
wait "$QS_PID" || true
cmp "$OUT/crash-before.json" "$config_path" || fail 'crash wrote draft'
mv "$OUT/qs.log" "$OUT/transaction-qs.log"
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
check_config 's["loaded"] and not s["active"] and s["theme"] == "vellum"'
alive || fail 'quickshell died'
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log" "$OUT/transaction-qs.log"; then fail 'QML errors'; fi
echo 'config: ok (atomic batches, projected stepping, preview on all outputs, cancel, one-write Apply, rebase/conflict, watcher, side-effect isolation, failures, lock/output loss/crash discard)'
