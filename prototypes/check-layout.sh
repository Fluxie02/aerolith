# shellcheck shell=bash
sleep 4
ipc open navigator; sleep 0.7; shot 07-small-off
key Down; key Tab; sleep 0.2
key m; key Escape
ipc close
ipc open command; sleep 0.4
typ 'vol 40'; sleep 0.4; key Return; sleep 1
wpctl get-volume @DEFAULT_AUDIO_SINK@ >"$OUT/volume-after.txt"
grep -q '0.40' "$OUT/volume-after.txt" || { echo 'FAIL: volume'; exit 1; }
ipc open signal; sleep 0.7
key Right; key m; key m
ipc close
alive || { echo 'FAIL: quickshell died'; exit 1; }
echo 'layout-and-keys: ok'
