#!/usr/bin/env python3
"""Actual-pixel fast-close probe; all instrumentation lives in a copied shell.
Usage: python3 docs/design/smooth/verification/scripts/run-interruption.py before|after 60|144
"""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys, time
from PIL import Image
ROOT=Path(__file__).resolve().parents[5]
phase,rate=sys.argv[1:]
assert phase in ('before','after') and rate in ('60','144')
base=ROOT/'build/ui016'
source=base/f'{phase}-shell'
copy=base/'verification'/f'{phase}-{rate}-interruption-shell'
if copy.exists(): shutil.rmtree(copy)
shutil.copytree(source,copy)
chord=copy/'components/ChordSlot.qml'
text=chord.read_text(); point=text.rfind('}')
chord.write_text(text[:point]+'''    // UI-016 pixel marker, diagnostic snapshot only.
    Rectangle { x: 0; y: 0; width: 10; height: 10; color: "#ff00ff"; z: 100000 }
'''+text[point:])
entry=copy/'shell.qml'; text=entry.read_text()
text=text.replace('import Quickshell\n','import Quickshell\nimport Quickshell.Io\n',1)
probe='''
    property int probeDelay: 35
    Timer {
        id: probeOpen; interval: 500; repeat: false
        onTriggered: {
            console.warn("UI016_PROBE_OPEN " + Date.now() + " delay=" + shell.probeDelay);
            Ui.open("command");
            probeClose.interval = shell.probeDelay;
            probeClose.restart();
        }
    }
    Timer {
        id: probeClose; repeat: false
        onTriggered: {
            console.warn("UI016_PROBE_CLOSE " + Date.now() + " delay=" + shell.probeDelay);
            Ui.close();
        }
    }
    IpcHandler {
        target: "ui016interrupt"
        function play(delay: int): string {
            shell.probeDelay = delay;
            const scheduled = Date.now() + 500;
            probeOpen.restart();
            return JSON.stringify({scheduledOpenMs: scheduled, closeDelayMs: delay});
        }
    }
'''
text=text.replace('    Component.onCompleted: {',probe+'\n    Component.onCompleted: {',1)
entry.write_text(text)
out=ROOT/'docs/design/smooth/verification/interruption'/f'{phase}-{rate}'
out.mkdir(parents=True,exist_ok=True);out.chmod(0o777)
manifest={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source.rglob('*')) if p.is_file()}
(out/'source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
subprocess.run([sys.executable,str(ROOT/'docs/design/smooth/prepare-session.py')],check=True)
config=base/'verification'/f'{phase}-{rate}-interruption.json'
config.write_text(json.dumps({'schemaVersion':1,'theme':{'motion':'full','intensity':'saturated'}}))
scenario='docs/design/smooth/verification/scripts/interruption-scenario.sh'
command=['docker','run','--rm','--cap-add=SYS_NICE','-v',f'{ROOT}:/src:ro','-v',f'{out}:/out',
         '-e',f'UI016_HZ={rate}','-e','UI016_KIND=position','-e',f'SHELL_PATH={copy.relative_to(ROOT)}',
         '-e',f'RES=1920x1080@{rate}Hz','-e',f'UI016_CONFIG=/src/{config.relative_to(ROOT)}',
         'aerolith-dev','bash','-c','''set -e
id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
mkdir -p /run/user/1000 /home/pilot/.config/aerolith
chown pilot /run/user/1000; chmod 700 /run/user/1000
cp "$UI016_CONFIG" /home/pilot/.config/aerolith/config.json
chown -R pilot /home/pilot
exec su pilot -c "bash /src/build/ui016/session.sh /src/'''+scenario+'"']
start=time.monotonic()
with (out/'result.txt').open('w') as log:
    log.write(json.dumps(command)+'\n');log.flush()
    proc=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    log.write(f'\nEXIT {proc.returncode}\n')
(out/'result.json').write_text(json.dumps({'command':command,'exit_code':proc.returncode,'elapsed_seconds':time.monotonic()-start},indent=2)+'\n')
if (out/'qs.log').exists():shutil.copyfile(out/'qs.log',out/'qs.txt')
if proc.returncode:raise SystemExit(proc.returncode)
rows=json.loads((out/'captures.json').read_text())
for row in rows:
    image=Image.open(out/row['file']).convert('RGB')
    points=[]
    for y in range(image.height):
        for x in range(image.width):
            r,g,b=image.getpixel((x,y))
            if r>110 and g<85 and b>110:points.append((x,y))
    row['marker_pixels']=len(points)
    if points:
        row['marker_screen_x']=round(680+sum(p[0] for p in points)/len(points),3)
        row['marker_screen_y']=round(195+sum(p[1] for p in points)/len(points),3)
marker_file=out/'captures-markers.json'
temporary=out/'captures-markers.tmp'
temporary.write_text(json.dumps(rows,indent=2)+'\n')
temporary.replace(marker_file)
print(out.relative_to(ROOT))
