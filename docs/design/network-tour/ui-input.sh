# Shared by the CI scenarios; fixture.py instruments only a throwaway shell.
ui_snapshot() { qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/ui.json"; }
ui_is() {
  ui_snapshot 2>/dev/null && python3 - "$OUT/ui.json" "$1" <<'PY' 2>/dev/null
import json, sys
s = json.load(open(sys.argv[1]))
# Comprehensions resolve free names in globals, including nested uses of s.
assert eval(sys.argv[2], {'__builtins__': {}, 's': s, 'all': all, 'any': any, 'len': len}), s
PY
}
wait_ui() {
  for _ in $(seq 60); do
    if ui_is "$1"; then return 0; fi
    sleep .1
  done
  cat "$OUT/ui.json"
  fail "UI did not converge: $1"
}
ui_click() {
  local point cx cy output=${2:-HEADLESS-1}
  ui_snapshot
  point=$(python3 - "$OUT/ui.json" "$1" "$output" "${SCALE:-1}" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); name, output = sys.argv[2:4]
w = next(w for w in s['strips'] if w['output'] == output)
parts = w['parts'] if name in ('networkIndicator', 'bluetoothIndicator') else w['popup']['controls']
p = next(p for p in parts if p['name'] == name and p['visible'])
if name == 'pickerOutside':
    # Choose the largest exposed rectangle of the catcher, outside the housing.
    h = next(p for p in parts if p['name'] == 'pickerHousing')
    x, y, width, height = p['x'], p['y'], p['w'], p['h']
    spaces = [(x,y,h['x']-x,height), (h['x']+h['w'],y,x+width-h['x']-h['w'],height),
              (x,y,width,h['y']-y), (x,h['y']+h['h'],width,y+height-h['y']-h['h'])]
    x,y,width,height = max(spaces, key=lambda r: max(0,r[2])*max(0,r[3]))
    assert width > 0 and height > 0
else:
    x,y,width,height = p['x'],p['y'],p['w'],p.get('hitH',p['h'])
scale = float(sys.argv[4])
print(round((x+width/2)*scale), round((y+height/2)*scale))
PY
  ) || fail "no clickable $1 on $output"
  read -r cx cy <<<"$point"
  # vpointer uses output-local physical coordinates, including under SCALE.
  swaymsg input type:pointer map_to_output "$output" >/dev/null
  click "$cx" "$cy"
}
ui_key() {
  local keyname=$1 want=$2 before now
  # Retry only if no tour state changed: dropped injection is recoverable;
  # advancing twice or accepting the wrong state is a failure.
  before=$(tour state)
  for _ in 1 2 3; do
    sleep .3
    key "$keyname"
    for _ in $(seq 12); do
      if ui_is "$want"; then return 0; fi
      sleep .1
    done
    now=$(tour state)
    [ "$now" = "$before" ] || fail "key $keyname reached unexpected state: $now"
  done
  fail "key $keyname: $want"
}
