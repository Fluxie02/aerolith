from pathlib import Path
import os,subprocess,sys,json,shutil,time
root=next(p for p in Path(__file__).resolve().parents if (p / "AGENTS.md").exists())
build=root/'build/ui015/verification'
docs=root/'docs/design/schemes/verification'
mode=sys.argv[1]
runs=[]
if mode=='scenarios':
  cases=[
    ('smoke','tests/scenarios/smoke.sh',{'CONFIG':str(build/'saturated.json')}),
    ('full','tests/scenarios/full.sh',{'AUDIO':'1','MEDIA':'1','MPV_AO':'pipewire','ROUTINES':'tests/fixtures/routines.json','CONFIG':str(build/'saturated.json')}),
    ('deck','tests/scenarios/deck.sh',{'AUDIO':'1','HYPR_MOCK_ARGS':'--mode 2560x1440 --scale 1.5 --transform 1','CONFIG':str(build/'insane.json')}),
    ('ai','tests/scenarios/ai.sh',{'AUDIO':'1','AI':'1','CONFIG':str(build/'insane.json')})
  ]
elif mode=='previews':
  cases=[(kind+'-schemes','build/ui015/verification/capture-'+kind+'.sh',{'SHELL_PATH':'build/ui015/verification/preview-'+kind}) for kind in ['lock','osd','session']]
elif mode=='compact':
  cases=[(kind+'-compact','build/ui015/verification/compact-preview.sh',{'SHELL_PATH':'build/ui015/verification/preview-'+kind,'RES':'1280x720'}) for kind in ['lock','osd','session']]
elif mode=='settings':
  cases=[('settings-focus','build/ui015/verification/settings-focus.sh',{'CONFIG':str(build/'saturated.json')})]
elif mode=='perf':
  cases=[('piyti-'+i+'-perf','tests/scenarios/perf.sh',{'AUDIO':'1','MEDIA':'1','CONFIG':str(build/(i+'.json'))}) for i in ['saturated','insane']]
else: raise SystemExit('unknown mode')
for name,scenario,extra in cases:
  out=build/name
  env=os.environ.copy()
  for key in ['CONFIG','AUDIO','MEDIA','MPV_AO','ROUTINES','AI','HYPR_MOCK_ARGS','RES','SCALE']: env.pop(key,None)
  settings={'SHELL_PATH':'build/ui015/verification/final-shell'}
  settings.update(extra)
  env.update(settings)
  command=['tools/headless/run.sh',scenario,str(out.relative_to(root))]
  label=' '.join(k+'='+json.dumps(v) for k,v in settings.items())+' '+' '.join(command)
  log=docs/'runs'/(name+'-result.txt')
  for attempt in [1,2]:
    start=time.time()
    with log.open('w') as f:
      f.write(label+'\n');f.flush()
      result=subprocess.run(command,cwd=root,env=env,stdout=f,stderr=subprocess.STDOUT)
      f.write('\nexit '+str(result.returncode)+'\n')
    q=out/'qs.log'
    qtext=q.read_text(errors='replace') if q.exists() else ''
    startup_race='Configuration Loaded' not in qtext and 'wl_display' in qtext
    if result.returncode and startup_race and attempt==1:
      target=docs/'attempts'/(name+'-wayland')
      if target.exists(): shutil.rmtree(target)
      shutil.copytree(out,target)
      shutil.copy2(log,target/'result.txt')
      print(name+': excluded Wayland readiness startup attempt; retrying',flush=True)
      continue
    break
  dest=docs/'runs'/name
  if dest.exists():shutil.rmtree(dest)
  shutil.copytree(out,dest,ignore=shutil.ignore_patterns('pipewire.log','wireplumber.log','sway.log','sway.conf','mpv.log','mock.log'))
  record={'name':name,'command':label,'exit':result.returncode,'attempts':attempt,'wall_seconds':round(time.time()-start,1)}
  runs.append(record)
  (docs/(mode+'-results.json')).write_text(json.dumps(runs,indent=2)+'\n')
  print(name+': exit '+str(result.returncode),flush=True)
  if result.returncode: print(log.read_text()[-2500:],flush=True)
raise SystemExit(any(r['exit'] for r in runs))
