# UI-008 integration and visual evidence. Uses real keys and Config.setValue.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
assert_config() {
  python3 - "$XDG_CONFIG_HOME/aerolith/config.json" "$1" "$2" <<'PY'
import json,sys
v=json.load(open(sys.argv[1]))
for k in sys.argv[2].split('.'): v=v[k]
assert v==json.loads(sys.argv[3]), (sys.argv[2],v,sys.argv[3])
PY
}
select_setting() {
  ipc close; sleep .25
  ipc open settings >/dev/null; sleep .4
  local count
  count=$(python3 -c 'import json,sys; print(next(i for i,r in enumerate(json.load(open("/src/build/ui008/row-map.json"))) if r["path"]==sys.argv[1]))' "$1")
  local args=(-k Shift_L)
  for (( i=0; i<count; i++ )); do args+=(-k Down); done
  wtype "${args[@]}"; sleep .25
}
replace_text() { wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace -- "$1"; }
sleep 3
ipc open settings; sleep .5
shot 01-compact
select_setting theme.density
shot 02-compact-choices
select_setting theme.uiScale
shot 03-compact-range
select_setting theme.fontSans
key Return; sleep .2; replace_text '<b>plain draft</b>'; sleep .3
shot 04-compact-draft
key Escape; sleep .2
select_setting ground.enabled
shot 05-compact-description
select_setting logging.level
shot 06-compact-last
alive || fail 'shell died'
echo 'compact: ok'
