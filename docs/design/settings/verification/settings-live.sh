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
  ipc open settings >/dev/null; sleep .8
  local count
  count=$(python3 -c 'import json,sys; print(next(i for i,r in enumerate(json.load(open("/src/build/ui008/row-map.json"))) if r["path"]==sys.argv[1]))' "$1")
  local args=(-k Shift_L)
  for (( i=0; i<count; i++ )); do args+=(-k Down); done
  wtype -d 15 "${args[@]}"; sleep .4
}
replace_text() { wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace -- "$1"; }
sleep 4
ipc open settings | grep -q '^ok$' || fail 'ipc open settings failed'
sleep 1
shot 01-register
# Bool: background surface setting changes immediately and persists.
select_setting ground.enabled
key space; sleep .5
assert_config ground.enabled false
[ "$(field ground)" = False ] || fail 'ground toggle did not apply live'
shot 02-bool-off
key Return; sleep .4
assert_config ground.enabled true
[ "$(field ground)" = True ] || fail 'ground restore did not apply live'
# Enum: screen edge moves the live strip and the Deck anchoring.
select_setting strip.edge
key Right; sleep .6
assert_config strip.edge '"bottom"'
[ "$(field stripEdge)" = bottom ] || fail 'strip enum did not apply live'
shot 03-enum-bottom
key Left; sleep .4
assert_config strip.edge '"top"'
# Number: telemetry changes its active interval without reopening.
select_setting telemetry.stripIntervalMs
key Right; sleep .5
assert_config telemetry.stripIntervalMs 6000
[ "$(field telemetryIntervalMs)" = 6000 ] || fail 'numeric interval did not apply live'
shot 04-number-range
key Left; sleep .3
assert_config telemetry.stripIntervalMs 5000
# Text: separate fresh opens preserve the original editor focus semantics.
select_setting theme.fontSans
key Return; sleep .15; replace_text '<b>UNTRUSTED & plain</b>'; sleep .3
shot 07-plain-text
key Escape; sleep .3
# Canceled text never reaches config.json.
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY2'
import json,sys
assert json.load(open(sys.argv[1])).get('theme',{}).get('fontSans','Inter')=='Inter'
PY2
select_setting theme.fontSans
key Return; sleep .15; replace_text 'Noto Sans'; sleep .4
shot 05-text-draft
key Return; sleep .5
assert_config theme.fontSans '"Noto Sans"'
shot 06-text-saved
select_setting theme.fontSans
key Return; sleep .15
replace_text "$(python3 -c 'print("x"*129)')"; key Return; sleep .4
assert_config theme.fontSans '"Noto Sans"'
shot 08-refused
select_setting theme.fontSans
key Return; sleep .15; replace_text 'Inter'; key Return; sleep .4
assert_config theme.fontSans '"Inter"'
# Every row is reachable, including the final section; pages retain selection.
select_setting logging.level
shot 09-last-section
key Page_Up; sleep .2; shot 10-page-up
key Page_Down; sleep .2
# Intensity itself changes the open bay and complete desktop, and is saved.
select_setting theme.intensity
before=$(python3 -c 'import json,os; print(json.load(open(os.environ["XDG_CONFIG_HOME"]+"/aerolith/config.json"))["theme"]["intensity"])')
key Right; sleep .6
if [ "$before" = saturated ]; then after=insane; else after=saturated; fi
assert_config theme.intensity "\"$after\""
shot 11-intensity-live
key Left; sleep .5
assert_config theme.intensity "\"$before\""
# Deck Ctrl+7 and Command Core set alias still reach Settings.
ipc open command >/dev/null; sleep .4
wtype -k Shift_L -M ctrl -k 7 -m ctrl; sleep .4
shot 12-ctrl7
ipc close; sleep .3
ipc open command >/dev/null; sleep .5
typ set; sleep .3; key Return; sleep .6
shot 13-set-alias
ipc open help; sleep .6
shot 14-help
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/config-final.json"
ipc status > "$OUT/status-final.json"
alive || fail 'shell died'
echo 'settings-live: ok (bool, enum, number, text, draft/cancel/refusal, plain text, paging, intensity, Ctrl+7, set alias)'
