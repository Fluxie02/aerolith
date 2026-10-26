# shellcheck shell=bash
# Fullscreen lifecycle scenario (roadmap B01–B05):
#   tools/headless/run.sh tests/scenarios/fullscreen.sh
# Checks that
#   1. a maximized window keeps the shell,
#   2. a fullscreen window on the active workspace suspends it: ambient
#      motion held, then the visual surfaces released,
#   3. leaving fullscreen restores the surfaces, then ambient motion,
#   4. a fullscreen window on another workspace does not count, and
#      switching to its workspace does,
#   5. summoning the Deck during fullscreen maps the Deck alone, and closing
#      it releases it again,
#   6. twenty enter/exit cycles, including open bays with service demand,
#      opt-in Navigator thumbnails, notifications and process RSS samples,
#   7. popup expiry pauses during fullscreen, and
#   8. a floating non-fullscreen client can take focus on the same workspace.
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
addr() { python3 -c 'import json,sys; print(json.loads(sys.argv[1])["address"])' "$1"; }
sleep 3
wait_field phase desktop 5 || fail "the shell did not start on the desktop"
starts=$(grep -c "AEROLITH started" "$OUT/qs.log")
[ "$starts" = 1 ] || fail "expected exactly one shell startup, got $starts"
notifications=0
if [ -f /seed/config.json ]; then
  notifications=$(python3 -c 'import json; print(int(json.load(open("/seed/config.json")).get("notifications", {}).get("server", False)))')
fi
send_pair() {
  local n
  for n in 1 2; do
    python3 "$SRC/tools/headless/notify_client.py" --summary "B05 cycle $i popup $n" --wait 0.1 >"$OUT/cycle-$i-notice-$n.txt" 2>>"$OUT/notify-client.log"
  done
  wait_field popups 2 3 || fail "cycle $i: expected two distinct popups"
}
fullscreen_mode() { mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":$1}" >/dev/null; }
restored() {
  wait_field phase desktop 3 || fail "$*: not restored"
  [ "$(field surfacesReleased)" = False ] || fail "$*: surfaces still released"
  [ "$(field deckMapped)" = False ] || fail "$*: Deck leaked after restore"
  [ "$(field audioDetail)" = 0 ] || fail "$*: audio demand leaked after restore"
  [ "$(field telemetryIntervalMs)" = 5000 ] || fail "$*: telemetry demand leaked after restore"
}

game=$(addr "$(mock '{"op":"open","class":"steam_app_1","title":"Game","workspace":1}')")
mock '{"op":"focus_workspace","workspace":1}' >/dev/null

# 1. Maximized is not fullscreen.
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":1}" >/dev/null
sleep 1.5
[ "$(field phase)" = desktop ] || fail "a maximized window suspended the shell"

# 2. Fullscreen suspends.
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
wait_field phase suspended 3 || fail "fullscreen did not suspend the shell"
wait_field surfacesReleased True 2 || fail "the surfaces were not released"
[ "$(field ambient)" = False ] || fail "ambient motion still runs while suspended"
[ "$(field fullscreenOwner)" = steam_app_1 ] || fail "wrong fullscreen owner: $(field fullscreenOwner)"
[ "$(field telemetryIntervalMs)" = 0 ] || fail "telemetry still samples every $(field telemetryIntervalMs) ms while suspended"
shot 01-suspended

# 3. Leaving fullscreen restores.
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_field surfacesReleased False 3 || fail "the surfaces did not come back"
wait_field phase desktop 3 || fail "the shell did not return to desktop"
wait_field ambient True 2 || fail "ambient motion did not resume"
[ "$(field telemetryIntervalMs)" = 5000 ] || fail "telemetry did not resume after fullscreen"
shot 02-restored

# 4. Only the active workspace of the selected output counts.
mock '{"op":"focus_workspace","workspace":2}' >/dev/null
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
sleep 1.5
[ "$(field phase)" = desktop ] || fail "a fullscreen window on another workspace suspended the shell"
mock '{"op":"focus_workspace","workspace":1}' >/dev/null
wait_field phase suspended 3 || fail "switching to the fullscreen workspace did not suspend the shell"

# 5. The Deck can be summoned over a fullscreen window.
ipc open command >/dev/null
wait_field deckMapped True 3 || fail "the Deck did not map during fullscreen"
[ "$(field surfacesReleased)" = True ] || fail "summoning the Deck restored the other surfaces"
shot 03-deck-over-fullscreen
ipc close
wait_field deckMapped False 3 || fail "the Deck stayed mapped after closing during fullscreen"
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_field phase desktop 3 || fail "the shell did not restore after the Deck test"

# 6. Twenty cycles. Each bay is live before entry; alternate audio/telemetry
# demand and Navigator (matrix CONFIG enables thumbnails). A pair of popups
# spans two cycles, then expires normally before the next pair. Stay below
# the three-popup cap so a duplicate is visible as a count mismatch.
printf 'cycle\trss_kib\n' >"$OUT/rss.tsv"
for i in $(seq 20); do
  case $(( (i - 1) % 3 )) in
    0) ipc open systems >/dev/null
       wait_field telemetryIntervalMs 1000 3 || fail "cycle $i: Systems demand missing" ;;
    1) ipc open signal >/dev/null
       wait_field audioDetail 1 3 || fail "cycle $i: Signal demand missing" ;;
    2) ipc open navigator >/dev/null ;;
  esac
  wait_field deckMapped True 3 || fail "cycle $i: Deck did not open"
  # Give Navigator tiles time to instantiate before tearing down their parent.
  sleep 0.3
  fullscreen_mode 2
  wait_field surfacesReleased True 3 || fail "cycle $i: not released"
  wait_field deckMapped False 3 || fail "cycle $i: Deck did not close on fullscreen entry"
  [ "$(field audioDetail)" = 0 ] || fail "cycle $i: audio demand held during fullscreen"
  [ "$(field telemetryIntervalMs)" = 0 ] || fail "cycle $i: telemetry still sampling"
  [ "$(field ambient)" = False ] || fail "cycle $i: ambient still running"
  if [ "$notifications" = 1 ]; then
    if [ $((i % 2)) = 1 ]; then send_pair; fi
    [ "$(field popups)" = 2 ] || fail "cycle $i: popups lost or duplicated while suspended"
  fi
  fullscreen_mode 0
  restored "cycle $i"
  if [ "$notifications" = 1 ]; then
    [ "$(field popups)" = 2 ] || fail "cycle $i: popups lost or duplicated on restore"
  fi
  # Read the actual shell PID, never the short-lived `qs ipc` client. Sample
  # the same restored state every time, including checkpoints 1, 10 and 20.
  rss=$(awk '/^VmRSS:/ {print $2}' "/proc/$QS_PID/status")
  [ -n "$rss" ] || fail "cycle $i: cannot read shell VmRSS"
  printf '%s\t%s\n' "$i" "$rss" >>"$OUT/rss.tsv"
  ipc status >"$OUT/cycle-$i-status.json"
  if [ "$notifications" = 1 ] && [ $((i % 2)) = 0 ]; then
    # Check identity as well as count: dismiss one of the two known ids.
    # A duplicated survivor masking a lost popup cannot pass this check.
    notice_id=$(head -1 "$OUT/cycle-$((i - 1))-notice-1.txt")
    [[ "$notice_id" =~ ^[0-9]+$ ]] || fail "cycle $i: invalid notification id"
    ipc run notifications.dismiss "{\"id\":$notice_id}" >/dev/null
    wait_field popups 1 2 || fail "cycle $i: dismissing one id did not leave exactly one popup"
    wait_field popups 0 7 || fail "cycle $i: popups never expired after restore"
  fi
done
alive || fail "quickshell died during the cycles"
[ "$(grep -c "AEROLITH started" "$OUT/qs.log")" = "$starts" ] || fail "the shell restarted"
[ "$(grep -c "desktop -> suspended" "$OUT/qs.log")" = 22 ] || fail "expected 22 suspensions, log has $(grep -c "desktop -> suspended" "$OUT/qs.log")"

# 7. With the notification server on (CONFIG=tests/fixtures/notify-config.json,
#    popupTimeoutMs 5000), a popup that arrives during fullscreen is kept
#    until the shell is back and then gets its full time.
if [ "$notifications" = 1 ]; then
  mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
  wait_field surfacesReleased True 3 || fail "not released before the notification test"
  python3 "$SRC/tools/headless/notify_client.py" --summary "Download finished" --wait 1 >"$OUT/fs-n1.txt" 2>>"$OUT/notify-client.log" &
  wait_field popups 1 5 || fail "the notification sent during fullscreen has no popup"
  sleep 7
  [ "$(field popups)" = 1 ] || fail "the popup expired during fullscreen"
  mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
  wait_field phase desktop 3 || fail "not restored for the notification test"
  sleep 3
  [ "$(field popups)" = 1 ] || fail "the popup did not get its full time after fullscreen"
  wait_field popups 0 4 || fail "the popup never expired after fullscreen"
fi

# RSS is noisy and may retain allocator caches. Flag sustained growth above
# an explicit 8 MiB budget in BOTH sampled intervals, rather than one bump.
# Keep every sample for review; this is a regression screen, not leak proof.
python3 - "$OUT/rss.tsv" "$OUT/rss-summary.json" <<'PY'
import csv, json, sys
with open(sys.argv[1]) as f:
    rows = {int(r['cycle']): int(r['rss_kib']) for r in csv.DictReader(f, delimiter='\t')}
a, b, c = (rows[n] for n in (1, 10, 20))
steady = b - a > 8192 and c - b > 8192
result = {'rss_kib': {str(n): rows[n] for n in (1, 10, 20)},
          'interval_budget_kib': 8192, 'steady_growth': steady}
with open(sys.argv[2], 'w') as f:
    json.dump(result, f, indent=2)
print(json.dumps(result))
if steady:
    sys.exit('FAIL: RSS grew by more than 8 MiB in both intervals; investigate before approving B05')
PY

# 8. Hyprland lets a floating client take focus above fullscreen without
# clearing the game's fullscreen bit (FocusState.cpp:27-41, v0.56.2).
# Tiled focus depends on misc:on_focus_under_fullscreen; do not fake its policy.
other=$(addr "$(mock '{"op":"open","class":"b05-dialog","title":"B05 focus target","workspace":1,"floating":true}')")
mock "{\"op\":\"focus_window\",\"address\":\"$game\"}" >/dev/null
fullscreen_mode 2
wait_field surfacesReleased True 3 || fail "focus test: not suspended initially"
mock "{\"op\":\"focus_window\",\"address\":\"$other\"}" >"$OUT/focus-reply.json"
wait_field activeWindow "B05 focus target" 3 || fail "focus test: compositor focus did not change"
mock '{"op":"state"}' >"$OUT/focus-other-mock.json"
ipc status >"$OUT/focus-other-status.json"
restored "focus on a non-fullscreen floating window"
mock "{\"op\":\"focus_window\",\"address\":\"$game\"}" >/dev/null
wait_field surfacesReleased True 3 || fail "focus test: focusing the game did not suspend again"
fullscreen_mode 0
restored "focus test cleanup"
[ "$(grep -c 'AEROLITH started' "$OUT/qs.log")" = 1 ] || fail "startup repeated"
if grep -nEi "ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
shot 04-after-cycles
echo "fullscreen: ok"
