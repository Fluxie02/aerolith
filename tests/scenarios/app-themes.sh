# shellcheck shell=bash
# APP_THEMES=1 tools/headless/run.sh tests/scenarios/app-themes.sh build/C06/app-themes
fail() { echo "FAIL: $*"; exit 1; }
count() { if [ -f "$OUT/app-theme-calls.jsonl" ]; then wc -l <"$OUT/app-theme-calls.jsonl"; else echo 0; fi; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  for _ in $(seq 50); do [ "$(field "$1")" = "$2" ] && return 0; sleep 0.1; done
  fail "status.$1 did not become $2"
}
wait_count() {
  for _ in $(seq 60); do [ "$(count)" = "$1" ] && return 0; sleep 0.1; done
  fail "expected $1 refresh(es), got $(count)"
}
scheme() { ipc run settings.scheme "{\"scheme\":\"$1\"}" >"$OUT/set-$1.json"; }
sleep 3
[ "$(count)" = 0 ] || fail 'startup refreshed without a scheme change'
if ! command -v aerolith >/dev/null 2>&1; then
  scheme iris
  # The settings command itself posts its normal 3.5 s notice.
  sleep 4.5
  [ "$(count)" = 0 ] || fail 'missing CLI produced a refresh'
  [ "$(field notices)" = 0 ] || fail 'missing CLI produced a notice'
  alive || fail 'quickshell died'
  echo 'app-themes: ok (missing CLI is silent)'
  exit 0
fi
scheme iris
sleep 0.2
scheme corona
sleep 0.2
scheme bathyal
sleep 0.4
[ "$(count)" = 0 ] || fail 'refreshed before debounce elapsed'
wait_count 1
sleep 2
[ "$(count)" = 1 ] || fail 'rapid scheme changes refreshed more than once'
python3 - "$OUT/app-theme-calls.jsonl" <<'PY'
import json, sys
assert [json.loads(line)["scheme"] for line in open(sys.argv[1])] == ["bathyal"]
PY
[ "$(field notices)" = 0 ] || fail 'empty applied-app result produced a notice'
# Refresh follows only scheme changes; unrelated settings do not trigger it.
ipc run settings.motion '{"motion":"off"}' >/dev/null
sleep 2
[ "$(count)" = 1 ] || fail 'unrelated setting refreshed themes'
# Existing compositor fixture and lifecycle; no lifecycle implementation edits.
game=$(mock '{"op":"open","class":"steam_app_1","title":"C06 game","workspace":1}')
game=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["address"])' "$game")
mock '{"op":"focus_workspace","workspace":1}' >/dev/null
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_field surfacesReleased True
scheme iris
sleep 0.2
scheme corona
sleep 2
[ "$(count)" = 1 ] || fail 'refreshed while surfaces released'
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_field surfacesReleased False
wait_count 2
sleep 2
[ "$(count)" = 2 ] || fail 'restore caused duplicate refresh'
python3 - "$OUT/app-theme-calls.jsonl" <<'PY'
import json, sys
assert [json.loads(line)["scheme"] for line in open(sys.argv[1])] == ["bathyal", "corona"]
PY
# Exercise the watched config path too, rather than just Config.setValue.
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); data = json.loads(p.read_text())
data["theme"]["scheme"] = "iris"
p.write_text(json.dumps(data))
PY
wait_count 3
sleep 2
[ "$(count)" = 3 ] || fail 'config file change caused duplicate refresh'
alive || fail 'quickshell died'
echo 'app-themes: ok (debounce, empty consent, unrelated setting, fullscreen restore, config watch)'
