# shellcheck shell=bash
# Session lock with a PAM stack that asks twice (roadmap D07):
#   LOCK=1 LOCK_PAM=double CONFIG=tests/fixtures/lock-config.json tools/headless/run.sh tests/scenarios/lock-multistep.sh
# /etc/pam.d/login runs the test module tests/fixtures/pam/pam_twice.c, which
# asks for a second hidden answer right after the first, the way a second
# factor would, and accepts only the password twice. The lock screen
# answers one hidden prompt only. Checks that
#   1. the second prompt ends the attempt as a failure instead of leaving
#      the lock screen checking forever, and the session stays locked,
#   2. the password is not sent a second time (a second answer would unlock),
#   3. the lock screen accepts input again afterwards.
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

ipc lock >/dev/null
wait_field lockSecure True 3 || fail "the compositor did not confirm the lock"
sleep 1

# 1–2. The right password meets a second prompt.
enter "aerolith-test"
wait_field lockState failed 10 || fail "a second PAM prompt left the lock screen in state $(field lockState)"
[ "$(field locked)" = True ] || fail "a second PAM prompt unlocked the session"
grep -q "\[aerolith:lock\] authentication stopped: .*does not support" "$OUT/qs.log" || fail "no log line for the unsupported prompt"
shot 01-second-prompt

# 3. Input is accepted again: another attempt reaches PAM and fails the same way.
enter "aerolith-test"
wait_field lockAttempts 2 10 || fail "the lock screen did not accept another attempt (attempts $(field lockAttempts))"
[ "$(field locked)" = True ] || fail "the second attempt unlocked the session"

if grep -E "aerolith-test" "$OUT/qs.log"; then fail "a password reached the log"; fi
alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "lock-multistep: ok"
