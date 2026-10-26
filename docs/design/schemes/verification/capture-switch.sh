set -e
sleep 4
ipc open settings
sleep 1
key Home
key Return
sleep .3
mkdir -p "$OUT/frames"
OUT="$OUT" python3 - <<'PY'
import json,os,subprocess,time
out=os.environ['OUT']; start=time.monotonic(); rows=[]
for i in range(16):
    deadline=start+i*.2
    time.sleep(max(0,deadline-time.monotonic()))
    if i in (4,10):
        subprocess.run(['wtype','-k','Shift_L','-k','Right','-k','Return'],check=True)
    before=time.monotonic()-start
    subprocess.run(['grim',f'{out}/frames/frame-{i:02d}.png'],check=True)
    rows.append({'frame':i,'capture_start_s':round(before,4),'capture_end_s':round(time.monotonic()-start,4),'input':'Right, Return' if i in (4,10) else None})
json.dump({'method':'Actual grim captures, target cadence 200ms; no synthetic interpolation. Two keyboard selections in the same live production Settings bay.','frames':rows},open(out+'/timing.json','w'),indent=2)
PY
alive || exit 1
echo 'live switch sequence: limb -> bathyal -> corona'
