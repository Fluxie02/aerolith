# shellcheck shell=bash
shot() { grim -o HEADLESS-1 "$OUT/$1.png"; }
sleep 3
# Native state transitions: empty workspace, no command results, sharing, DND.
ipc open command; sleep .7; typ 'zzzzzz-no-such-command'; sleep .4; shot e1-no-results
ipc close
mock '{"op":"focus_workspace","id":5}'
ipc open navigator; sleep 1; shot e2-empty-workspace
ipc close
mock '{"op":"screencast","active":true,"owner":"<b>Recorder</b> with a long owner name"}'
swaymsg create_output >/dev/null
ipc run notifications.dnd.toggle '{}'; sleep 1; shot e3-sharing-multi-dnd
ipc run shell.notify '{"message":"<b>Literal summary</b>"}'; sleep .3; shot e4-notice
ipc open help; sleep .8; key Next; key Next; shot e5-help-keys
ipc close
ipc open systems; sleep .1; shot e6-systems-loading
sleep 1
alive || exit 1
