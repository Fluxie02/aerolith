# shellcheck shell=bash
# Notification server scenario. Needs the server on:
#   CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh
# A real D-Bus client (tools/headless/notify_client.py) sends notifications
# and records the signals it gets back. Checks that
#   1. a notification shows a popup, and invoking one of its actions reaches
#      the sender as ActionInvoked and removes the popup (a resident
#      notification, which the server keeps, so only the shell can hide it),
#   2. popup lifetimes are fixed when they appear (popupTimeoutMs 5000), so a
#      later popup never extends an earlier one, and hiding a popup does not
#      close the notification,
#   3. dismissing a notification closes it for the sender.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
send() {
  local out=$1
  shift
  python3 "$SRC/tools/headless/notify_client.py" "$@" >"$out" 2>>"$OUT/notify-client.log" &
  for _ in $(seq 50); do [ -s "$out" ] && break; sleep 0.1; done
  head -1 "$out"
}
saw() {
  local pattern=$1 file=$2
  for _ in $(seq 30); do grep -q "$pattern" "$file" && return 0; sleep 0.1; done
  return 1
}
sleep 3

# 1. Actions.
id=$(send "$OUT/n1.txt" --summary "Build finished" --body "aerolith: 0 errors" --action "default:Open" --action "rerun:Run again" --resident --wait 15)
[ -n "$id" ] || fail "the notification server did not answer"
wait_field popups 1 5 || fail "no popup for the notification"
shot n1-popup
ipc run notifications.action "{\"id\":$id,\"action\":\"rerun\"}" >/dev/null
wait_for_log "notifications.action: ok" 5 || fail "the action command failed"
saw "^action rerun" "$OUT/n1.txt" || fail "the sender never received ActionInvoked"
wait_field popups 0 3 || fail "the popup stayed after its action ran"

# 2. Lifetimes fixed on arrival.
first=$(send "$OUT/n2.txt" --summary "First popup" --wait 25)
sleep 2.5
send "$OUT/n3.txt" --summary "Second popup" --wait 25 >/dev/null
wait_field popups 2 3 || fail "two popups expected"
shot n2-two-popups
sleep 3.3
[ "$(field popups)" = 1 ] || fail "the first popup's life was extended by the second ($(field popups) shown)"
wait_field popups 0 5 || fail "popups did not expire"
grep -q "^closed" "$OUT/n2.txt" && fail "hiding a popup closed the notification"

# 3. Dismissal reaches the sender (reason 2: dismissed by the user).
ipc run notifications.dismiss "{\"id\":$first}" >/dev/null
saw "^closed 2" "$OUT/n2.txt" || fail "the sender was not told the notification was dismissed"

# 4. Evicting the oldest of 101 retained notifications closes its sender.
ipc run notifications.clear '{}' >/dev/null
wait_field popups 0 3 || fail "clear did not remove popups"
send "$OUT/evicted.txt" --summary "Oldest retained notification" --wait 30 >/dev/null
python3 - <<'PY'
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib
conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
for i in range(100):
    conn.call_sync("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                   "org.freedesktop.Notifications", "Notify",
                   GLib.Variant("(susssasa{sv}i)", ("overflow-test", 0, "", f"Overflow {i}", "", [], {}, 0)),
                   GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 5000, None)
PY
saw "^closed 2" "$OUT/evicted.txt" || fail "the evicted sender was left open"

alive || fail "quickshell died"
echo "notify: ok"
