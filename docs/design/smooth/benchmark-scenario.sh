# Sourced by the copied headless session. No service/host changes are required.
set -e
sleep 12
swaymsg -t get_outputs -r > "$OUT/outputs.json"
mock '{"op":"state"}' > "$OUT/mock-state.json"
ipc status > "$OUT/status.json"

# Monotonic milliseconds match the compositor's uint32 wl_callback.done time.
mark() { python3 - "$OUT/events.jsonl" "$1" "$2" <<'PY'
import json,sys,time
with open(sys.argv[1], 'a') as f:
    f.write(json.dumps({'event':sys.argv[2], 'edge':sys.argv[3], 'monotonic_ms':time.monotonic()*1000, 'wall_time':time.time()})+'\n')
PY
}
action() {
  local name=$1; shift
  mark "$name" start
  "$@" >/dev/null
  # Workspace rotation lasts Theme.slow*2 (520ms). CPU action sequence stays
  # matched; timing observes the complete event rather than clipping its tail.
  if [[ "$UI016_KIND" = timing && "$name" = workspace-switch-* ]]; then sleep .7; else sleep .36; fi
  mark "$name" end
}
actions() {
  for n in 1 2 3 4 5; do
    action deck-open-$n ipc open command
    action bay-switch-$n ipc open navigator
    action deck-close-$n ipc close
    action workspace-switch-$n mock "{\"op\":\"focus_workspace\",\"workspace\":$((n % 2 + 1))}"
  done
  ipc open settings >/dev/null; sleep .6
  key Home; key Return; sleep .4
  for n in 1 2 3 4 5; do
    action spectra-switch-$n wtype -k Shift_L -k Right -k Return
  done
  ipc close
}
if [ "$UI016_KIND" = cpu ]; then
  # /proc reads are outside the shell. No frame logging or screenshots here.
  cpu_sample() {
    local name=$1 duration=$2
    python3 - "$QS_PID" "$OUT/cpu-$name-start.json" <<'PY'
import json,os,sys,time
p=sys.argv[1]; stat=open('/proc/'+p+'/stat').read().split()
json.dump({'time':time.monotonic(),'ticks':int(stat[13])+int(stat[14]),'hz':os.sysconf('SC_CLK_TCK')},open(sys.argv[2],'w'))
PY
    if [ "$name" = active ]; then actions; else sleep "$duration"; fi
    python3 - "$QS_PID" "$OUT/cpu-$name-start.json" "$OUT/cpu-$name.json" <<'PY'
import json,sys,time
p=sys.argv[1]; a=json.load(open(sys.argv[2])); stat=open('/proc/'+p+'/stat').read().split()
wall=time.monotonic()-a['time']; ticks=int(stat[13])+int(stat[14])-a['ticks']; cpu=ticks/a['hz']
json.dump({'seconds':round(wall,4),'cpu_seconds':cpu,'cpu_percent_one_core':round(cpu/wall*100,3),'method':'Uninstrumented shell process utime+stime; no screenshots, logging or parallel tests.'},open(sys.argv[3],'w'),indent=2)
PY
  }
  cpu_sample idle 120
  cpu_sample active 0
elif [ "$UI016_KIND" = timing ]; then
  # Covers at least one complete Saturated 144Hz cost-controlled cadence.
  mark background start; sleep 30; mark background end
  actions
elif [ "$UI016_KIND" = capture ]; then
  mkdir -p "$OUT/frames"
  python3 - "$SHELL_DIR" "$OUT" <<'PY'
import json,subprocess,sys,time
shell,out=sys.argv[1:]; start=time.monotonic(); rows=[]
for i in range(60):
    time.sleep(max(0,start+i/30-time.monotonic()))
    if i in (2,20,40):
        args=['open','command'] if i==2 else ['open','navigator'] if i==20 else ['close']
        subprocess.run(['qs','-p',shell,'ipc','call','aerolith']+args,check=True,stdout=subprocess.DEVNULL)
    begin=time.monotonic()-start
    subprocess.run(['grim',out+'/frames/frame-%02d.png'%i],check=True)
    rows.append({'frame':i,'capture_start_s':round(begin,5),'capture_end_s':round(time.monotonic()-start,5)})
json.dump({'method':'Actual 1920x1080 grim frames; target 30 fps; no interpolation. Capture cost means these are illustration only, not frame pacing measurements.','frames':rows},open(out+'/capture-timing.json','w'),indent=2)
PY
fi
alive
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/config-final.json"
echo "UI-016 $UI016_KIND done: $RES"
