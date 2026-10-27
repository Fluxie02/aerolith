# shellcheck shell=bash
# Desktop links (alpha): the application bus along the bottom of the desktop
# and the window register act on applications instead of opening the
# Navigator:
#   tools/headless/run.sh tests/scenarios/app-links.sh
# The mock starts with foot, Firefox, Nautilus and Code across workspaces 1–3.
# Checks that
#   1. clicking a running application's link focuses its window,
#   2. with two windows, a click goes to the most recently used one and the
#      next click to the other,
#   3. an installed application that is not running is started,
#   4. a reverse-DNS window uses its desktop name and a launch raises rank,
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
# Probe actual rendered sockets in a disposable shell copy. No production IPC
# or geometry changes; clicks follow the app when usage changes its position.
bar() { qs -p "$SHELL_DIR" ipc call app-links snapshot; }
click_app() {
  local point app_x app_y
  point=$(bar | python3 -c 'import json,sys; a=next(a for a in json.load(sys.stdin)["apps"] if a["name"]==sys.argv[1]); print(round(a["x"]), round(a["y"]))' "$1")
  read -r app_x app_y <<<"$point"
  click "$app_x" "$app_y"
}
rank_of() { bar | python3 -c 'import json,sys; print([a["name"] for a in json.load(sys.stdin)["apps"]].index(sys.argv[1]))' "$1"; }
ALL_APPS=(1753 1040)
addr_of() { mock '{"op":"state"}' | python3 -c 'import json,sys; s=json.load(sys.stdin); print([c["address"] for c in s["clients"] if c["title"]==sys.argv[1]][0])' "$1"; }
focus() { mock "{\"op\":\"focus_window\",\"address\":\"$(addr_of "$1")\"}" >/dev/null; wait_field activeWindow "$1" 3 || fail "could not focus $1"; }
no_navigator() { [ "$(field bay)" != navigator ] || fail "$1 opened the Navigator"; }

FOOT="pilot@aerolith: ~"
WIKI="Hyprland Wiki — Mozilla Firefox"
# Hide the dev image's launchers through user-local overrides, then provide
# four running-app entries and one launch fixture. Host files are untouched.
mkdir -p "$HOME/.local/share/applications"
for desktop in /usr/share/applications/*.desktop; do
  printf '[Desktop Entry]\nType=Application\nName=Hidden test entry\nHidden=true\n' >"$HOME/.local/share/applications/$(basename "$desktop")"
done
printf '[Desktop Entry]\nType=Application\nName=Foot\nExec=foot\nIcon=foot\n' >"$HOME/.local/share/applications/foot.desktop"
printf '[Desktop Entry]\nType=Application\nName=Firefox\nExec=true\nIcon=firefox\n' >"$HOME/.local/share/applications/firefox.desktop"
printf '[Desktop Entry]\nType=Application\nName=Files\nExec=true\nIcon=system-file-manager\n' >"$HOME/.local/share/applications/org.gnome.Nautilus.desktop"
printf '[Desktop Entry]\nType=Application\nName=Visual Studio Code\nExec=true\nStartupWMClass=Code\n' >"$HOME/.local/share/applications/com.example.Editor.desktop"
printf '[Desktop Entry]\nType=Application\nName=LibreOffice\nExec=touch %s/libreoffice-started\n' "$OUT" \
  >"$HOME/.local/share/applications/libreoffice-startcenter.desktop"
sleep 3
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/app-links-shell"
SHELL_DIR="$HOME/app-links-shell"
python3 - "$SHELL_DIR/components/AppContinuity.qml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text().replace('import QtQuick', 'import Quickshell.Io\nimport QtQuick', 1)
probe = '''
    IpcHandler {
        target: "app-links"
        enabled: bus.exposed
        function snapshot(): string {
            const apps = [];
            for (const child of sockets.children) {
                if (child.modelData === undefined) continue;
                const e = child.modelData;
                const point = child.mapToItem(null, child.width / 2, child.height / 2);
                apps.push({id:e.id, name:e.name, icon:e.icon, running:e.running,
                    windows:child.windowCount, current:child.current, x:point.x, y:point.y});
            }
            return JSON.stringify({apps:apps, capacity:bus.capacity});
        }
    }
'''
p.write_text(s.replace('    id: bus\n', '    id: bus\n' + probe, 1))
PY
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
for _ in $(seq 50); do
  if bar >"$OUT/bar-before.json" 2>/dev/null && python3 -c 'import json,sys; a=json.load(open(sys.argv[1]))["apps"]; assert len(a) == 5 and sum(e["windows"] for e in a) == 4' "$OUT/bar-before.json" 2>/dev/null; then break; fi
  sleep 0.1
done
python3 - "$OUT/bar-before.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
apps = d['apps']
assert len(apps) == 5 and len(apps) <= d['capacity'], d
files = next(a for a in apps if a['name'] == 'Files')
assert files['id'].removesuffix('.desktop') == 'org.gnome.Nautilus', files
assert files['icon'] == 'system-file-manager' and files['windows'] == 1, files
editor = next(a for a in apps if a['name'] == 'Visual Studio Code')
assert editor['windows'] == 1 and editor['icon'] == 'application-x-executable', editor
PY
sleep 2
mock '{"op":"state"}' >"$OUT/mock-start.json"

# 1. A running application: its window.
focus "$FOOT"
click_app Firefox
wait_field activeWindow "$WIKI" 3 || fail "the Firefox link did not focus Firefox"
no_navigator "the Firefox link"
shot 01-firefox-focused

# 2. Two windows: most recent first, then the other.
mock '{"op":"open","class":"firefox","title":"Second Firefox","workspace":1}' >/dev/null
focus "Second Firefox"
focus "$FOOT"
click_app Firefox
wait_field activeWindow "Second Firefox" 3 || fail "the Firefox link did not go to the most recent Firefox window"
click_app Firefox
[ "$(field activeWindow)" != "Second Firefox" ] || wait_field activeWindow "$WIKI" 3 || fail "a second click did not move to the other Firefox window"
[ "$(field activeWindow)" = "$WIKI" ] || fail "a second click went to $(field activeWindow)"

# 3. Installed, not running: started.
# (Desktop entries are picked up live; retry if the first click came too early.)
before_rank=$(rank_of LibreOffice)
for _ in 1 2 3; do
  click_app LibreOffice
  for _ in $(seq 30); do [ -f "$OUT/libreoffice-started" ] && break; sleep 0.1; done
  [ -f "$OUT/libreoffice-started" ] && break
  if [ "$(field bay)" != "" ]; then ipc close >/dev/null; sleep 1; fi
  sleep 2
done
[ -f "$OUT/libreoffice-started" ] || fail "the LibreOffice link did not start LibreOffice"
no_navigator "the LibreOffice link"
[ "$(field bay)" = "" ] || fail "starting LibreOffice opened the Deck ($(field bay))"
for _ in $(seq 30); do [ "$(rank_of LibreOffice)" = 0 ] && break; sleep 0.1; done
[ "$before_rank" -gt "$(rank_of LibreOffice)" ] || fail "launching LibreOffice did not raise its rank"
[ "$(rank_of LibreOffice)" = 0 ] || fail "most-used LibreOffice did not rank first"
bar >"$OUT/bar-after-launch.json"
# Its new socket still starts the same desktop entry, rather than searching.
rm "$OUT/libreoffice-started"
click_app LibreOffice
for _ in $(seq 30); do [ -f "$OUT/libreoffice-started" ] && break; sleep 0.1; done
[ -f "$OUT/libreoffice-started" ] || fail "ranked LibreOffice socket lost launch behavior"
focus "$FOOT"
click_app Files
wait_field activeWindow Downloads 3 || fail "the reverse-DNS Files socket did not focus Nautilus"
bar >"$OUT/bar-files-focused.json"
python3 -c 'import json,sys; a=next(a for a in json.load(open(sys.argv[1]))["apps"] if a["name"]=="Files"); assert a["current"] and a["windows"] == 1, a' "$OUT/bar-files-focused.json"

# 4. The persistent All apps entry opens search regardless of the dock list.
click "${ALL_APPS[@]}"
wait_field bay command 3 || fail "All apps did not open the search"
[ "$(field query)" = "" ] || fail "All apps should start with an empty query"
shot 02-all-apps-search
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
