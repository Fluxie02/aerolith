# shellcheck shell=bash
# Root schedules 35/70ms close with a one-shot Qt Timer, in a diagnostic copy.
set -e
sleep 5
swaymsg -t get_outputs -r >"$OUT/outputs.json"
python3 - "$SHELL_DIR" "$OUT" <<'PY'
import json,subprocess,sys,time
shell,out=sys.argv[1:];rows=[]
def call(target,*args):
    return subprocess.check_output(['qs','-p',shell,'ipc','call',target]+list(args),text=True)
for delay in (35,70):
    for repeat in range(3):
        call('aerolith','close');time.sleep(.35)
        data=json.loads(call('ui016interrupt','play',str(delay)))
        scheduled=data['scheduledOpenMs']/1000
        for sample,target in enumerate((0,.016,.032,.048,.064,.080,.096,.112,.128,.160,.200,.240,.280,.320)):
            time.sleep(max(0,scheduled+target-time.time()))
            began=time.time();name=f'close-{delay}-{repeat}-{sample:02d}.png'
            subprocess.run(['grim','-g','680,195 115x115',out+'/'+name],check=True)
            ended=time.time()
            rows.append({'close_delay_ms':delay,'repeat':repeat,'sample':sample,'file':name,
                'target_after_scheduled_open_ms':target*1000,
                'capture_start_after_scheduled_open_ms':(began-scheduled)*1000,
                'capture_end_after_scheduled_open_ms':(ended-scheduled)*1000,
                'scheduled_open_unix_ms':data['scheduledOpenMs'],
                'method':'Actual software-rendered crop. Native frame lies within capture interval. Qt one-shot Timer logs actual open/close wall times; no frame interpolation or per-frame production JS.'})
json.dump(rows,open(out+'/captures.json','w'),indent=2)
PY
alive
echo 'UI-016 fast-close render-position sequence complete'
