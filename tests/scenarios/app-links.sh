# shellcheck shell=bash
# Desktop links (alpha): the application bus along the bottom of the desktop
# and the window register act on applications instead of opening the
# Navigator:
#   tools/headless/run.sh tests/scenarios/app-links.sh
# The mock compositor starts with foot (workspace 1) and Firefox (workspace 2).
# Checks that
#   1. clicking a running application's link focuses its window,
#   2. with two windows, a click goes to the most recently used one and the
#      next click to the other,
#   3. an installed application that is not running is started,
#   4. an application that is not installed opens the search for it,
#   5. clicking a window in the window register focuses that window,
#   and that none of these opens the Navigator.
# Clicks go through the harness's virtual pointer at the 1920x1080 layout
# positions of the sockets (components/Instrumentation.qml, AppContinuity.qml).
fail() { echo "FAIL: $*"; exit 1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$(ipc status)" "$1"; }
wait_field() {
  local name=$1 want=$2 timeout=${3:-10}
  for _ in $(seq $((timeout * 10))); do [ "$(field "$name")" = "$want" ] && return 0; sleep 0.1; done
  echo "timeout: status.$name is $(field "$name"), wanted $want" >&2
  return 1
}
# Socket centres: x = 0.055 W + i (socket + 8) + socket / 2, y = 0.87 H + 30 + 49.
FIREFOX=(272 1018) LIBREOFFICE=(614 1018) STEAM=(955 1018)
addr_of() { mock '{"op":"state"}' | python3 -c 'import json,sys; s=json.load(sys.stdin); print([c["address"] for c in s["clients"] if c["title"]==sys.argv[1]][0])' "$1"; }
focus() { mock "{\"op\":\"focus_window\",\"address\":\"$(addr_of "$1")\"}" >/dev/null; wait_field activeWindow "$1" 3 || fail "could not focus $1"; }
no_navigator() { [ "$(field bay)" != navigator ] || fail "$1 opened the Navigator"; }

FOOT="pilot@aerolith: ~"
WIKI="Hyprland Wiki — Mozilla Firefox"
# A LibreOffice that only leaves a mark when started.
mkdir -p "$HOME/.local/share/applications"
printf '[Desktop Entry]\nType=Application\nName=LibreOffice\nExec=touch %s/libreoffice-started\n' "$OUT" \
  >"$HOME/.local/share/applications/libreoffice-startcenter.desktop"
sleep 5
mock '{"op":"state"}' >"$OUT/mock-start.json"

# 1. A running application: its window.
focus "$FOOT"
click "${FIREFOX[@]}"
wait_field activeWindow "$WIKI" 3 || fail "the Firefox link did not focus Firefox"
no_navigator "the Firefox link"
shot 01-firefox-focused

# 2. Two windows: most recent first, then the other.
mock '{"op":"open","class":"firefox","title":"Second Firefox","workspace":1}' >/dev/null
focus "Second Firefox"
focus "$FOOT"
click "${FIREFOX[@]}"
wait_field activeWindow "Second Firefox" 3 || fail "the Firefox link did not go to the most recent Firefox window"
click "${FIREFOX[@]}"
[ "$(field activeWindow)" != "Second Firefox" ] || wait_field activeWindow "$WIKI" 3 || fail "a second click did not move to the other Firefox window"
[ "$(field activeWindow)" = "$WIKI" ] || fail "a second click went to $(field activeWindow)"

# 3. Installed, not running: started.
# (Desktop entries are picked up live; retry if the first click came too early.)
for _ in 1 2 3; do
  click "${LIBREOFFICE[@]}"
  for _ in $(seq 30); do [ -f "$OUT/libreoffice-started" ] && break; sleep 0.1; done
  [ -f "$OUT/libreoffice-started" ] && break
  if [ "$(field bay)" != "" ]; then ipc close >/dev/null; sleep 1; fi
  sleep 2
done
[ -f "$OUT/libreoffice-started" ] || fail "the LibreOffice link did not start LibreOffice"
no_navigator "the LibreOffice link"
[ "$(field bay)" = "" ] || fail "starting LibreOffice opened the Deck ($(field bay))"

# 4. Not installed: the search.
click "${STEAM[@]}"
wait_field bay command 3 || fail "the Steam link (not installed) did not open the search"
[ "$(field query)" = steam ] || fail "the search was not for Steam ($(field query))"
shot 02-steam-search
ipc close >/dev/null
wait_field deckMapped False 3 || fail "the Deck did not close"

# 5. The window register (top three windows, from 0.66 H at 0.70 W).
focus "$WIKI"
first=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["clients"][0]["title"])' "$OUT/mock-start.json")
other="$WIKI"; [ "$first" = "$WIKI" ] && other="$FOOT"
focus "$other"
click 1574 752
wait_field activeWindow "$first" 3 || fail "clicking the first window in the register did not focus it ($first)"
no_navigator "the window register"

alive || fail "quickshell died"
if grep -nE "ReferenceError|TypeError|is not defined|Cannot read|Binding loop|Unable to assign" "$OUT/qs.log"; then fail "QML errors in qs.log"; fi
echo "app-links: ok"
