#!/usr/bin/env python3
"""Run/resume the final UI-016 functional matrix, at most two containers.
Run only after the timing harness explicitly releases exclusive benchmarks.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[5]
DOC=ROOT/'docs/design/smooth/verification'
DRIVER=Path(__file__).with_name('verify.py')
manifest=(DOC/'source-hashes.json').read_bytes()
digest=hashlib.sha256(manifest).hexdigest()
identity=DOC/'campaign-source-sha256.txt'
if identity.exists() and identity.read_text().strip()!=digest:
 raise SystemExit('Campaign source changed; archive previous campaign before rerunning.')
identity.write_text(digest+'\n')
cases=[]
for direction in ('piyti','thears'):
 for intensity in ('saturated','insane'):
  for scenario in (('smoke','full','deck','ai') if direction=='piyti' else ('smoke','deck')):
   cases.append((direction,intensity,scenario))
cases.append(('piyti','saturated','notify'))
def work(case):
 direction,intensity,scenario=case
 name=f'{direction}-{intensity}-full-{scenario}'
 result=DOC/'results'/f'{name}.json'
 if result.exists() and json.loads(result.read_text())['exit_code']==0:
  print(name+': retained passing result',flush=True)
  return json.loads(result.read_text())
 cmd=[sys.executable,str(DRIVER),scenario,'--direction',direction,'--intensity',intensity]
 proc=subprocess.run(cmd,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 print(proc.stdout.strip(),flush=True)
 if not result.exists():
  raise RuntimeError(name+': no result record, driver exit '+str(proc.returncode))
 return json.loads(result.read_text())
results=[]
with ThreadPoolExecutor(max_workers=2) as pool:
 for future in as_completed([pool.submit(work,case) for case in cases]):results.append(future.result())
results.sort(key=lambda r:r['name'])
(DOC/'final-command-index.json').write_text(json.dumps(results,indent=2)+'\n')
failed=[r for r in results if r['exit_code']]
print(f'Final matrix: {len(results)-len(failed)}/{len(results)} passed.',flush=True)
raise SystemExit(bool(failed))
