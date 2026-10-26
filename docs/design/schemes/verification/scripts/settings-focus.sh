# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 2
ipc open settings; sleep 1
shot 01-initial-picker
key End; key Return; sleep .5
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY' || fail "Glacial did not persist through Settings"
import json,sys
s=json.load(open(sys.argv[1])); assert s['theme']['scheme']=='glacial',s
PY
shot 02-live-glacial
key Tab; sleep .3
shot 03-register
key Return; typ '<b>draft only</b>'; key Escape; sleep .2
key Tab; sleep .3
shot 04-back-to-picker
python3 -c 'import json,sys; assert json.loads(sys.argv[1])["deckMapped"] is True' "$(ipc status)" || fail "editing Escape closed Settings"
key Escape; sleep .5
python3 -c 'import json,sys; assert json.loads(sys.argv[1])["deckMapped"] is False' "$(ipc status)" || fail "Settings did not close"
alive || fail "quickshell died"
echo "settings-focus: ok"
