# shellcheck shell=bash
sleep 3
shot 01-idle
mock '{"op":"focus_workspace","workspace":3}' >/dev/null
mock '{"op":"open","class":"<b>plain & literal</b>","title":"<i>Window title remains plain text</i>","workspace":3}' >/dev/null
sleep .1; shot 02-workspace-focus
sleep .8; shot 03-settled
ipc open command; sleep .6; typ 'vol 45'; sleep .2; shot 04-command
key Return; sleep .5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.45' || exit 1
ipc open systems; sleep 1; shot 05-systems
ipc open settings; sleep .6; shot 06-settings
ipc close; sleep .5
ipc status > "$OUT/status.json"
alive || exit 1
echo 'accessibility: ok'
