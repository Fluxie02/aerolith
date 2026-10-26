# shellcheck shell=bash
# Session menu scenario (roadmap D06):
#   tools/headless/run.sh tests/scenarios/session.sh
# The container has no logind or systemd, so the actions fail harmlessly and
# their failure notices prove whether a command ran. Checks that
#   1. the menu opens over IPC and lists the Power commands,
#   2. a sensitive action (reboot) needs a deliberate second activation:
#      Escape backs out of the confirmation, a second Escape closes the menu,
#      and nothing has run,
#   3. after the confirmation the command runs once, confirmed (no second
#      prompt), and the menu closes,
#   4. opening the Deck closes the menu.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
keys() { wtype -k Shift_L "$@"; }
sleep 3

# 1. Open.
ipc session >/dev/null
wait_field session True 3 || fail "the session menu did not open"
sleep 0.8
shot 01-session
notices=$(field notices)

# 2. Reboot is the fourth action (lock, suspend, logout, reboot, poweroff).
keys -k Down -s 100 -k Down -s 100 -k Down -s 100 -k Return
sleep 0.5
shot 02-confirming
keys -k Escape
sleep 0.4
[ "$(field session)" = True ] || fail "Escape in the confirmation closed the menu instead of backing out"
keys -k Escape
wait_field session False 3 || fail "a second Escape did not close the menu"
sleep 1
[ "$(field notices)" = "$notices" ] || fail "a command ran without confirmation ($(field notices) notices, was $notices)"
grep -q "needs confirmation" "$OUT/qs.log" && fail "the registry was asked to run an unconfirmed command"

# 3. Confirm: Return on Reboot, Tab to the confirm button, Return.
ipc session >/dev/null
wait_field session True 3 || fail "the session menu did not reopen"
sleep 0.8
keys -k Down -s 100 -k Down -s 100 -k Down -s 100 -k Return -s 300 -k Tab -s 200 -k Return
wait_field session False 3 || fail "the menu did not close after the confirmed action"
for _ in $(seq 30); do [ "$(field notices)" != "$notices" ] && break; sleep 0.1; done
[ "$(field notices)" != "$notices" ] || fail "the confirmed reboot did not run (no result notice)"
shot 03-after-confirm
grep -q "needs confirmation" "$OUT/qs.log" && fail "the confirmed action was refused as unconfirmed"

# 4. The Deck takes over.
ipc session >/dev/null
wait_field session True 3 || fail "the session menu did not open for the Deck test"
ipc open command >/dev/null
wait_field session False 3 || fail "opening the Deck did not close the session menu"
ipc close

alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "session: ok"
