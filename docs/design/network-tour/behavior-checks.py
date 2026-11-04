"""NB-2: run each behavior scenario three times, strictly serially."""
import json
import os
from pathlib import Path
import subprocess
import time

out = Path('build/nb2')
records = Path(__file__).resolve().parent / 'checks'
out.mkdir(parents=True, exist_ok=True)
results = []
for name, overrides, scenario, budget in [
    ('network-present', {'NET': '1'}, 'network', 180),
    ('network-absent', {'NET': '0'}, 'network', 180),
    ('tour', {'TOUR': '1'}, 'tour', 240),
    ('network-two-outputs', {'NET': '1', 'OUTPUTS': '2'}, 'network', 180),
]:
    for repeat in range(1, 2 if name == 'network-two-outputs' else 4):
        run = f'{name}-{repeat}'
        cmd = ['tools/headless/run.sh', f'tests/scenarios/{scenario}.sh', str(out/run)]
        display = ' '.join([f'{k}={v}' for k,v in overrides.items()] + cmd)
        print(display, flush=True)
        env = os.environ.copy()
        for key in ['NET', 'TOUR', 'OUTPUTS', 'CONFIG', 'RES', 'SCALE', 'AUDIO',
                    'MEDIA', 'AI', 'LOCK', 'SHELL_PATH', 'HYPR_MOCK', 'HYPR_MOCK_ARGS']:
            env.pop(key, None)
        env.update(overrides)
        start = time.monotonic()
        result = subprocess.run(cmd, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        elapsed = round(time.monotonic() - start, 2)
        (records/f'nb2-{run}.txt').write_text(result.stdout)
        results.append({'command': display, 'exit': result.returncode,
                        'seconds': elapsed, 'budget': budget})
        (records/'nb2-behavior.json').write_text(json.dumps(results, indent=2)+'\n')
        print(f'{run}: exit {result.returncode}, {elapsed}s\n{result.stdout[-800:]}', flush=True)
        if result.returncode or elapsed >= budget:
            raise SystemExit(f'{run} failed or exceeded its CI budget')
