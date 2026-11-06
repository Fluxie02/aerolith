# shellcheck shell=bash
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
# Preserve and audit the original cold start, using Personalize's exact regex.
cp "$OUT/qs.log" "$OUT/startup-qs.log"
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/startup-qs.log"; then
  echo 'FAIL: startup QML errors'; exit 1
fi
echo "smoke: ok"
