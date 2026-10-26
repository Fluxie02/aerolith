# shellcheck shell=bash
set -e
sleep 4
shot 01-idle
firefox_address=$(mock '{"op":"open","class":"firefox","title":"<b>Literal & untrusted</b>","workspace":2}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
ipc open navigator; sleep .6; ipc close; sleep .4
mock '{"op":"focus_workspace","workspace":2}' >/dev/null
sleep .35
ipc run window.focus "{\"address\":\"$firefox_address\"}"
sleep .8; shot 02-app-focus
ipc open command; sleep .6; typ 'vol 45'; sleep .5; shot 03-command
key Return; sleep .5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.45'
ipc open settings; sleep .6; shot 04-settings
ipc close; sleep .5
ipc status > "$OUT/status.json"
python3 -c 'import json,sys;s=json.load(open(sys.argv[1]));assert s["configErrors"]==0 and s["routineErrors"]==0;assert s["focusedWorkspace"]==2;assert s["activeWindow"]=="<b>Literal & untrusted</b>"' "$OUT/status.json"
alive || exit 1
echo 'accessibility: ok'
