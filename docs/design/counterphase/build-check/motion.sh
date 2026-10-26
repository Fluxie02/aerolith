# shellcheck shell=bash
set -e
sleep 5
mkdir -p "$OUT/frames"
# Re-enable full to align all finite carrier groups with this capture.
ipc run settings.motion '{"motion":"off"}' >/dev/null
sleep .25
ipc run settings.motion '{"motion":"full"}' >/dev/null
# Captures use real compositor output; no manufactured frames.
for i in $(seq -w 0 14); do
  date +%s.%N >> "$OUT/frames/times.txt"
  grim "$OUT/frames/frame-$i.png"
  sleep .065
done
sleep 1
shot 01-full-settled
for mode in off reduced; do
 ipc run settings.motion "{\"motion\":\"$mode\"}" >/dev/null
 sleep .2
 shot "$mode-0"
 sleep .6
 shot "$mode-1"
 sleep 1
 shot "$mode-2"
done
ipc run settings.motion '{"motion":"full"}' >/dev/null
sleep .2
shot restart-0
sleep .3
shot restart-1
ipc run settings.low-effects '{}' >/dev/null
sleep .2
shot low-0
sleep 1
shot low-1
ipc run settings.low-effects '{}' >/dev/null
sleep .2
shot resume-0
sleep .3
shot resume-1
ipc open command; sleep .5; shot 02-command
ipc close; sleep .2; shot deck-resume-0
sleep .3; shot deck-resume-1
ipc status > "$OUT/status.json"
alive || exit 1
echo 'motion: ok'
