# Exercise the maintained direction through startup metadata only.
sleep 3
printf '%s\n' '{"direction":"thears"}' >"$XDG_CONFIG_HOME/aerolith/installation.json"
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
qs -p "$SHELL_DIR" >"$OUT/qs-thears.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
sleep 4
ipc status >"$OUT/status-thears.json"
grep -q '"direction":"thears"' "$OUT/status-thears.json" || exit 1
shot thears-desktop
ipc open command >/dev/null
sleep 1
shot thears-command
alive || exit 1
echo 'thears: ok'
