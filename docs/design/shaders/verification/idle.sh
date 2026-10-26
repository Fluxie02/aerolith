# Matched UI-013-style idle CPU sample. /proc process CPU, not GPU cost.
sleep 15
python3 - "$QS_PID" "$OUT/idle.json" <<'PY'
import json,sys,time,os
from pathlib import Path
pid,out=sys.argv[1:]
def snap():
 s=Path(f'/proc/{pid}/stat').read_text().split()
 return int(s[13])+int(s[14])
t0=snap(); wall=time.monotonic(); time.sleep(120)
wall=time.monotonic()-wall
cpu=(snap()-t0)/os.sysconf('SC_CLK_TCK')
Path(out).write_text(json.dumps({'seconds':round(wall,3),'cpu_seconds':cpu,'cpu_percent_one_core':round(cpu*100/wall,3),'backend':'Qt software / sway pixman'},indent=2)+'\n')
PY
cat "$OUT/idle.json"
alive
