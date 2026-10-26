from pathlib import Path
import json,shutil
b=Path('build/ui009');o=Path('docs/design/review/verification');(o/'runs').mkdir(parents=True,exist_ok=True)
accepted=[]
for intensity in ('saturated','insane'):
 for scenario in ('smoke','full','signal','deck','notify','ai'):
  run=f'verified-{intensity}-{scenario}'
  if scenario=='ai' or (intensity=='insane' and scenario in ('deck','notify')):run=f'retry-{intensity}-{scenario}'
  p=b/(run+'-result.txt');s=p.read_text();assert scenario+': ok' in s,(run,s[-500:])
  env={'SHELL_PATH':'build/ui009/verified-shell','CONFIG':f'build/ui009/{intensity}-full.json'}
  if scenario in ('full','signal'):env.update(AUDIO='1',MEDIA='1',MPV_AO='pipewire',ROUTINES='tests/fixtures/routines.json')
  if scenario=='deck':env.update(AUDIO='1',HYPR_MOCK_ARGS='--mode 2560x1440 --scale 1.5 --transform 1')
  if scenario=='notify':env['CONFIG']=f'build/ui009/notify-{intensity}.json'
  if scenario=='ai':env.update(AUDIO='1',AI='1')
  accepted.append({'intensity':intensity,'scenario':scenario,'run':run,'environment':env,'command':f'tools/headless/run.sh tests/scenarios/{scenario}.sh build/ui009/{run}','result':'passed','stream_routing_skipped':"SKIP: stream routing" in s})
for p in b.glob('*-result.txt'):shutil.copy2(p,o/'runs'/p.name)
for name in ('saturated-required.txt','insane-required.txt','verified-saturated-required.txt','verified-insane-required.txt'):shutil.copy2(b/name,o/'runs'/name)
(o/'scenarios.json').write_text(json.dumps(accepted,indent=2)+'\n')
print(json.dumps(accepted,indent=2))
