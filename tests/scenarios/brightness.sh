# shellcheck shell=bash
# Brightness scenario (roadmap D02). Needs BACKLIGHT=1 (a fake backlight and
# brightnessctl in the container):
#   BACKLIGHT=1 tools/headless/run.sh tests/scenarios/brightness.sh
# Checks that
#   1. the backlight is detected and read (500 of 1000 = 50%),
#   2. brightness.set writes the kernel value and shows the brightness OSD,
#   3. up/down step to multiples of 5 and never reach 0,
#   4. without a backlight the commands report it instead of failing silently
#      (run without BACKLIGHT=1 to see that case).
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
# `ipc run` starts a command and logs its result; return that result line.
run() {
  local id=$1 before
  before=$(grep -c "\[aerolith:ipc\] $id: " "$OUT/qs.log" || true)
  ipc run "$id" "$2" >/dev/null
  for _ in $(seq 50); do
    [ "$(grep -c "\[aerolith:ipc\] $id: " "$OUT/qs.log" || true)" -gt "$before" ] && break
    sleep 0.1
  done
  grep "\[aerolith:ipc\] $id: " "$OUT/qs.log" | tail -1 | sed "s/.*\[aerolith:ipc\] $id: //"
}
sleep 3
if [ -z "${AEROLITH_BACKLIGHT_ROOT:-}" ]; then
  r=$(run brightness.set '{"level":40}')
  case $r in failed*) echo "brightness: unavailable case reports: $r";; *) fail "brightness.set succeeded without a backlight: $r";; esac
  echo "brightness: ok (no backlight)"
  return 0 2>/dev/null || exit 0
fi
bl="$AEROLITH_BACKLIGHT_ROOT/test_backlight/brightness"

# 1. Detection.
wait_field brightness 50 5 || fail "the backlight was not detected at 50%"
grep -q "using backlight test_backlight" "$OUT/qs.log" || fail "no detection log line"

# 2. Set, and the OSD.
r=$(run brightness.set '{"level":30}')
[ "$r" = "ok: Brightness 30%" ] || fail "brightness.set replied: $r"
[ "$(cat "$bl")" = 300 ] || fail "the kernel value is $(cat "$bl"), wanted 300"
wait_field osd brightness 3 || fail "no brightness OSD"
[ "$(field osdValue)" = 0.3 ] || fail "the OSD shows $(field osdValue), wanted 0.3"
shot 01-brightness-osd
wait_field osd "" 4 || fail "the brightness OSD did not expire"

# 3. Steps.
run brightness.up '{}' >/dev/null
[ "$(cat "$bl")" = 350 ] || fail "up from 30% gave $(cat "$bl")"
echo 470 >"$bl"
run brightness.set '{"level":47}' >/dev/null
run brightness.down '{}' >/dev/null
[ "$(cat "$bl")" = 450 ] || fail "down from 47% gave $(cat "$bl"), wanted 450"
run brightness.set '{"level":1}' >/dev/null
run brightness.down '{}' >/dev/null
[ "$(cat "$bl")" = 10 ] || fail "brightness went below 1%: $(cat "$bl")"

alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "brightness: ok"
