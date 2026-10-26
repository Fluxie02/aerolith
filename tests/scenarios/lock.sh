# shellcheck shell=bash
# Session lock scenario (roadmap D07). Needs LOCK=1 and lock.enabled:
#   LOCK=1 CONFIG=tests/fixtures/lock-config.json tools/headless/run.sh tests/scenarios/lock.sh
# The test user's password is aerolith-test (set by run.sh for LOCK=1); PAM
# is real (/etc/pam.d/login, pam_unix). sway implements ext-session-lock-v1.
# Checks that
#   1. the lock command locks the session through the Wayland session lock,
#   2. a wrong password is refused and the session stays locked,
#   3. the right password unlocks it,
#   4. five wrong passwords pause input, and nothing typed then unlocks,
#   5. the password never appears in the shell's log,
#   6. editing the shell's files while locked does not reload it and keeps
#      the lock and the attempt count (a reload would rebuild the lock; see
#      LockHost.qml),
#   7. the pause ends and the right password then unlocks,
#   8. once unlocked, file changes reload the shell again.
# "locked" is the lock the shell holds; "lockSecure" is the compositor's
# confirmation, and the lock command reports success only after it.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
enter() { wtype -k Shift_L -- "$1"; sleep 0.3; wtype -k Shift_L -k Return; }
sleep 3
[ "$(field locked)" = False ] || fail "locked at startup"

# 1. Lock.
ipc lock >/dev/null
wait_field locked True 3 || fail "the lock command did not lock"
wait_field lockSecure True 3 || fail "the compositor did not confirm the lock"
grep -q "\[aerolith:lock\] locking" "$OUT/qs.log" || fail "no lock log line"
sleep 1
shot 01-locked

# 2. Wrong password.
enter "not-the-password"
wait_field lockState failed 10 || fail "a wrong password was not refused"
[ "$(field locked)" = True ] || fail "a wrong password unlocked the session"
shot 02-wrong
loads() { grep -c "Configuration Loaded" "$OUT/qs.log"; }
change_shell() { echo "// edit $RANDOM" >>"$SHELL_DIR/shell.qml"; }
# Editing the shell while locked does not reload it (file watching pauses).
before=$(loads)
change_shell
sleep 3
[ "$(loads)" = "$before" ] || fail "a file change reloaded the shell while locked"
[ "$(field locked)" = True ] || fail "a file change released the lock"
[ "$(field lockSecure)" = True ] || fail "after a file change the compositor no longer holds the lock"
[ "$(field lockAttempts)" = 1 ] || fail "a file change reset the attempt count (now $(field lockAttempts))"
shot 02b-after-edit

# 3. Right password.
enter "aerolith-test"
wait_field locked False 10 || fail "the right password did not unlock (state $(field lockState))"
grep -q "\[aerolith:lock\] unlocked" "$OUT/qs.log" || fail "no unlock log line"

# 4. Five failures pause input; the right password then does nothing.
ipc lock >/dev/null
wait_field locked True 3 || fail "could not lock again"
sleep 0.5
for i in 1 2 3 4 5; do
  enter "wrong-$i"
  for _ in $(seq 100); do s=$(field lockState); [ "$s" = failed ] || [ "$s" = locked-out ] && break; sleep 0.1; done
done
wait_field lockState locked-out 5 || fail "five failures did not pause input (state $(field lockState), attempts $(field lockAttempts))"
shot 03-locked-out
enter "aerolith-test"
sleep 2
[ "$(field locked)" = True ] || fail "typing during the pause unlocked the session"

# 7. The pause ends (30 s from the fifth failure); the right password works.
wait_field lockState idle 35 || fail "the pause did not end (state $(field lockState))"
enter "aerolith-test"
wait_field locked False 10 || fail "the right password did not unlock after the pause"

# 8. Unlocked, file watching is back: a change reloads the shell.
before=$(loads)
change_shell
for _ in $(seq 100); do [ "$(loads)" -gt "$before" ] && break; sleep 0.1; done
[ "$(loads)" -gt "$before" ] || fail "file watching did not resume after unlocking"
sleep 2

# 5. No secret in the log.
if grep -E "aerolith-test|not-the-password|wrong-[1-5]" "$OUT/qs.log"; then fail "a password reached the log"; fi
alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "lock: ok"
