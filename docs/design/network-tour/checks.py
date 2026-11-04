"""Run required scenarios serially and retain exact commands/results."""
import json
import os
from pathlib import Path
import subprocess
import sys

# Keep the archive small, complete and consistent with every linked filename.
evidence = Path(__file__).resolve().parent
manifest = json.loads((evidence / 'evidence.json').read_text())
shots = {p.relative_to(evidence).as_posix() for p in evidence.rglob('*.jpg')}
assert len(manifest) == len(shots) == 38
assert {shot['file'] for shot in manifest} == shots
assert not list(evidence.rglob('*.png'))
for shot in manifest:
    assert (evidence / shot['file']).read_bytes().startswith(b'\xff\xd8\xff')
size = sum(p.stat().st_size for p in evidence.rglob('*') if p.is_file())
assert size < 4 * 1024 * 1024, size
print(f'evidence: 38 JPEG shots, {size} bytes total', flush=True)
if '--evidence-only' in sys.argv:
    raise SystemExit(0)

out = Path('build/network-tour')
out.mkdir(parents=True, exist_ok=True)
cases = [
    ('smoke', {}, 'smoke'),
    ('deck', {'AUDIO':'1'}, 'deck'),
    ('app-links', {}, 'app-links'),
    ('fullscreen', {'AUDIO':'1','CONFIG':'tests/fixtures/notify-config.json'}, 'fullscreen'),
    ('network-present', {'NET':'1'}, 'network'),
    ('network-absent', {'NET':'0'}, 'network'),
    ('tour', {'TOUR':'1'}, 'tour'),
    ('oled', {'AI':'1','OUTPUTS':'2','CONFIG':'tests/fixtures/oled-config.json'}, 'oled'),
]
results = []
for name, overrides, scenario in cases:
    cmd = ['tools/headless/run.sh', f'tests/scenarios/{scenario}.sh', str(out/name)]
    display = ' '.join([f'{k}={v}' for k,v in overrides.items()] + cmd)
    print(display, flush=True)
    env = os.environ.copy()
    for key in ['NET','TOUR','AUDIO','AI','OUTPUTS','CONFIG','RES','SCALE','HYPR_MOCK_ARGS']:
        env.pop(key, None)
    env.update(overrides)
    result = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (out/(name+'.txt')).write_text(result.stdout)
    results.append({'name':name, 'command':display, 'exit':result.returncode})
    (out/'checks.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'{name}: exit {result.returncode}\n{result.stdout[-1600:]}', flush=True)
cmd=['node','tests/js/run-node.mjs']
r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
(out/'node.txt').write_text(r.stdout)
results.append({'name':'node','command':' '.join(cmd),'exit':r.returncode,'result':r.stdout.splitlines()[-1]})
(out/'checks.json').write_text(json.dumps(results,indent=2)+'\n')
print(r.stdout.splitlines()[-1],flush=True)
raise SystemExit(any(r['exit'] != 0 for r in results))
