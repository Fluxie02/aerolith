# shellcheck shell=bash
# Exercise an actual Ground surface unmap/remap using its supported config.
# This checks restoration only; it does not implement Claude's fullscreen mode.
fail() { echo "FAIL: $*"; exit 1; }
sleep 4
shot remap-before
for enabled in false true; do
  python3 - "$enabled" <<'PY'
import json, os, sys
from pathlib import Path
p=Path(os.environ['XDG_CONFIG_HOME'])/'aerolith/config.json'
d=json.loads(p.read_text());d.setdefault('ground',{})['enabled']=sys.argv[1]=='true'
p.write_text(json.dumps(d))
PY
  ipc reload >/dev/null
  if [ "$enabled" = false ]; then sleep .3; shot remap-hidden; else
    python3 - "$OUT" <<'PY'
import subprocess, sys, time
from pathlib import Path
out=Path(sys.argv[1]);start=time.monotonic();jobs=[]
for i,t in enumerate([0,.10,.25,.6],1):
    time.sleep(max(0,start+t-time.monotonic()))
    jobs.append(subprocess.Popen(['grim',str(out/('remap-return-%02d.png'%i))]))
for j in jobs: assert j.wait()==0
PY
  fi
done
ipc open command >/dev/null; sleep .5; typ 'vol 37'; sleep .4; key Return; sleep 1
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '0.37' || fail 'keys after remap'
alive || fail 'quickshell died'
echo 'round3 remap: ok'
