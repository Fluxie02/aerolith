# shellcheck shell=bash
# Event-driven scratch-space contract, including fullscreen and output routing.
# tools/headless/run.sh tests/scenarios/scratch.sh build/headless/scratch
# HYPR_MOCK_ARGS=--hyprlang runs the same contract in the legacy dialect.

# Direct protocol checks cover both parsers and exact events even though the
# live shell below uses only the selected dialect. No sockets/processes needed.
python3 - "$SRC/tools/mock-hyprland/mock_hyprland.py" <<'MOCK_CONTRACT'
import importlib.util, sys
spec = importlib.util.spec_from_file_location('scratch_mock', sys.argv[1])
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
for lua in (True, False):
    mock = module.Mock('', None, lua=lua)
    events = []
    mock.emit = lambda name, data: events.append((name, data))
    addr = mock.open_window('note', 'Parked', 1)
    move = (f'hl.dsp.window.move({{ workspace = "special:aerolith", follow = false, window = "address:{addr}" }})'
            if lua else 'movetoworkspacesilent special:aerolith')
    events.clear()
    assert mock.dispatch(move) == 'ok'
    wid = mock.state.clients[addr].workspace
    assert ('movewindow', f'{addr[2:]},special:aerolith') in events
    assert ('movewindowv2', f'{addr[2:]},{wid},special:aerolith') in events
    assert mock.state.active_ws == 1 and mock.state.active_addr != addr
    toggle = 'hl.dsp.workspace.toggle_special("aerolith")' if lua else 'togglespecialworkspace aerolith'
    for opened in (True, False):
        events.clear()
        assert mock.dispatch(toggle) == 'ok'
        special = mock.state.monitors_json()[0]['specialWorkspace']
        expected = {'id':wid, 'name':'special:aerolith'} if opened else {'id':0, 'name':''}
        assert special == expected
        assert ('activespecial', 'special:aerolith,DP-1' if opened else ',DP-1') in events
        assert ('activespecialv2', f'{wid},special:aerolith,DP-1' if opened else '0,,DP-1') in events
        assert mock.state.active_ws == 1
    mock.control({'op':'add_monitor', 'name':'HDMI-A-2'})
    focus = 'hl.dsp.focus({ monitor = "HDMI-A-2" })' if lua else 'focusmonitor HDMI-A-2'
    assert mock.dispatch(focus) == 'ok'
    assert mock.dispatch(toggle) == 'ok'
    monitors = mock.state.monitors_json()
    assert monitors[0]['specialWorkspace']['id'] == 0
    assert monitors[1]['specialWorkspace']['id'] == wid
    assert monitors[1]['focused']
    # Transfer a shown special workspace; there must never be two copies.
    mock.focus_monitor('DP-1')
    assert mock.dispatch(toggle) == 'ok'
    assert [m['specialWorkspace']['id'] for m in mock.state.monitors_json()] == [wid, 0]
    events.clear()
    assert mock.close_window(addr)
    assert ('closewindow', addr[2:]) in events
    assert ('activespecialv2', '0,,DP-1') in events
    assert mock.state.monitors_json()[0]['specialWorkspace']['id'] == 0
    assert mock.dispatch(toggle) == 'ok'  # Empty special workspaces stay hidden.
    assert mock.state.monitors_json()[0]['specialWorkspace']['id'] == 0
print('scratch mock protocol: both dialects passed')
MOCK_CONTRACT

fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-5}
  for _ in $(seq $((timeout * 10))); do
    [ "$(field "$name")" = "$want" ] && return 0
    sleep 0.1
  done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
addr() { python3 -c 'import json,sys; print(json.loads(sys.argv[1])["address"])' "$1"; }
hypr_dispatch() {
  python3 - "$1" <<'PY'
import os, socket, sys
with socket.socket(socket.AF_UNIX) as s:
    s.connect(os.path.join(os.environ['XDG_RUNTIME_DIR'], 'hypr', os.environ['HYPRLAND_INSTANCE_SIGNATURE'], '.socket.sock'))
    s.sendall(('dispatch ' + sys.argv[1]).encode())
    s.shutdown(socket.SHUT_WR)
    assert s.recv(65536).decode() == 'ok'
PY
}

# Add a read-only probe in a disposable copy to inspect the public list itself,
# rather than accepting a matching count with the wrong window or record shape.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/scratch-shell"
SHELL_DIR="$HOME/scratch-shell"
python3 - "$SHELL_DIR/modules/ControlSurface.qml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
probe = '''
        function scratchSnapshot(): string {
            const plain = w => ({ address:w.address, title:w.title, workspaceId:w.workspaceId,
                appId:w.appId, keys:Object.keys(w).sort() });
            return JSON.stringify({ scratch:Compositor.scratchWindows.map(plain),
                windows:Compositor.windows().map(plain), workspaces:Compositor.workspaces });
        }
'''
p.write_text(s.replace('        function status(): string {', probe + '\n        function status(): string {', 1))
PY
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
for _ in $(seq 50); do ipc status >"$OUT/start.json" 2>/dev/null && break; sleep 0.1; done
wait_field scratchOpen False || fail "scratch should start hidden"
wait_field scratchWindows 0 || fail "scratch should start empty"
ipc commands >"$OUT/commands.json"
python3 - "$OUT/commands.json" <<'PY'
import json, sys
commands = {c['id']:c for c in json.load(open(sys.argv[1]))}
assert {'scratch.toggle', 'scratch.park'} <= commands.keys()
assert commands['scratch.toggle']['params'] == commands['scratch.park']['params'] == []
PY

parked=$(addr "$(mock '{"op":"open","class":"scratch-note","title":"Park me","workspace":1}')")
wait_field activeWindow "Park me" || fail "test window was not focused"
ipc scratchPark >"$OUT/park-reply.txt"
wait_field scratchWindows 1 || fail "parking did not update scratchWindows"
[ "$(field scratchOpen)" = False ] || fail "parking opened the scratch space"
[ "$(field focusedWorkspace)" = 1 ] || fail "parking followed the window"
[ "$(field activeWindow)" != "Park me" ] || fail "parked window retained focus"
ipc scratchSnapshot >"$OUT/parked.json"
mock '{"op":"state"}' >"$OUT/parked-mock.json"
python3 - "$OUT/parked.json" "$OUT/parked-mock.json" "$parked" <<'PY'
import json, sys
d, state = (json.load(open(p)) for p in sys.argv[1:3])
window = next(c for c in state['clients'] if c['address'] == sys.argv[3])
assert window['workspace']['name'] == 'special:aerolith' and window['workspace']['id'] < 0
scratch = d['scratch']
assert len(scratch) == 1 and scratch[0]['title'] == 'Park me', d
assert scratch[0] == next(w for w in d['windows'] if w['title'] == 'Park me'), d
assert all(w['workspaceId'] != 1 for w in scratch), d
assert next(w for w in d['workspaces'] if w['id'] == 1)['windows'] == 1, d
PY

ipc scratch >/dev/null
wait_field scratchOpen True || fail "toggle did not show scratch"
wait_field activeWindow "Park me" || fail "shown scratch did not focus its window"
ipc scratch >/dev/null
wait_field scratchOpen False || fail "toggle did not hide scratch"
wait_field scratchWindows 1 || fail "hiding lost the parked window"

# External opens, moves and closes must update the list without a shell action.
special_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["scratch"][0]["workspaceId"])' "$OUT/parked.json")
other=$(addr "$(mock "{\"op\":\"open\",\"class\":\"scratch-other\",\"title\":\"Other parked\",\"workspace\":$special_id}")")
wait_field scratchWindows 2 || fail "openwindow did not refresh scratch"
ipc run window.move "{\"address\":\"$other\",\"workspace\":2,\"follow\":false}" >/dev/null
wait_field scratchWindows 1 || fail "movewindow out did not refresh scratch"
mock "{\"op\":\"close\",\"address\":\"$other\"}" >/dev/null
other=$(addr "$(mock "{\"op\":\"open\",\"class\":\"scratch-other\",\"title\":\"Close parked\",\"workspace\":$special_id}")")
wait_field scratchWindows 2 || fail "second open did not refresh scratch"
mock "{\"op\":\"close\",\"address\":\"$other\"}" >/dev/null
wait_field scratchWindows 1 || fail "closewindow did not refresh scratch"

# A special workspace overlays fullscreen: restore while shown, suspend again
# when hidden, then restore after the underlying fullscreen window exits.
game=$(addr "$(mock '{"op":"open","class":"scratch-game","title":"Scratch fullscreen","workspace":1}')")
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_field surfacesReleased True || fail "fullscreen did not release surfaces"
ipc scratch >/dev/null
wait_field scratchOpen True || fail "scratch did not open over fullscreen"
wait_field phase desktop || fail "shown scratch did not restore lifecycle"
[ "$(field surfacesReleased)" = False ] || fail "surfaces remained released with scratch shown"
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
sleep 0.6
[ "$(field phase)" = desktop ] || fail "fullscreen exit under scratch changed lifecycle"
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
sleep 0.6
[ "$(field phase)" = desktop ] || fail "fullscreen entry under scratch suspended the shell"
ipc scratch >/dev/null
wait_field surfacesReleased True || fail "hiding scratch did not suspend for fullscreen"
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_field phase desktop || fail "fullscreen exit did not restore"

# The shell uses the single monitor fallback (sway/Qt names HEADLESS-1 while
# the mock calls it DP-1). Align the mock name before adding another output.
# Change its name through the existing test control operations, then focus
# the second output and prove the command returns scratch to the shell output.
display=$(field display)
mock "{\"op\":\"add_monitor\",\"name\":\"$display\"}" >/dev/null
mock '{"op":"remove_monitor","name":"DP-1"}' >/dev/null
mock '{"op":"add_monitor","name":"HDMI-A-2"}' >/dev/null
sleep 0.5
if [ "$(field dialect)" = lua ]; then
  hypr_dispatch 'hl.dsp.focus({ monitor = "HDMI-A-2" })'
else
  hypr_dispatch 'focusmonitor HDMI-A-2'
fi
sleep 0.3
ipc scratch >/dev/null
wait_field scratchOpen True || fail "scratch did not open on the shell output"
mock '{"op":"state"}' >"$OUT/output-mock.json"
python3 - "$OUT/output-mock.json" "$display" <<'PY'
import json, sys
monitors = {m['name']:m for m in json.load(open(sys.argv[1]))['monitors']}
assert monitors[sys.argv[2]]['specialWorkspace']['name'] == 'special:aerolith', monitors
assert monitors[sys.argv[2]]['focused'] is True, monitors
assert monitors['HDMI-A-2']['specialWorkspace']['id'] == 0, monitors
PY
mock "{\"op\":\"close\",\"address\":\"$parked\"}" >/dev/null
wait_field scratchWindows 0 || fail "last parked close did not clear list"
wait_field scratchOpen False || fail "last parked close did not hide scratch"

ipc status >"$OUT/final.json"
alive || fail "quickshell died"
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
if grep -nE 'scratch\.(toggle|park): failed|Invalid dispatcher|lua dispatch not understood' "$OUT/qs.log"; then fail "scratch command failed"; fi
echo "scratch: ok"
