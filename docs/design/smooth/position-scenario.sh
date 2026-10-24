# A diagnostic marker is attached to the actual ChordSlot in a copied shell.
set -e
sleep 5
swaymsg -t get_outputs -r > "$OUT/outputs.json"
python3 - "$SHELL_DIR" "$OUT" <<'PY'
import json,subprocess,sys,time
shell,out=sys.argv[1:]; rows=[]
def ipc(*args):
    subprocess.run(['qs','-p',shell,'ipc','call','aerolith']+list(args),stdout=subprocess.DEVNULL,check=True)
for repeat in range(3):
    ipc('close'); time.sleep(.35)
    before=time.monotonic()
    ipc('open','command')
    returned=time.monotonic()
    for sample,target in enumerate((0,.04,.08,.12,.16,.20,.24)):
        time.sleep(max(0,returned+target-time.monotonic()))
        begin=time.monotonic(); name=f'position-{repeat}-{sample}.png'
        subprocess.run(['grim','-g','680,195 115x115',out+'/'+name],check=True)
        end=time.monotonic()
        rows.append({'repeat':repeat,'target_after_ipc_return_ms':target*1000,'file':name,
            'ipc_call_ms':(returned-before)*1000,'capture_start_after_ipc_return_ms':(begin-returned)*1000,
            'capture_end_after_ipc_return_ms':(end-returned)*1000,
            'method':'Actual crop; frame timestamp lies inside capture interval. Animation begins before IPC returns; call length records the upper bound on that offset.'})
json.dump(rows,open(out+'/positions.json','w'),indent=2)
PY
alive
echo 'UI-016 actual ChordSlot position sequence complete'
