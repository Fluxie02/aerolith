# shellcheck shell=bash
# Actual QML frames with explicit Hyprland protocol fixture windows.
set -e
sleep 4
shot 00-settled
capture() {
    local name=$1
    shift
    mkdir -p "$OUT/frames/$name"
    (
      for i in $(seq -w 0 17); do
        date +%s.%N >> "$OUT/frames/$name/times.txt"
        grim -t ppm "$OUT/frames/$name/frame-$i.ppm"
        sleep .024
      done
    ) &
    local capture_pid=$!
    sleep .06
    date +%s.%N > "$OUT/frames/$name/trigger.txt"
    "$@"
    wait "$capture_pid"
    sleep .6
    shot "$name-settled"
}
mock '{"op":"open","class":"libreoffice-writer","title":"SHEAR field notes — Writer","workspace":2}' >/dev/null
mock '{"op":"open","class":"steam","title":"Library — Steam","workspace":3}' >/dev/null
mock '{"op":"open","class":"discord","title":"Studio / Discord","workspace":3}' >/dev/null
craft_address=$(mock '{"op":"open","class":"ai.storyteller.photocraft","title":"Material study <draft> & light","workspace":3}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
firefox_address=$(mock '{"op":"open","class":"firefox","title":"AEROLITH / research notebook","workspace":2}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
# Navigator already owns explicit snapshot refresh. Use that contract.
ipc open navigator; sleep .6; ipc close; sleep .5
sleep .4
mock '{"op":"focus_workspace","workspace":2}' >/dev/null
sleep .35
capture 01-firefox-handoff ipc run window.focus "{\"address\":\"$firefox_address\"}"
mock '{"op":"focus_workspace","workspace":3}' >/dev/null
sleep .35
ipc status > "$OUT/status-before-creative.json"
python3 -c 'import json,sys;assert json.load(open(sys.argv[1]))["focusedWorkspace"]==3' "$OUT/status-before-creative.json"
capture 02-creative-handoff ipc run window.focus "{\"address\":\"$craft_address\"}"
ipc status > "$OUT/status-creative.json"
python3 -c 'import json,sys;s=json.load(open(sys.argv[1]));assert s["focusedWorkspace"]==3;assert s["activeWindow"]=="Material study <draft> & light"' "$OUT/status-creative.json"
capture 03-dock ipc open command
typ "firefox"; sleep .3; shot 04-input
capture 05-window-bay ipc open navigator
capture 06-release ipc close
mock '{"op":"screencast","active":true,"owner":1}' >/dev/null
sleep .2; shot 07-sharing
mock '{"op":"screencast","active":false}' >/dev/null
ipc status > "$OUT/status-final.json"
python3 -c 'import json,sys;s=json.load(open(sys.argv[1]));assert s["configErrors"]==0 and s["routineErrors"]==0;assert s["focusedWorkspace"]==3' "$OUT/status-final.json"
alive || exit 1
echo 'motion: ok'
