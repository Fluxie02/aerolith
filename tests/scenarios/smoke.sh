# Smoke scenario: the shell starts, renders the Flight Strip with mock
# Hyprland state, opens the Command Core over IPC, and exits cleanly.
# Sourced by tools/headless/session.sh (helpers: ipc, shot, mock, alive).

sleep 2
shot 01-strip
ipc status >"$OUT/status.json"
ipc open command
sleep 1
shot 02-command-core
ipc close
sleep 0.5
alive || { echo "FAIL: quickshell died"; exit 1; }
echo "smoke: ok"
