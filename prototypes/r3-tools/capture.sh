# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
# Capture the actual first process start, without slowing or replaying it.
python3 - "$OUT" <<'PY'
import json, subprocess, sys, time
from pathlib import Path
out=Path(sys.argv[1]); start=time.monotonic(); stamps=[]; jobs=[]
schedule=[0,.10,.25,.45,.75,1.15,1.85,2.75]
for i,due in enumerate(schedule,1):
    time.sleep(max(0,start+due-time.monotonic()))
    stamps.append(round((time.monotonic()-start)*1000,1))
    jobs.append(subprocess.Popen(['grim',str(out/('00-boot-%02d.png'%i))]))
for job in jobs: assert job.wait()==0
(out/'boot-timing.json').write_text(json.dumps({'capture_start_ms':stamps,'reference':'scenario entry after Configuration Loaded; process start precedes this','real_time':True},indent=2)+'\n')
PY
sleep 3
shot 01-idle
ipc status >"$OUT/status-idle.json"
ipc open command >/dev/null
sleep .3; typ '@ a'; sleep .3; shot 02-command
ipc close; sleep .25
ipc open navigator >/dev/null; sleep .4; shot 03-navigator
# Exercise existing coherent directional selection and move/cancel keys.
key Right; key Tab; key m; key Escape
ipc close; sleep .25
ipc open systems >/dev/null; sleep 4; shot 04-systems
ipc status >"$OUT/status-systems.json"
python3 - "$OUT/status-systems.json" <<'PY' || fail 'systems telemetry'
import json,sys
s=json.load(open(sys.argv[1]));assert s['telemetryIntervalMs']==1000,s
assert s['cpuPercent'] is not None and s['memoryPercent'] is not None,s
PY
key m; key c
ipc close; sleep .25
ipc status >"$OUT/status-closed.json"
python3 - "$OUT/status-closed.json" <<'PY' || fail 'demand release'
import json,sys
s=json.load(open(sys.argv[1])); assert s['telemetryIntervalMs']==5000,s
PY
ipc open signal >/dev/null; sleep 1; shot 05-sound
key Down; key Up; ipc close; sleep .3
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify AEROLITH 0 "" "Workspace route updated" "Window register and workspace arc are linked to the compositor." "[]" "{}" 3500 >/dev/null
sleep .2; shot 06-notice
ipc open command >/dev/null; sleep .25; shot 09-notice-over-deck
ipc close; sleep 4
python3 - "$OUT" <<'PY'
import json, os, subprocess, sys, time
from pathlib import Path
out=Path(sys.argv[1]); start=time.monotonic(); stamps=[]; jobs=[]
opener=subprocess.Popen(['qs','-p',os.environ['SHELL_DIR'],'ipc','call','aerolith','open','command'],stdout=subprocess.DEVNULL)
for i in range(6):
    time.sleep(max(0,start+i*.035-time.monotonic()))
    stamps.append(round((time.monotonic()-start)*1000,1))
    jobs.append(subprocess.Popen(['grim',str(out/('07-opening-%02d.png'%(i+1)))]))
for job in jobs: assert job.wait()==0
assert opener.wait()==0
(out/'opening-timing.json').write_text(json.dumps({'capture_start_ms':stamps,'interval_ms':35,'reference':'launch of real open IPC; no slowed animation'},indent=2)+'\n')
PY
sleep .25; shot 08-settled
ipc close; sleep .3
# A real command proves text still takes keys and executes through Registry.
ipc open command >/dev/null; sleep .8; typ 'vol 42'; sleep .4; key Return; sleep 1.5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.42' || fail 'command keys did not set volume'
alive || fail 'quickshell died'
echo 'round3 capture: ok'
