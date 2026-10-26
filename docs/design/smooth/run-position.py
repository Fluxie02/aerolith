"""Capture actual ChordSlot position; magenta marker exists only in a copy.

Usage: python3 docs/design/smooth/run-position.py before|after 60|144
The marker moves with the whole retained bay, including its real transforms.
"""
import json, shutil, subprocess, sys
from pathlib import Path

repo=Path(__file__).resolve().parents[3]
phase,rate=sys.argv[1:]
assert phase in ('before','after') and rate in ('60','144')
source=repo/'build/ui016'/f'{phase}-shell'
diagnostic=repo/'build/ui016'/f'{phase}-position-shell'
shutil.copytree(source,diagnostic,dirs_exist_ok=True)
chord=diagnostic/'components/ChordSlot.qml'
text=chord.read_text(); point=text.rfind('}')
start_log='    onPresentedChanged: if (presented) console.log("UI016_DOCK_START " + Date.now() + " generation=" + presentationGeneration)\n' if phase=='after' else ''
chord.write_text(text[:point]+start_log+'''    // UI-016 measurement fiducial; diagnostic copy only.
    Rectangle { x: 0; y: 0; width: 10; height: 10; color: "#ff00ff"; z: 100000 }
'''+text[point:])
out=repo/'docs/design/smooth/data'/f'{phase}-{rate}-position'
out.mkdir(parents=True,exist_ok=True); out.chmod(0o777)
subprocess.run([sys.executable,str(repo/'docs/design/smooth/prepare-session.py')],check=True)
config=repo/'build/ui016'/f'{phase}-{rate}-position.json'
config.write_text(json.dumps({'schemaVersion':1,'theme':{'motion':'full','intensity':'saturated'}}))
command=['docker','run','--rm','--cap-add=SYS_NICE','-v',f'{repo}:/src:ro','-v',f'{out}:/out',
    '-e',f'UI016_HZ={rate}','-e','UI016_KIND=position','-e',f'SHELL_PATH={diagnostic.relative_to(repo)}',
    '-e',f'RES=1920x1080@{rate}Hz','-e',f'UI016_CONFIG=/src/{config.relative_to(repo)}',
    'aerolith-dev','bash','-c','''set -e
id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
mkdir -p /run/user/1000 /home/pilot/.config/aerolith
chown pilot /run/user/1000; chmod 700 /run/user/1000
cp "$UI016_CONFIG" /home/pilot/.config/aerolith/config.json
chown -R pilot /home/pilot
exec su pilot -c "bash /src/build/ui016/session.sh /src/docs/design/smooth/position-scenario.sh"
''']
with (out/'result.txt').open('w') as log: subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
from PIL import Image
rows=json.loads((out/'positions.json').read_text())
for row in rows:
    image=Image.open(out/row['file']).convert('RGB')
    points=[(x,y) for y in range(image.height) for x in range(image.width) if (lambda p:p[0]>110 and p[1]<85 and p[2]>110)(image.getpixel((x,y)))]
    row['marker_pixels']=len(points)
    if points:
        row['marker_screen_x']=round(680+sum(p[0] for p in points)/len(points),3)
        row['marker_screen_y']=round(195+sum(p[1] for p in points)/len(points),3)
if phase=='after':
    import re
    starts=[int(s) for s in re.findall(r'UI016_DOCK_START (\d+)',(out/'qs.log').read_text())]
    for row in rows:
        if row['repeat']<len(starts):
            row['docking_start_unix_ms']=starts[row['repeat']]
            row['capture_start_after_dock_ms']=row['capture_start_unix_ms']-starts[row['repeat']]
            row['capture_end_after_dock_ms']=row['capture_end_unix_ms']-starts[row['repeat']]
temporary=out/'positions-host.tmp'
temporary.write_text(json.dumps(rows,indent=2)+'\n')
temporary.replace(out/'positions.json')
print(f'position captures: {out.relative_to(repo)}')
