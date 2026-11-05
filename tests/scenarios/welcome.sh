# shellcheck shell=bash
# WELCOME=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/welcome.sh
# Every mutation is confined to the disposable container and shell copy.
fail() { echo "FAIL: $*"; exit 1; }
welcome() { qs -p "$SHELL_DIR" ipc call welcome "$@"; }
tour() { qs -p "$SHELL_DIR" ipc call tour "$@"; }
probe() { qs -p "$SHELL_DIR" ipc call welcomeProbe "$@"; }
life_start=1
check_life() {
  local end
  end=$(wc -l <"$OUT/qs.log")
  sed -n "${life_start},${end}p" "$OUT/qs.log" >>"$OUT/qs-lifetimes.log"
  # This case deliberately loads malformed state; its caught JSON warning is
  # expected. All QML engine/parser/binding errors remain fatal.
  if grep -vF '[aerolith:state] ignoring unreadable state file:' "$OUT/qs-lifetimes.log" | grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML'; then
    fail 'QML errors during a shell lifetime'
  fi
  alive || fail 'quickshell died'
}
stop_shell() { check_life; qs -p "$SHELL_DIR" kill; wait "$QS_PID" || true; }
start_shell() {
  life_start=$(( $(wc -l <"$OUT/qs.log") + 1 ))
  qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
  QS_PID=$!; PIDS+=("$QS_PID")
  for _ in $(seq 80); do welcome state >/dev/null 2>&1 && return 0; sleep .1; done
  fail 'Welcome IPC unavailable'
}
check() {
  welcome state >"$OUT/welcome.json" 2>/dev/null && tour state >"$OUT/tour.json" 2>/dev/null &&
  probe snapshot >"$OUT/probe.json" 2>/dev/null &&
  python3 - "$OUT" "$1" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
w, t, s = [json.loads((p / (name + '.json')).read_text()) for name in ('welcome', 'tour', 'probe')]
assert eval(sys.argv[2]), (sys.argv[2], w, t, s)
PY
}
wait_check() {
  for _ in $(seq 80); do
    if check "$1" 2>"$OUT/check-error.txt"; then return 0; fi
    sleep .1
  done
  cat "$OUT/check-error.txt" >&2
  fail "$1"
}
state_file="$XDG_STATE_HOME/aerolith/state.json"
config_file="$XDG_CONFIG_HOME/aerolith/config.json"
# Verify the production service's first lifetime before adding the probe.
for _ in $(seq 60); do welcome state >"$OUT/initial.json" 2>/dev/null && break; sleep .1; done
sleep .5
welcome state >"$OUT/initial.json"
python3 - "$OUT/initial.json" "$(tour state)" <<'PY'
import json, sys
w=json.load(open(sys.argv[1])); t=json.loads(sys.argv[2])
assert w['active'] and w['firstRunPending'] and not t['active'], (w,t)
assert w['diagnostics'] == {'running':False,'ok':None,'checks':[],'error':None}, w
PY
stop_shell
cp -r "$SHELL_DIR" "$HOME/welcome-shell"
SHELL_DIR="$HOME/welcome-shell"
# A tiny surface proves lifecycle/output gates. It is intentionally absent
# from production; round two supplies the real Welcome design.
python3 - "$SHELL_DIR/shell.qml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text().replace('import QtQuick\n', 'import QtQuick\nimport Quickshell.Io\nimport Quickshell.Wayland\n', 1)
probe='''
    LazyLoader {
        id: welcomeProbeSurface
        active: Welcome.active
        PanelWindow {
            screen: Welcome.output ? Welcome.output.screen : null
            visible: true
            implicitWidth: 2; implicitHeight: 2
            WlrLayershell.namespace: "aerolith-welcome"
            WlrLayershell.layer: WlrLayer.Overlay
        }
    }
    IpcHandler {
        target: "welcomeProbe"
        function snapshot(): string {
            const item = welcomeProbeSurface.item;
            return JSON.stringify({surface: !!item, mappedOutput: item && item.screen ? item.screen.name : null,
                primary: Displays.primary ? Displays.primary.name : null,
                focused: Displays.focused ? Displays.focused.name : null,
                outputs: Displays.outputs.map(o => o.name)});
        }
        function locked(value: bool): void { Ui.locked = value; }
        function launch(value: bool): void { Welcome.setLaunchOnStartup(value); }
        function doc(id: string): bool { return Welcome.openDoc(id); }
    }
'''
p.write_text(s.replace('    id: shell\n', '    id: shell\n'+probe, 1))
PY
# Installed doc bundle fixture, retaining nested relative paths.
mkdir -p "$HOME/docs/docs"
printf '# Fixture docs\n' >"$HOME/docs/README.md"
# Real argv path: count each doctor request, delay it to exercise overlap, and
# model explicit startup changes. No startup action is allowed on opening.
mkdir -p "$HOME/welcome-bin"
cat >"$HOME/welcome-bin/aerolith" <<'FAKE'
#!/usr/bin/env python3
import json, pathlib, sys, time
args=sys.argv[1:]
with open('/out/cli-calls.jsonl','a') as log: log.write(json.dumps(args)+'\n')
if args == ['doctor','--json']:
    time.sleep(.5)
    print(json.dumps({'checks':[{'name':'fixture','status':'ok','detail':'verified fixture'}]}))
elif args == ['status','--json'] or args[:1] == ['startup']:
    state=pathlib.Path('/out/startup-enabled')
    if args[:2] == ['startup','enable']: state.touch()
    if args[:2] == ['startup','disable']: state.unlink(missing_ok=True)
    enabled=state.exists()
    print(json.dumps({'startupState':{'method':'hyprland','enabled':enabled,'state':'enabled' if enabled else 'disabled','error':None}}))
else:
    raise SystemExit('unexpected argv: '+repr(args))
FAKE
cat >"$HOME/welcome-bin/xdg-open" <<'OPEN'
#!/usr/bin/env python3
import json, sys
open('/out/doc-open.json','w').write(json.dumps(sys.argv[1:]))
OPEN
chmod +x "$HOME/welcome-bin/xdg-open" "$HOME/welcome-bin/aerolith"
export PATH="$HOME/welcome-bin:$PATH"
start_shell
wait_check 'w["active"] and w["firstRunPending"] and not t["active"] and s["surface"] and s["mappedOutput"] == s["primary"]'
cp "$OUT/welcome.json" "$OUT/fresh.json"
ipc commands >"$OUT/commands.json"
python3 - "$OUT/fresh.json" "$OUT/commands.json" <<'PYACTIONS'
import json, sys
w, commands = [json.load(open(p)) for p in sys.argv[1:]]
ids = {c['id'] for c in commands}
assert all(c['action'] in ids for c in w['checklist'] if c['id'] != 'startup'), w['checklist']
PYACTIONS
wait_check 'w["docs"][0]["available"] and not w["docs"][1]["available"]'
[ "$(probe doc missing)" = false ] || fail 'opened unknown docs'
[ "$(probe doc readme)" = true ] || fail 'did not open installed docs'
for _ in $(seq 40); do [ -f "$OUT/doc-open.json" ] && break; sleep .1; done
python3 - "$OUT/doc-open.json" "$HOME/docs/README.md" <<'PYDOC'
import json, pathlib, sys
assert [str(pathlib.Path(p).resolve()) for p in json.load(open(sys.argv[1]))] == [sys.argv[2]]
PYDOC
sleep .6
python3 - "$OUT/cli-calls.jsonl" <<'PY'
import json,sys
calls=[json.loads(l) for l in open(sys.argv[1])]
assert calls and all(c == ['status','--json'] for c in calls), calls
PY
welcome takeTour
wait_check 'not w["active"] and t["active"] and not s["surface"]'
tour next
# Handoff state retains the current step across an immediate shell restart.
stop_shell
start_shell
wait_check 'not w["active"] and t["active"] and t["step"] == 1'
for _ in $(seq 4); do tour next; done
wait_check 'w["active"] and not t["active"] and s["surface"] and w["checklist"][3]["state"] == "passed"'
welcome takeTour
wait_check 't["active"] and not w["active"]'
tour skip
wait_check 'not t["active"] and not w["active"] and not s["surface"] and w["checklist"][3]["state"] == "attention"'
# A fresh install dismissed without a tour must stay dismissed after restart.
stop_shell
rm -f "$state_file"
start_shell
wait_check 'w["active"] and not t["active"]'
welcome startUsing
wait_check 'not w["active"] and not t["active"]'
stop_shell
start_shell
sleep .8
wait_check 'not w["active"] and not w["firstRunPending"] and not t["active"] and not s["surface"]'
# A pre-Welcome state file is an upgrade, even with no tour record.
stop_shell
printf '{"version":1,"usage":{},"recent":[]}' >"$state_file"
start_shell
sleep .8
wait_check 'not w["active"] and not w["firstRunPending"] and not t["active"] and not s["surface"]'
tour skip
# Malformed existing state is also an upgrade; never overwrite it to onboard.
stop_shell
printf '{invalid' >"$state_file"
start_shell
sleep .8
wait_check 'not w["active"] and not w["firstRunPending"] and not t["active"]'
tour skip
# Startup preference is independent of shell autostart, and reopens each time.
stop_shell
printf '{"welcome":{"showOnStartup":true}}' >"$config_file"
printf '{"version":1,"tour":{"completed":true,"version":1}}' >"$state_file"
for _ in 1 2; do
  start_shell
  wait_check 'w["active"] and w["showOnStartup"] and not w["firstRunPending"] and not t["active"] and w["checklist"][3]["state"] == "unknown"'
  welcome startUsing
  wait_check 'not w["active"]'
  stop_shell
done
printf '{"welcome":{"showOnStartup":false}}' >"$config_file"
start_shell
sleep .7
wait_check 'not w["active"]'
# Manual command uses the focused output, including a non-primary output.
if [ "$OUTPUTS" -ge 2 ]; then mock '{"op":"focus_monitor","name":"HEADLESS-2"}' >/dev/null; fi
wait_check 's["focused"] == ("HEADLESS-2" if len(s["outputs"]) > 1 else s["primary"])'
ipc run welcome.open '{}'
wait_check 'w["active"] and s["surface"] and w["output"] == s["focused"] and s["mappedOutput"] == s["focused"]'
# Lock holds a requested Welcome, then restores it without another action.
probe locked true
wait_check 'not w["active"] and not s["surface"]'
probe locked false
wait_check 'w["active"] and s["surface"]'
# Fullscreen on the selected output holds both an open and a queued request.
game=$(mock '{"op":"open","class":"welcome-game","title":"Welcome hold","workspace":2}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["address"])')
mock '{"op":"focus_workspace","workspace":2}' >/dev/null
welcome open
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_check 'not w["active"] and not s["surface"]'
welcome close
welcome open
wait_check 'not w["active"] and not s["surface"]'
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_check 'w["active"] and s["surface"]'
# Still no doctor or startup mutation, despite all opens/restarts.
python3 - "$OUT/cli-calls.jsonl" <<'PY'
import json,sys
calls=[json.loads(l) for l in open(sys.argv[1])]
assert all(c == ['status','--json'] for c in calls), calls
PY
welcome runDiagnostics
welcome runDiagnostics
wait_check 'not w["diagnostics"]["running"] and w["diagnostics"]["ok"] is True'
welcome runDiagnostics
wait_check 'not w["diagnostics"]["running"] and w["diagnostics"]["ok"] is True'
python3 - "$OUT/cli-calls.jsonl" <<'PY'
import json,sys
calls=[json.loads(l) for l in open(sys.argv[1])]
assert calls.count(['doctor','--json']) == 2, calls
PY
probe launch true
wait_check 'w["startup"]["enabled"] is True and w["checklist"][2]["state"] == "passed"'
probe launch false
wait_check 'w["startup"]["enabled"] is False and w["checklist"][2]["state"] == "attention"'
welcome report >"$OUT/report.txt"
grep -q 'fixture: verified fixture' "$OUT/report.txt" || fail 'diagnostic report incomplete'
welcome startUsing
check_life
echo 'welcome: ok (fresh/upgrade, restart, handoff/resume/finish/skip, focused output, lock/fullscreen holds, diagnostics and explicit startup)'
