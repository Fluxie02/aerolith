# shellcheck shell=bash
sleep 4
shot 01-idle
ipc open command; sleep 0.7
typ '@ a'; sleep 0.7; shot 02-launcher
ipc close; sleep 0.3
ipc open navigator; sleep 0.8; shot 03-overview
# Exercise actual navigator selection, filtering and destructive confirmation without accepting it.
key Down; key Tab; key x; sleep 0.2; key Escape
ipc close; sleep 0.3
# The protocol fixture does not draw window pixels. Start actual foot under sway.
foot -o font='JetBrains Mono:size=12' -o colors-dark.background=202b26 -o colors-dark.foreground=f0f2e8 --title='pilot@aerolith: ~' sh -c 'cat /src/README.md; exec bash --noprofile --norc' >"$OUT/foot.log" 2>&1 &
PIDS+=($!)
sleep 1.2
swaymsg 'client.focused #943f32 #202b26 #f0f2e8 #943f32 #943f32' >/dev/null
swaymsg '[app_id="foot"] floating enable, resize set width 1160 height 700, move position center' >/dev/null
sleep 0.5
shot 04-active
ipc run shell.notify '{"message":"Hyprland Wiki — Mozilla Firefox · Downloads"}'
sleep 0.4; shot 05-notice
sleep 3.5
ipc open signal; sleep 1.2; shot 06-sound
key Right; key m; key m; sleep 0.2
ipc close; sleep 0.3
ipc status >"$OUT/status-final.json"
alive || { echo 'FAIL: quickshell died'; exit 1; }
echo 'design-shots: ok'
