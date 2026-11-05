# Extra fit check, 1280x720 / UI scale 1.5 / reduced motion.
source "$SRC/docs/design/network-tour/jpeg.sh"
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/compact-shell"
SHELL_DIR="$HOME/compact-shell"
python3 "$SRC/docs/design/network-tour/fixture.py" "$SHELL_DIR"
qs -p "$SHELL_DIR" >>"$OUT/qs.log" 2>&1 &
QS_PID=$!; PIDS+=("$QS_PID")
sleep 3
qs -p "$SHELL_DIR" ipc call tour start
for step in 0 1 2 3 4; do
  sleep .4
  qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/tour-$step-ui.json"
  python3 - "$OUT/tour-$step-ui.json" "$step" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); t=s['tour']; assert t['step']==int(sys.argv[2])
c=next(p for p in t['parts'] if p['name']=='tourCard'); r=t['target']
assert 0<=c['x'] and c['x']+c['w']<=1281 and 0<=c['y'] and c['y']+c['h']<=721,c
assert c['x']+c['w']<=r['x'] or c['x']>=r['x']+r['width'] or c['y']+c['h']<=r['y'] or c['y']>=r['y']+r['height'],(c,r)
PY
  shot "tour-$step"
  qs -p "$SHELL_DIR" ipc call tour next
done
if grep -nE 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|is not a type|Error loading QML' "$OUT/qs.log"; then exit 1; fi
echo 'compact: ok (five steps fit and leave targets clear)'
# A new surface must receive keys once the tour has been destroyed.
sleep .5
ipc open command
sleep 1
key F1
sleep .5
ipc status >"$OUT/keyboard-after-tour.json"
python3 - "$OUT/keyboard-after-tour.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); assert s['bay']=='help' and s['deckMapped'],s
PY
key Escape
sleep .5
ipc status >"$OUT/keyboard-released.json"
python3 - "$OUT/keyboard-released.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); assert not s['deckMapped'],s
PY
echo 'keyboard after tour: ok (F1 to Help, Esc closes Deck)'
