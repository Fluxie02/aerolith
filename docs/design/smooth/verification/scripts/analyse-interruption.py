#!/usr/bin/env python3
"""Read captured pixels, preserving container-owned original timing JSON."""
from pathlib import Path
from PIL import Image
import json,sys
BASE=Path(__file__).resolve().parents[1]/'interruption'
paths=[Path(x) for x in sys.argv[1:]] or sorted(BASE.glob('*-*'))
for out in paths:
 if not (out/'captures.json').exists():continue
 rows=json.loads((out/'captures.json').read_text())
 for row in rows:
  image=Image.open(out/row['file']).convert('RGB');points=[]
  for y in range(image.height):
   for x in range(image.width):
    r,g,b=image.getpixel((x,y))
    if r>110 and g<85 and b>110:points.append((x,y))
  row['marker_pixels']=len(points)
  if points:
   row['marker_screen_x']=round(680+sum(p[0] for p in points)/len(points),3)
   row['marker_screen_y']=round(195+sum(p[1] for p in points)/len(points),3)
 temporary=out/'captures-markers.tmp'
 temporary.write_text(json.dumps(rows,indent=2)+'\n')
 temporary.replace(out/'captures-markers.json')
 print(out.name,'captures',len(rows),'with marker',sum(r['marker_pixels']>0 for r in rows))
