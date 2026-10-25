# shellcheck shell=bash
# Exercise cold slot A/B, close during entry, reuse and repeated bay replacement.
set -e
sleep 3
for delay in 0 0.035 0.070 0.1; do
    ipc open command >/dev/null
    sleep "$delay"
    ipc close
    ipc open settings >/dev/null
    sleep "$delay"
    ipc open navigator >/dev/null
    ipc close
    sleep 0.2
done
for _ in 1 2 3 4 5 6 7 8; do
    ipc open command >/dev/null
    ipc open systems >/dev/null
    ipc open settings >/dev/null
    ipc open navigator >/dev/null
    ipc close
done
sleep 0.4
ipc status >"$OUT/final-status.json"
ipc open command >/dev/null
sleep 0.5
shot settled-reused-command
ipc close
sleep 0.3
python3 - "$OUT/final-status.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
assert not s['deckMapped'],s
assert s['telemetryIntervalMs']==5000,s
assert s['audioDetail']==0,s
assert s['configErrors']==0,s
PY
alive
echo 'cold rapid slot lifecycle: ok'
