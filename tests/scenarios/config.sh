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
p.write_text(p.read_text().replace('watchChanges: true', 'watchChanges: false'))
p = root/'shell.qml'
s = p.read_text().replace('import QtQuick\n', 'import QtQuick\nimport Quickshell.Io\n', 1)
probe = '''
    property var configFailures: []
    Connections {
        target: Config
        function onSaveFailed(message) { shell.configFailures = shell.configFailures.concat([message]); }
    }
    IpcHandler {
        target: "configTest"
        function snapshot(): string {
            return JSON.stringify({loaded: Config.loaded, raw: Config.raw, data: Config.data,
                queued: Config.saves.length, phase: Config.savePhase, failures: shell.configFailures});
        }
        function set(path: string, value: string): string { return Config.setValue(path, JSON.parse(value)); }
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
alive || fail 'quickshell died'
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then fail 'QML errors'; fi
echo 'config: ok (atomic replacement, queued saves, same-path conflict, invalid file, read/write failure recovery)'
