"""Parse compositor callback pacing; do not count intentional idle as misses."""
import json, math, re, statistics, sys
from pathlib import Path

out=Path(sys.argv[1]); outputs=json.loads((out/'outputs.json').read_text())
refresh=outputs[0]['current_mode']['refresh']/1000
summary={'output_mode':outputs[0]['current_mode'],'refresh_hz':refresh}
if (out/'cpu-idle.json').exists():
    summary['cpu']={k:json.loads((out/('cpu-'+k+'.json')).read_text()) for k in ('idle','active')}
if 'timing' in out.name:
    # WAYLAND_DEBUG's callback IDs may be reused after delete_id.
    surfaces={}; pending={}; frames=[]
    for line in (out/'qs.log').read_text(errors='replace').splitlines():
        m=re.search(r'get_layer_surface\(new id zwlr_layer_surface_v1#?(\d+), wl_surface#?(\d+),.*"(aerolith-[^\"]+)"',line)
        if m: surfaces[m[2]]=m[3]
        m=re.search(r'wl_surface[#@](\d+)\.frame\(new id wl_callback[#@](\d+)',line)
        if m: pending[m[2]]=m[1]
        m=re.search(r'wl_callback[#@](\d+)\.done\((\d+)\)',line)
        if m and m[1] in pending:
            sid=pending.pop(m[1]); frames.append({'surface':surfaces.get(sid,sid),'time_ms':int(m[2])})
    (out/'callback-frames.json').write_text(json.dumps(frames,indent=2)+'\n')
    events=[json.loads(x) for x in (out/'events.jsonl').read_text().splitlines()]
    segments=[]
    for a,b in zip(events[::2],events[1::2]):
        start=a['monotonic_ms']%(2**32); end=b['monotonic_ms']%(2**32)
        selected=[f for f in frames if start<=f['time_ms']<=end]
        groups={}
        for f in selected: groups.setdefault(f['surface'],[]).append(f['time_ms'])
        rows={}
        for surface,times in groups.items():
            gaps=[y-x for x,y in zip(times,times[1:])]
            # Retain the full raw gaps: long Deck/workspace gaps may be stalls.
            # Ambient bearings deliberately rest for seconds between strokes.
            active=[g for g in gaps if g>0 and (a['event']!='background' or g<100)]
            spectra=a['event'].startswith('spectra-switch')
            rows[surface]={'callbacks':len(times),'all_intervals_ms':gaps,'analysed_intervals_ms':active,
                'median_ms':statistics.median(active) if active else None,
                'p95_ms':sorted(active)[math.ceil(len(active)*.95)-1] if active else None,
                'missed_refresh_opportunities_estimate':None if spectra else sum(max(0,round(g/(1000/refresh))-1) for g in active),
                'long_ambient_rest_gaps_omitted':len(gaps)-len(active) if a['event']=='background' else 0}
        segments.append({'event':a['event'],'seconds':(end-start)/1000,'surfaces':rows})
    summary['segments']=segments
    summary['method']='wl_surface.frame to wl_callback.done; uint32 compositor monotonic timestamps in ms. Full gaps retained. Only background rests >=100ms omitted from active statistics. Spectra is an atomic palette redraw, with no expected animation or opportunity estimate. Other opportunity estimates include event/render latency and are not GPU presentation/drop telemetry.'
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='segments'}))
