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
#   5. the password never appears in the shell's log.
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
grep -q "\[aerolith:lock\] locking" "$OUT/qs.log" || fail "no lock log line"
sleep 1
shot 01-locked

# 2. Wrong password.
enter "not-the-password"
wait_field lockState failed 10 || fail "a wrong password was not refused"
[ "$(field locked)" = True ] || fail "a wrong password unlocked the session"
shot 02-wrong

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

# 5. No secret in the log.
if grep -E "aerolith-test|not-the-password|wrong-[1-5]" "$OUT/qs.log"; then fail "a password reached the log"; fi
alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "lock: ok"
