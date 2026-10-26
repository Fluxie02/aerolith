# shellcheck shell=bash
# Runtime regressions: tools/headless/run.sh tests/scenarios/runtime.sh
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$(ipc status)" "$1"; }
wait_workspace() {
  for _ in $(seq 100); do [ "$(field focusedWorkspace)" = "$1" ] && return 0; sleep 0.1; done
  fail "workspace did not become $1"
}
sleep 3

# This container has neither an idle listener nor a ScreenSaver owner.
ipc run session.lock '{}' >/dev/null
wait_for_log 'session.lock: failed: No external session locker is running' 8 || fail "absent locker reported success"

read -r lowest highest < <(mock '{"op":"state"}' | python3 -c '
import json,sys
ids=[w["id"] for w in json.load(sys.stdin)["workspaces"] if w["id"]>0]
print(min(ids),max(ids))')
for current in -98 -1337; do
  for direction in next previous; do
    mock "{\"op\":\"focus_workspace\",\"workspace\":$current}" >/dev/null
    wait_workspace "$current"
    ipc run "workspace.$direction" '{}' >/dev/null
    if [ "$direction" = next ]; then wait_workspace "$lowest"; else wait_workspace "$highest"; fi
  done
done

# A separate windowless Quickshell instance exercises the real Process/parser
# signals without exposing a test command or diagnostic state in the shell.
mkdir -p "$OUT/exec-probe/core"
cp "$SRC/shell/core/Exec.qml" "$OUT/exec-probe/core/"
cat >"$OUT/exec-probe/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs.core

Scope {
    function check(ok, message) {
        if (!ok)
            throw new Error(message);
    }
    Component.onCompleted: {
        const start = Date.now();
        Exec.run(["/nonexistent/aerolith-test-program"], {timeoutMs: 9000}).then(r => {
            check(r.code === -1 && !r.timedOut && r.stderr.indexOf("could not start") !== -1, "failed-start result");
            check(Date.now() - start < 2500, "failed start waited for the timeout");
            return Exec.run(["python3", "-c", "import sys; sys.stdout.write('a'*2097152); sys.stderr.write('b'*2097152)"], {maxOutput: 1024});
        }).then(r => {
            check(r.code === 0, "streaming process failed");
            check(r.stdout === "a".repeat(1024) && r.stderr === "b".repeat(1024), "output cap or stream drain");
            return Exec.run(["python3", "-c", "import sys; print('tail'); sys.stderr.write('err-tail'); sys.exit(7)"]);
        }).then(r => {
            check(r.code === 7 && r.stdout === "tail\n" && r.stderr === "err-tail", "final stream data or exit status lost");
            console.log("RUNTIME_EXEC_OK");
            Qt.quit();
        }).catch(e => {
            console.error("RUNTIME_EXEC_FAIL " + e);
            Qt.quit();
        });
    }
}
QML
qs -p "$OUT/exec-probe" >"$OUT/exec-probe.log" 2>&1 &
PIDS+=("$!")
for _ in $(seq 150); do
  grep -q RUNTIME_EXEC_OK "$OUT/exec-probe.log" && break
  grep -q RUNTIME_EXEC_FAIL "$OUT/exec-probe.log" && fail "Exec probe: $(cat "$OUT/exec-probe.log")"
  sleep 0.1
done
grep -q RUNTIME_EXEC_OK "$OUT/exec-probe.log" || fail "Exec probe did not finish: $(cat "$OUT/exec-probe.log")"
alive || fail "quickshell died"
if grep -nE 'ReferenceError|TypeError|Binding loop|Unable to assign' "$OUT/qs.log" "$OUT/exec-probe.log"; then fail "QML errors"; fi
echo 'runtime: ok'
