# Sourced by the copied headless session, after the benchmark matrix ends.
set -e
sleep 8
swaymsg -t get_outputs -r > "$OUT/outputs.json"
python3 - "$SHELL_DIR" "$OUT" <<'PY'
import json,os,signal,subprocess,sys,time
shell,out=sys.argv[1:]
log=open(out+'/recorder.log','w')
recorder=subprocess.Popen(['/capture-tools/wf-recorder','--no-dmabuf','-D','-r','30','-y','-o','HEADLESS-1',
    '-c','libx264','-p','preset=ultrafast','-p','crf=20','-p','threads=2','-x','yuv420p','-f',out+'/raw.mkv'],stdout=log,stderr=subprocess.STDOUT)
launch=time.monotonic();time.sleep(.5);epoch=time.monotonic()
json.dump({'recorder_launch_monotonic':launch,'event_epoch_monotonic':epoch,'event_epoch_unix':time.time(),
    'target_clip_seconds':12,'method':'Actual compositor recording, configured 144 Hz output, 30 fps constant encode. No interpolation or playback retiming.'},open(out+'/clock.json','w'),indent=2)
events=open(out+'/events.jsonl','w',buffering=1)
def ipc(*args):return ['qs','-p',shell,'ipc','call','aerolith']+list(args)
def keys(*names):
    result=['wtype','-k','Shift_L']
    for name in names:result+=['-k',name]
    return result
def at(t,label,args):
    time.sleep(max(0,epoch+t-time.monotonic()));begin=time.monotonic()
    result=subprocess.run(args,capture_output=True,text=True,check=True)
    events.write(json.dumps({'event':label,'start_seconds':begin-epoch,'end_seconds':time.monotonic()-epoch,'argv':args,'stdout':result.stdout})+'\n')
try:
    at(.8,'Deck open / Command',ipc('open','command'))
    at(2,'Bay switch / Navigator',ipc('open','navigator'))
    at(3.2,'Bay switch / Settings',ipc('open','settings'))
    at(3.7,'Spectra / Limb',keys('Home','Return'))
    at(4.3,'Spectra / Bathyal',keys('Right','Return'))
    at(5.2,'Spectra / Corona',keys('Right','Return'))
    at(6.2,'Deck close / ambient stroke resumes',ipc('close'))
    at(7.3,'Workspace 2',ipc('run','workspace.focus','{"workspace":2}'))
    at(9,'Workspace 1',ipc('run','workspace.focus','{"workspace":1}'))
    time.sleep(max(0,epoch+12-time.monotonic()))
finally:
    recorder.send_signal(signal.SIGINT);recorder.wait(timeout=20);events.close();log.close()
if recorder.returncode:raise SystemExit(recorder.returncode)
PY
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/config-final.json"
alive
echo 'UI-016 illustrative Wayland recording complete'
