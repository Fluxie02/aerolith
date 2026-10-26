#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageChops
import json,sys
out=Path(sys.argv[1]);results=[]
for mode in ('off','low'):
 a=Image.open(out/f'{mode}-still-1.png').convert('RGB')
 b=Image.open(out/f'{mode}-still-2.png').convert('RGB')
 roi=(100,220,1400,1000)
 bbox=ImageChops.difference(a.crop(roi),b.crop(roi)).getbbox()
 results.append({'mode':mode,'roi':roi,'difference_bbox':bbox})
 assert bbox is None,(mode,bbox)
(out/'stationary-pixels.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
