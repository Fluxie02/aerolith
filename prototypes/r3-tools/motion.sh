# shellcheck shell=bash
# Run alone: simultaneous boot/capture workloads can miss short open frames.
sleep 4
python3 - "$OUT" <<'PY'
import json, os, subprocess, sys, time
from pathlib import Path
out=Path(sys.argv[1]);start=time.monotonic();jobs=[];stamps=[]
opener=subprocess.Popen(['qs','-p',os.environ['SHELL_DIR'],'ipc','call','aerolith','open','command'],stdout=subprocess.DEVNULL)
for i in range(6):
    time.sleep(max(0,start+i*.035-time.monotonic()))
    stamps.append(round((time.monotonic()-start)*1000,1))
    jobs.append(subprocess.Popen(['grim',str(out/('07-opening-%02d.png'%(i+1)))]))
for j in jobs: assert j.wait()==0
assert opener.wait()==0
(out/'opening-timing.json').write_text(json.dumps({'capture_start_ms':stamps,'interval_ms':35,'reference':'real IPC launch, one variant at a time, original 160 ms duration'},indent=2)+'\n')
PY
sleep .3; shot 08-settled
ipc close; sleep .3
alive || { echo 'FAIL: quickshell died'; exit 1; }
echo 'round3 motion: ok'
