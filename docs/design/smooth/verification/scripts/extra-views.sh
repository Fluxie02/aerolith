# shellcheck shell=bash
set -e
sleep 3
views() { qs -p "$SHELL_DIR" ipc call ui016views "$@"; }
views state >"$OUT/initial.json"
shot osd-and-circular
views progress 0 >/dev/null
sleep 0.04
views progress 1 >/dev/null
sleep 0.25
views setOpen false >/dev/null
sleep 0.2
views state >"$OUT/full-exit.json"
views setOpen true >/dev/null
sleep 0.2
views bounce >/dev/null
sleep 0.2
views state >"$OUT/reopened.json"
for mode in off reduced lowEffects; do
    views configure full false >/dev/null
    views setOpen true >/dev/null
    sleep 0.2
    views closeAndDisable "$mode" >/dev/null
    sleep 0.2
    views state >"$OUT/$mode-exit.json"
done
views setKind 1 >/dev/null
sleep 0.3
shot lock-static-fixture
views setKind 2 >/dev/null
sleep 0.3
shot session-static-fixture
python3 - "$OUT" <<'PY'
import json,pathlib,sys
out=pathlib.Path(sys.argv[1]);load=lambda name:json.loads((out/name).read_text())
initial=load('initial.json');full=load('full-exit.json');reopen=load('reopened.json')
assert initial['open'] and initial['presenting'] and initial['settled']==0,initial
assert not full['open'] and not full['presenting'] and full['settled']==1,full
assert reopen['open'] and reopen['presenting'] and reopen['settled']==1,reopen
for count,mode in enumerate(('off','reduced','lowEffects'),2):
 result=load(mode+'-exit.json')
 assert not result['open'] and not result['presenting'] and result['settled']==count,result
print('OSD normal, interrupted reopen and off/reduced/lowEffects settlement: ok')
PY
alive
echo 'extra visual views: ok'
