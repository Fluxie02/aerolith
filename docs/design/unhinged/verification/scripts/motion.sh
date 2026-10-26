# shellcheck shell=bash
set -e
mkdir -p "$OUT/frames/00-assembly"
for i in $(seq -w 0 17); do
    date +%s.%N >> "$OUT/frames/00-assembly/times.txt"
    grim -t ppm "$OUT/frames/00-assembly/frame-$i.ppm"
    sleep .12
done
sleep 1
shot 00-settled
capture() {
    local name=$1
    shift
    mkdir -p "$OUT/frames/$name"
    (
      for i in $(seq -w 0 17); do
        date +%s.%N >> "$OUT/frames/$name/times.txt"
        grim -t ppm "$OUT/frames/$name/frame-$i.ppm"
        sleep 0.018
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
capture 01-workspace mock '{"op":"focus_workspace","workspace":5}'
capture 02-focus mock '{"op":"open","class":"AeroLab","title":"Airframe stress analysis","workspace":5}'
capture 03-dock ipc open command
typ "foot"; sleep .3; shot 04-input
capture 05-cross-bay ipc open navigator
capture 06-release ipc close
mock '{"op":"screencast","active":true,"owner":1}' >/dev/null
sleep .2; shot 07-sharing
mock '{"op":"screencast","active":false}' >/dev/null
ipc run shell.notify '{"message":"Airframe registered","detail":"Workspace and focus planes are settled."}' >/dev/null
sleep .3; shot 08-notice
ipc status > "$OUT/status-final.json"
alive || exit 1
echo 'motion: ok'
