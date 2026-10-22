# shellcheck shell=bash
# UI-002, real mock windows and live telemetry; no screenshot-only model data.
fail() { echo "FAIL: $*"; exit 1; }
sleep 4
# Enable the existing notification service and real strip telemetry in the isolated
# container config. This does not alter the checkout or introduce config keys.
python3 - <<'CONFIG'
import json
from pathlib import Path
p=Path.home()/'.config/aerolith/config.json'
d=json.loads(p.read_text()) if p.exists() else {'schemaVersion':1}
d.setdefault('notifications',{})['server']=True
d.setdefault('strip',{})['telemetry']='always'
p.write_text(json.dumps(d))
CONFIG
ipc reload
sleep .5
shot 01-idle
ipc open command; sleep .35
typ '@ a'; sleep .35
shot 02-command
ipc close; sleep .2
ipc open navigator; sleep .4
shot 03-navigator
key Right; key Tab; key x; sleep .1; key Escape
ipc close; sleep .2
ipc open systems; sleep 4
shot 04-systems
ipc status >"$OUT/status-systems.json"
python3 - "$OUT/status-systems.json" <<'PY' || fail 'systems telemetry demand'
import json,sys
s=json.load(open(sys.argv[1])); assert s['telemetryIntervalMs']==1000,s
assert s['cpuPercent'] is not None and s['memoryPercent'] is not None,s
PY
key m; key c
ipc close; sleep .3
ipc status >"$OUT/status-closed.json"
python3 - "$OUT/status-closed.json" <<'PY' || fail 'telemetry demand was not released'
import json,sys
s=json.load(open(sys.argv[1])); assert s['telemetryIntervalMs']==5000,s
PY
# Use the notification server instead of shell.notify's known duplicate success report.
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify AEROLITH 0 "" "Workspace route updated" "Hyprland Wiki — Mozilla Firefox · Workspace 2" "[]" "{}" 3500 >/dev/null
sleep .3; shot 05-notice
sleep 4
# Keep capture starts on a 35ms schedule. PNG writes finish asynchronously;
# timestamps record actual invocation times, and may drift under load.
ipc open command >/dev/null &
motion_ipc_pid=$!
python3 - "$OUT" <<'PY'
import subprocess,sys,time,json
from pathlib import Path
out=Path(sys.argv[1]);start=time.monotonic();jobs=[];stamps=[]
for i in range(6):
    due=start+i*.035
    time.sleep(max(0,due-time.monotonic()))
    stamps.append(round((time.monotonic()-start)*1000,1))
    jobs.append(subprocess.Popen(['grim',str(out/('06-motion-%02d.png'%(i+1)))]))
for j in jobs:
    assert j.wait()==0
(out/'motion-timing.json').write_text(json.dumps({'capture_start_ms':stamps,'interval_ms':35,'note':'Timing relative to capture process, after IPC was launched; no slowed animation.'},indent=2))
PY
wait "$motion_ipc_pid"
sleep .2; shot 07-settled
ipc close
alive || fail 'quickshell died'
echo 'round2: ok'
