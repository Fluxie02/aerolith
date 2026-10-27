# Reproduce the teardown edge case: exit immediately after configuration load.
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
echo 'early-exit: process stopped'
