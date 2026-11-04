# shellcheck shell=bash
# State-only tour contract; TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh
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
wait_tour active True
assert_state fresh '{"active":true,"step":0,"stepId":"hatch","completed":false}'
tour next
wait_tour step 1
assert_state next '{"active":true,"step":1,"stepId":"ring","completed":false}'
tour back
wait_tour step 0
tour back
assert_state back '{"active":true,"step":0,"stepId":"hatch","completed":false}'
tour skip
wait_tour completed True
assert_state skipped '{"active":false,"step":0,"stepId":"hatch","completed":true}'
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
ipc commands >"$OUT/commands.json"
python3 - "$OUT/commands.json" <<'PY'
import json, sys
c = next(c for c in json.load(open(sys.argv[1])) if c['id'] == 'tour.start')
assert c['title'] == 'Show the tour again' and c['params'] == [], c
PY
ipc run tour.start '{}' >"$OUT/replay-reply.txt"
wait_tour active True
assert_state replay '{"active":true,"step":0,"stepId":"hatch","completed":true}'
for _ in $(seq 5); do tour next; done
wait_tour active False
assert_state finished '{"active":false,"step":4,"stepId":"strip","completed":true}'
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
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_tour active True
assert_state fullscreen-cleared '{"active":true,"step":0,"stepId":"hatch","completed":false}'
# Later fullscreen temporarily hides an active tour without losing its step.
tour next
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_tour active False
wait_tour step 1
tour next
wait_tour step 1
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_tour active True
wait_tour step 1
tour skip
check_life
echo "tour: ok"
