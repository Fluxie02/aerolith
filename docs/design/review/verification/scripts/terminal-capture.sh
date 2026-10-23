fail() { echo "FAIL: $*"; exit 1; }
sleep 4
ipc open command; sleep .7
typ foot; sleep .4
shot 01-command-all
key Tab; sleep .25
shot 02-scope-apps
key Tab; sleep .25
shot 03-scope-windows
wtype -k Shift_L -M shift -k Tab -m shift; sleep .25
shot 04-scope-back
wtype -k Shift_L -M ctrl -k 3 -m ctrl; sleep .8
shot 05-rail-systems
ipc status > "$OUT/status-systems.json"
python3 - "$OUT/status-systems.json" <<'PY'
import sys,json
assert json.load(open(sys.argv[1]))['telemetryIntervalMs']==1000
PY
wtype -k Shift_L -M ctrl -k 7 -m ctrl; sleep .6
shot 06-rail-settings
key F1; sleep .5
shot 07-rail-help
ipc close; sleep .5
# Real foot on the actual Ground/Strip; no change to installed user settings.
if [[ "$SHELL_DIR" == *before-tabs* ]]; then
  foot_args=()
else
  foot_args=(--config=/src/themes/foot/aerolith.ini)
  swaymsg 'client.focused #ceebac #1b282b #edf3f5 #ceebac #ceebac' > "$OUT/sway-decoration.json"
fi
swaymsg 'for_window [app_id="aerolith-themed"] floating enable' > "$OUT/sway-placement.json"
foot "${foot_args[@]}" --app-id=aerolith-themed --title='Terminal · AEROLITH' bash /src/build/ui008/terminal-demo.sh > "$OUT/foot.log" 2>&1 &
terminal_pid=$!
sleep .6
swaymsg '[app_id="aerolith-themed"] border pixel 2' > "$OUT/sway-border.json"
swaymsg '[app_id="aerolith-themed"] resize set width 1050 height 660' > "$OUT/sway-size.json"
swaymsg '[app_id="aerolith-themed"] move position 720 230' > "$OUT/sway-position.json"
sleep 1
kill -0 "$terminal_pid" || fail 'real foot failed to start'
shot 08-terminal-with-shell
swaymsg -t get_tree > "$OUT/sway-tree.json"
kill "$terminal_pid"
alive || fail 'shell died'
echo 'tabs: ok (Tab / Shift+Tab, Ctrl+3, Ctrl+7, F1, real foot)'
