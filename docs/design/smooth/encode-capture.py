"""Encode actual screenshot timestamps as VFR video; never interpolate frames."""
import json,statistics,subprocess,sys
from pathlib import Path
out=Path(sys.argv[1]).resolve(); timing=json.loads((out/'capture-timing.json').read_text())
rows=timing['frames']; rows=[dict(r,time_s=(r['capture_start_s']+r['capture_end_s'])/2) for r in rows]
gaps=[b['time_s']-a['time_s'] for a,b in zip(rows,rows[1:])]
lines=['ffconcat version 1.0']
for i,row in enumerate(rows):
    lines.extend([f"file 'frames/frame-{row['frame']:02d}.png'",'option framerate 1000',f'duration {gaps[i] if i<len(gaps) else statistics.median(gaps):.6f}'])
(out/'frames.ffconcat').write_text('\n'.join(lines)+'\n')
subprocess.run(['ffmpeg','-y','-loglevel','warning','-f','concat','-safe','0','-i',str(out/'frames.ffconcat'),'-fps_mode','vfr','-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(out/'motion.mp4')],check=True)
timing['observed_effective_capture_fps']=(len(rows)-1)/(rows[-1]['time_s']-rows[0]['time_s'])
timing['median_capture_interval_ms']=statistics.median(gaps)*1000
timing['video_method']='VFR from actual capture-midpoint intervals, millisecond input time base; no interpolated frames.'
temporary=out/'capture-timing-host.tmp'
temporary.write_text(json.dumps(timing,indent=2)+'\n')
temporary.replace(out/'capture-timing.json')
print(json.dumps({k:v for k,v in timing.items() if k!='frames'},indent=2))
