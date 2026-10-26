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
#   6. twenty enter/exit cycles leave the shell in the same state, without
#      QML errors or a replayed startup.
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
shot 01-suspended

# 3. Leaving fullscreen restores.
mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
wait_field surfacesReleased False 3 || fail "the surfaces did not come back"
wait_field phase desktop 3 || fail "the shell did not return to desktop"
wait_field ambient True 2 || fail "ambient motion did not resume"
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

# 6. Twenty cycles.
for i in $(seq 20); do
  mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":2}" >/dev/null
  wait_field surfacesReleased True 3 || fail "cycle $i: not released"
  mock "{\"op\":\"fullscreen\",\"address\":\"$game\",\"mode\":0}" >/dev/null
  wait_field phase desktop 3 || fail "cycle $i: not restored"
done
alive || fail "quickshell died during the cycles"
[ "$(grep -c "AEROLITH started" "$OUT/qs.log")" = "$starts" ] || fail "the shell restarted"
[ "$(grep -c "desktop -> suspended" "$OUT/qs.log")" = 22 ] || fail "expected 22 suspensions, log has $(grep -c "desktop -> suspended" "$OUT/qs.log")"

# 7. With the notification server on (CONFIG=tests/fixtures/notify-config.json,
#    popupTimeoutMs 5000), a popup that arrives during fullscreen is kept
#    until the shell is back and then gets its full time.
if [ -f /seed/config.json ] && grep -q '"notifications"' /seed/config.json; then
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
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
shot 04-after-cycles
echo "fullscreen: ok"
