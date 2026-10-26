# shellcheck shell=bash
# Startup-only direction, invalid metadata fallback and warning. Uses the
# harness's disposable config and restarts only its own Quickshell process.
fail() { echo "FAIL: $*"; exit 1; }
metadata="$XDG_CONFIG_HOME/aerolith/installation.json"
expect_direction() {
  python3 -c 'import json,sys; s=json.loads(sys.argv[1]); assert s["direction"] == sys.argv[2], s' "$(ipc status)" "$1" || fail "direction should be $1"
}
restart_direction() {
  qs -p "$SHELL_DIR" kill
  wait "$QS_PID" || true
  qs -p "$SHELL_DIR" >"$OUT/qs-$1.log" 2>&1 &
  QS_PID=$!
  PIDS+=("$QS_PID")
  for _ in $(seq 100); do
    grep -q 'Configuration Loaded' "$OUT/qs-$1.log" && break
    sleep 0.1
  done
  alive || fail "shell died after $1"
}
expect_direction piyti
printf '%s\n' '{"direction":"thears"}' >"$metadata"
ipc reload
sleep 0.3
expect_direction piyti
restart_direction thears
expect_direction thears
printf '%s\n' '{"direction":"piyti"}' >"$metadata"
ipc reload
sleep 0.3
expect_direction thears
restart_direction piyti
expect_direction piyti
for entry in 'invalid:{"direction":"other"}' 'null:{"direction":null}' 'array:[]' 'broken:{' 'empty:' 'whitespace:  '; do
  label=${entry%%:*}
  printf '%s\n' "${entry#*:}" >"$metadata"
  restart_direction "$label"
  expect_direction piyti
  grep -q 'invalid installation direction.*using piyti' "$OUT/qs-$label.log" || fail "missing invalid direction warning ($label)"
done
rm "$metadata"
restart_direction missing
expect_direction piyti
! grep -q 'invalid installation direction' "$OUT/qs-missing.log" || fail "missing file should be quiet"
echo "direction: ok (startup choice, no live switch, invalid fallback, missing fallback)"
