# shellcheck shell=bash
# Focused off/reduced/lowEffects live-mode checks, using production IPC only.
set -e
sleep 3
for motion in reduced off full; do
    ipc run settings.motion "{\"motion\":\"$motion\"}" >/dev/null
    sleep 0.25
    ipc open command >/dev/null
    sleep 0.3
    ipc open settings >/dev/null
    sleep 0.3
    shot "mode-$motion-settings"
    ipc close
    sleep 0.3
    ipc status >"$OUT/status-$motion.json"
done
for _ in 1 2 3 4 5; do
    ipc open command >/dev/null
    ipc run settings.motion '{"motion":"off"}' >/dev/null
    ipc run settings.motion '{"motion":"reduced"}' >/dev/null
    ipc run settings.motion '{"motion":"full"}' >/dev/null
    ipc close
done
ipc run settings.motion '{"motion":"off"}' >/dev/null
sleep 4.5
shot off-still-1
sleep 0.3
shot off-still-2
ipc run settings.motion '{"motion":"full"}' >/dev/null
ipc run settings.low-effects '{}' >/dev/null
sleep 4.5
shot low-still-1
sleep 0.3
shot low-still-2
ipc status >"$OUT/status-low.json"
python3 - "$OUT" <<'PY'
import json,pathlib,sys
out=pathlib.Path(sys.argv[1]); results=[]
for motion in ('reduced','off','full'):
 status=json.loads((out/f'status-{motion}.json').read_text())
 assert status['motion']==motion,status
 assert not status['deckMapped'],status

PY
alive
echo 'motion modes: ok'
