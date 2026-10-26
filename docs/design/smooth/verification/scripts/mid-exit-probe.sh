# shellcheck shell=bash
sleep 3
for mode in off lowEffects; do
    ipc run settings.motion '{"motion":"full"}' >/dev/null
    if [ "$mode" = lowEffects ]; then
        # The previous case only touched motion; lowEffects starts false.
        sleep 0.5
    fi
    ipc open command >/dev/null
    sleep 0.6
    qs -p "$SHELL_DIR" ipc call ui016review disable "$mode" >"$OUT/$mode-immediate.json"
    sleep 0.3
    ipc status >"$OUT/$mode-settled-status.json"
done
python3 - "$OUT" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
for mode in ('off','lowEffects'):
 r=json.loads((p/f'{mode}-immediate.json').read_text())
 assert r['before']['mapped'] and r['before']['leaving'], r
 assert r['after']['exitMs'] == 0, r
 s=json.loads((p/f'{mode}-settled-status.json').read_text())
 assert not s['deckMapped'], s
 print(mode, json.dumps(r))
PY
alive || { echo 'FAIL: shell died'; exit 1; }
echo 'mid-exit probe: observed'
