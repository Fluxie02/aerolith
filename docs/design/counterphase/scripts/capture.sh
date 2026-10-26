# shellcheck shell=bash
# Lean visual evidence on real-sized headless output; no production mutation.
set -e
sleep 5
swaymsg -t get_outputs -r > "$OUT/output-geometry.json"
mock '{"op":"state"}' > "$OUT/mock-geometry.json"
ipc status > "$OUT/status.json"
shot 01-idle
ipc open command; sleep .8; shot 02-command
ipc open settings; sleep .8; shot 03-settings
ipc open navigator; sleep .8; shot 04-navigator
ipc close; sleep .4
ipc status > "$OUT/status-final.json"
python3 - "$OUT/status-final.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
assert s['configErrors']==0 and s['routineErrors']==0, s
assert s['deckMapped'] is False, s
PY
alive || exit 1
echo 'capture: ok'
