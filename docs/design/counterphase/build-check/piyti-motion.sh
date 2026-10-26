# shellcheck shell=bash
set -e
sleep 4
mock '{"op":"open","class":"libreoffice-writer","title":"COUNTERPHASE field notes — Writer","workspace":2}' >/dev/null
mock '{"op":"open","class":"steam","title":"Library — Steam","workspace":3}' >/dev/null
mock '{"op":"open","class":"discord","title":"Studio / Discord","workspace":3}' >/dev/null
craft_address=$(mock '{"op":"open","class":"ai.storyteller.photocraft","title":"COUNTERPHASE / material study","workspace":3}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
firefox_address=$(mock '{"op":"open","class":"firefox","title":"AEROLITH / motion notebook","workspace":3}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["address"])')
ipc open navigator; sleep .5; ipc close; sleep .4
mock '{"op":"focus_workspace","workspace":3}' >/dev/null
ipc run window.focus "{\"address\":\"$craft_address\"}" >/dev/null
sleep .7
shot 00-piyti-integrated
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
# Reduced focus cannot create the old full-opacity 240 ms flash.
ipc run settings.motion '{"motion":"reduced"}' >/dev/null
sleep 3
shot reduced-focus-before
ipc run window.focus "{\"address\":\"$firefox_address\"}" >/dev/null
sleep .06
shot reduced-focus-after
# Intensity/motion changes in one turn must never restart a disabled timer.
for _ in 1 2 3; do
 ipc run settings.intensity '{"intensity":"insane"}' >/dev/null
 ipc run settings.motion '{"motion":"off"}' >/dev/null
 ipc run settings.intensity '{"intensity":"saturated"}' >/dev/null
done
sleep .2; shot rapid-off-0
sleep 1; shot rapid-off-1
ipc status > "$OUT/status.json"
alive || exit 1
echo 'motion: ok'
