# shellcheck shell=bash
# Tour UI and state contract; TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh
# All config/state writes below belong to the disposable container user.

fail() { echo "FAIL: $*"; exit 1; }
tour() { qs -p "$SHELL_DIR" ipc call tour "$@"; }
tour_field() {
  python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$(tour state)" "$1"
}
wait_tour() {
  local name=$1 want=$2
  for _ in $(seq 60); do
    [ "$(tour_field "$name" 2>/dev/null)" = "$want" ] && return 0
    sleep 0.1
  done
  fail "tour.$name wanted $want; got $(tour state)"
}
assert_state() {
  tour state >"$OUT/tour-$1.json"
  python3 - "$OUT/tour-$1.json" "$2" <<'PY'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual == json.loads(sys.argv[2]), actual
PY
}
config_hash() {
  python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import hashlib, pathlib, sys
p = pathlib.Path(sys.argv[1])
print(hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else 'missing')
PY
}

# Check each live segment, excluding only the QML engine's teardown messages.
life_start=1
check_life() {
  local end
  end=$(wc -l <"$OUT/qs.log")
  sed -n "${life_start},${end}p" "$OUT/qs.log" >>"$OUT/qs-lifetimes.log"
  if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs-lifetimes.log"; then
    fail "QML errors during a shell lifetime"
  fi
  alive || fail "quickshell died"
}
stop_shell() {
  check_life
  qs -p "$SHELL_DIR" kill
  wait "$QS_PID" || true
}
start_shell() {
  life_start=$(( $(wc -l <"$OUT/qs.log") + 1 ))
  qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
  QS_PID=$!
  PIDS+=("$QS_PID")
  for _ in $(seq 60); do
    tour state >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  fail "tour IPC did not become ready"
}
state_file="$XDG_STATE_HOME/aerolith/state.json"
config_before=$(config_hash)
# Probe rendered objects only in a disposable copy, never production IPC.
stop_shell
cp -r "$SHELL_DIR" "$HOME/tour-shell"
SHELL_DIR="$HOME/tour-shell"
python3 "$SRC/docs/design/network-tour/fixture.py" "$SHELL_DIR" --behavior
source "$SRC/docs/design/network-tour/ui-input.sh"
start_shell
# Keep one idle virtual keyboard attached while probing focus. A one-shot
# wtype removes the seat's last keyboard on exit, making activeFocus false
# between injections even though the exclusive tour receives the next key.
wtype -k Shift_L -s 240000 &
PIDS+=($!)
wait_tour active True
assert_state fresh '{"active":true,"step":0,"stepId":"hatch","completed":false}'
surface_ready='s["tour"] is not None and s["tour"]["name"] == "tourHost" and s["tour"]["output"] == s["primaryOutput"] and any(p["focus"] for p in s["tour"]["parts"])'
wait_ui "$surface_ready"
cp "$OUT/ui.json" "$OUT/tour-focused.json"
# A real normal window waits behind the exclusive layer surface. Do not
# refocus it after dismissal: compositor focus must return there by itself.
foot --app-id=nb2-tour-input bash -c 'while IFS= read -r line; do printf "%s\n" "$line" >"$1"; done' -- "$OUT/normal-input.txt" >"$OUT/foot.log" 2>&1 &
PIDS+=($!)
foot_ready=0
for _ in $(seq 50); do
  if swaymsg -t get_tree | python3 -c 'import json,sys
def walk(n):
    yield n
    for c in n.get("nodes",[])+n.get("floating_nodes",[]): yield from walk(c)
assert any(n.get("app_id")=="nb2-tour-input" for n in walk(json.load(sys.stdin)))' 2>/dev/null; then
    foot_ready=1; break
  fi
  sleep .1
done
[ "$foot_ready" = 1 ] || fail 'normal foot window did not map'
wait_ui "$surface_ready"
ui_key Return 's["tour"] is not None and s["tour"]["step"] == 1'
wait_tour step 1
assert_state next '{"active":true,"step":1,"stepId":"ring","completed":false}'
ui_key Right 's["tour"] is not None and s["tour"]["step"] == 2'
ui_key Left 's["tour"] is not None and s["tour"]["step"] == 1'
ui_key Left 's["tour"] is not None and s["tour"]["step"] == 0'
wait_tour step 0
tour back
assert_state back '{"active":true,"step":0,"stepId":"hatch","completed":false}'
ui_key Escape 's["tour"] is None'
wait_tour completed True
assert_state skipped '{"active":false,"step":0,"stepId":"hatch","completed":true}'
for _ in 1 2 3; do
  wtype -k Shift_L -M ctrl -k u -m ctrl
  typ 'NB2-normal-window-keys'
  key Return
  for _ in $(seq 15); do
    [ "$(cat "$OUT/normal-input.txt" 2>/dev/null)" = NB2-normal-window-keys ] && break
    sleep .1
  done
  [ "$(cat "$OUT/normal-input.txt" 2>/dev/null)" = NB2-normal-window-keys ] && break
done
[ "$(cat "$OUT/normal-input.txt" 2>/dev/null)" = NB2-normal-window-keys ] || fail 'keyboard did not return to the normal foot window'
swaymsg -t get_tree >"$OUT/focus-after-tour.json"
python3 - "$OUT/focus-after-tour.json" <<'PY'
import json, sys
def walk(n):
    yield n
    for child in n.get('nodes', []) + n.get('floating_nodes', []):
        yield from walk(child)
assert any(n.get('app_id') == 'nb2-tour-input' and n.get('focused')
           for n in walk(json.load(open(sys.argv[1])))), 'foot did not regain focus'
PY
for _ in $(seq 50); do
  python3 - "$state_file" <<'PY' 2>/dev/null && break
import json, sys
assert json.load(open(sys.argv[1]))['tour'] == {'completed': True, 'version': 1}
PY
  sleep 0.1
done
python3 - "$state_file" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d['tour'] == {'completed': True, 'version': 1}, d
assert 'usage' in d and 'recent' in d, d
PY
[ "$(config_hash)" = "$config_before" ] || fail "tour changed user config"

stop_shell
start_shell
wait_tour completed True
sleep 0.7
assert_state restarted '{"active":false,"step":0,"stepId":"hatch","completed":true}'
wait_ui 's["tour"] is None'
ipc commands >"$OUT/commands.json"
python3 - "$OUT/commands.json" <<'PY'
import json, sys
c = next(c for c in json.load(open(sys.argv[1])) if c['id'] == 'tour.start')
assert c['title'] == 'Show the tour again' and c['params'] == [], c
PY
ipc run tour.start '{}' >"$OUT/replay-reply.txt"
wait_tour active True
assert_state replay '{"active":true,"step":0,"stepId":"hatch","completed":true}'
wait_ui "$surface_ready"
for _ in $(seq 5); do tour next; done
wait_tour active False
assert_state finished '{"active":false,"step":4,"stepId":"strip","completed":true}'
wait_ui 's["tour"] is None'
tour start
wait_tour active True
wait_tour step 0
tour skip
[ "$(config_hash)" = "$config_before" ] || fail "replay changed user config"

# Fresh state with tour.enabled=false stays off, including explicit IPC start.
stop_shell
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" "$state_file" <<'PY'
import json, pathlib, sys
config, state = map(pathlib.Path, sys.argv[1:])
d = json.loads(config.read_text()) if config.exists() else {}
d['tour'] = {'enabled': False}
config.write_text(json.dumps(d))
s = json.loads(state.read_text())
s.pop('tour', None)
state.write_text(json.dumps(s))
PY
start_shell
sleep 0.7
assert_state disabled '{"active":false,"step":0,"stepId":"hatch","completed":false}'
wait_ui 's["tour"] is None'
tour start
assert_state disabled-start '{"active":false,"step":0,"stepId":"hatch","completed":false}'

# Seed fullscreen BEFORE starting a fresh shell: catches startup snapshot races.
stop_shell
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
d = json.loads(p.read_text())
d['tour']['enabled'] = True
p.write_text(json.dumps(d))
PY
game=$(mock '{"op":"open","class":"tour-game","title":"Tour fullscreen hold","workspace":1}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["address"])')
mock '{"op":"focus_workspace","workspace":1}' >/dev/null
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
start_shell
sleep 1
assert_state fullscreen-held '{"active":false,"step":0,"stepId":"hatch","completed":false}'
wait_ui 's["tour"] is None'
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_tour active True
assert_state fullscreen-cleared '{"active":true,"step":0,"stepId":"hatch","completed":false}'
wait_ui "$surface_ready"
# Later fullscreen temporarily hides an active tour without losing its step.
tour next
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_tour active False
wait_tour step 1
wait_ui 's["tour"] is None'
tour next
wait_tour step 1
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_tour active True
wait_tour step 1
wait_ui "$surface_ready and s[\"tour\"][\"step\"] == 1"
ui_key Escape 's["tour"] is None'
check_life
echo 'tour: ok (state persistence, primary surface/focus, real navigation, fullscreen lifetime, keyboard returned to foot)'
