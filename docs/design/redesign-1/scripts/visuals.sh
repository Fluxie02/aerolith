# Headless-only visual and interaction evidence, using the real Media service.
fail() { echo "FAIL: $*"; exit 1; }
sleep 4
shot desktop
ipc status >"$OUT/status.json"
python3 "$SRC/docs/design/redesign-1/scripts/mpris-fixture.py" "file://$SRC/docs/design/redesign-1/scripts/cover.svg" >"$OUT/mpris-fixture.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 50); do
  ipc status | grep -q '"players":1' && break
  sleep 0.1
done
ipc status | grep -q '"players":1' || fail 'MPRIS fixture did not connect'
sleep 1
shot media-cover
# Click coordinates below are only for 1080p; larger runs check rendering.
if [ "$RES" = 1920x1080 ]; then
 click 1375 414
 sleep 0.4
 grep -qE 'PlayPause|Pause' "$OUT/mpris-fixture.log" || fail 'desktop play/pause did not reach MPRIS'
 shot media-paused
 click 1480 414
 sleep 0.4
 grep -q Next "$OUT/mpris-fixture.log" || fail 'desktop next did not reach MPRIS'
 shot media-next
 # Workspace 05 is empty initially; its target is outside the wing footprint.
 click 768 785
 sleep 1
 ipc status | grep -q '"focusedWorkspace":5' || fail 'station click did not switch workspace'
 shot workspace-05
 ipc run settings.motion '{"motion":"reduced"}' >/dev/null
 sleep 0.4
 shot reduced-workspace-05
 ipc run workspace.focus '{"workspace":1}' >/dev/null
 sleep 0.6
 shot reduced-workspace-01
 ipc run settings.motion '{"motion":"off"}' >/dev/null
 ipc open command >/dev/null
 sleep 0.5
 shot motion-off-command
 key F1
 sleep 0.5
 ipc status | grep -q '"bay":"help"' || fail 'F1 help missing'
 ipc close >/dev/null
fi
if [ "$RES" = 1280x720 ]; then
 click 374 533
 sleep 0.5
 ipc status | grep -q '"focusedWorkspace":3' || fail 'compact workspace click failed'
 shot compact-workspace-03
 ipc open command >/dev/null
 sleep 0.7
 shot compact-command
fi
alive || fail 'shell died' 
echo 'visuals: ok'
