# Sourced only inside the headless harness's disposable session.
fail() { echo "FAIL: $*"; exit 1; }
probe() { qs -p "$SHELL_DIR" ipc call hatch-evidence "$@"; }
capture_state() {
  sleep 0.4
  probe snapshot >"$OUT/$1.json"
  shot "$1"
}
click_hatch() {
  local point hatch_x hatch_y
  point=$(probe snapshot | python3 -c 'import json,sys; d=json.load(sys.stdin); scale=float(sys.argv[1]); print(round(d["x"]*scale),round(d["y"]*scale))' "$SCALE")
  read -r hatch_x hatch_y <<<"$point"
  click "$hatch_x" "$hatch_y"
}
expect_open() {
  probe snapshot | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["open"] == (sys.argv[1] == "true"), d' "$1" || fail "hatch open should be $1"
}
start_visual_fixture() {
  sleep 4
  # First capture proves the unmodified shell survives the missing interface.
  shot interface-state
  qs -p "$SHELL_DIR" kill
  wait "$QS_PID" || true
  cp -r "$SHELL_DIR" "$HOME/hatch-visual-shell"
  SHELL_DIR="$HOME/hatch-visual-shell"
  python3 "$SRC/docs/design/redesign-2/scripts/fixture.py" "$SHELL_DIR"
  restart_visual_fixture
}
restart_visual_fixture() {
  qs -p "$SHELL_DIR" >>"$OUT/qs-fixture.log" 2>&1 &
  QS_PID=$!
  PIDS+=("$QS_PID")
  for _ in $(seq 100); do
    if probe snapshot >"$OUT/ready.json" 2>/dev/null; then
      python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["canToggle"] and d["width"] > 0' "$OUT/ready.json" 2>/dev/null && break
    fi
    sleep 0.1
  done
  probe snapshot >"$OUT/ready.json" || fail 'hatch probe not ready'
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["canToggle"] and d["width"] > 0, d' "$OUT/ready.json" || fail 'hatch command not ready'
  sleep 3
}
audit_visual_logs() {
  alive || fail 'shell died'
  if grep -nE 'Error:|Failed to load configuration|Cannot override FINAL|ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign|Error loading QML|is not a type|Cannot assign' "$OUT"/qs*.log; then
    fail 'QML error in visual logs'
  fi
}
