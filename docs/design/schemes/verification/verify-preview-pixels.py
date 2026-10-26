"""Read-only palette propagation check of actual headless PNGs.

Opaque signal/text/surface pigments must occur exactly. Field sample permits
one channel level because Session's 0.97 alpha plane uses premultiplied colour
rounding. textDim exact pixel counts are diagnostic: small antialiased text
need not include a full-coverage pixel in that pigment.
"""
from PIL import Image
from pathlib import Path
import json,subprocess
base=Path(__file__).resolve().parent
root=base.parents[3]
palette=json.loads(subprocess.check_output(['node','--input-type=module','-e','import {SCHEMES} from "./shell/lib/schemes.mjs"; console.log(JSON.stringify(SCHEMES));'],cwd=root,text=True))
results=[]
for view in ['lock','osd','session']:
 for scheme in palette:
  p=base/'runs'/(view+'-schemes')/(scheme['id']+'.png')
  im=Image.open(p).convert('RGB')
  counts={color:n for n,color in im.getcolors(im.width*im.height)}
  roles={}
  for role in ['obsidian','surface','signal','text','textDim']:
   value=scheme['palette'][role]
   rgb=tuple(int(value[i:i+2],16) for i in [1,3,5])
   roles[role]=counts.get(rgb,0)
  field=scheme['palette']['obsidian']
  expected=tuple(int(field[i:i+2],16) for i in [1,3,5])
  actual=im.getpixel((0,0))
  delta=max(abs(a-b) for a,b in zip(expected,actual))
  result={'view':view,'scheme':scheme['id'],'dimensions':[im.width,im.height],'exact_palette_pixels':roles,'field_sample':actual,'expected_field':expected,'field_max_channel_error':delta,'pass':all(roles[r]>0 for r in ['surface','signal','text']) and delta<=1}
  results.append(result)
(base/'preview-pixel-verification.json').write_text(json.dumps(results,indent=2)+'\n')
failed=[r for r in results if not r['pass']]
print(json.dumps({'images':len(results),'pass':len(results)-len(failed),'failed':failed},indent=2))
raise SystemExit(bool(failed))
