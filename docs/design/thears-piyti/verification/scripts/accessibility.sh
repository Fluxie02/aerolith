# shellcheck shell=bash
set -e
sleep 4
shot 01-idle
mock '{"op":"open","class":"firefox","title":"<b>Literal & untrusted</b>","workspace":2}' >/dev/null
sleep .8; shot 02-app-focus
ipc open command; sleep .6; typ 'vol 45'; sleep .2; shot 03-command
key Return; sleep .5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.45'
ipc open settings; sleep .6; shot 04-settings
ipc close; sleep .5
ipc status > "$OUT/status.json"
alive || exit 1
echo 'accessibility: ok'
