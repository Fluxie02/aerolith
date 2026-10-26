"""Plot actual diagnostic marker positions, including capture uncertainty.

SVG is generated from measured numbers; no screenshots are interpolated or edited.
The 160 ms model is fixed. A fitted start offset describes software job latency,
not a change to the production animation duration.
"""
import csv,json,math
from pathlib import Path

root=Path(__file__).resolve().parent
def trajectory(t,offset=0):
    progress=max(0,min(1,(t-offset)/160))
    return 714.5+34.5*(1-progress)**3

groups=[];flat=[]
for rate in (60,144):
    rows=json.loads((root/f'data/after-{rate}-position/positions.json').read_text())
    for repeat in range(3):
        samples=[r for r in rows if r['repeat']==repeat and r['marker_pixels']]
        for r in samples:
            r['mid_ms']=(r['capture_start_after_dock_ms']+r['capture_end_after_dock_ms'])/2
            flat.append({'refresh_hz':rate,'repeat':repeat,'capture_begin_ms':r['capture_start_after_dock_ms'],
                'capture_end_ms':r['capture_end_after_dock_ms'],'marker_x':r['marker_screen_x'],'marker_y':r['marker_screen_y']})
        lag=min(range(201),key=lambda lag:sum((trajectory(r['mid_ms'],lag)-r['marker_screen_x'])**2 for r in samples))
        moving=[r for r in samples if 715<r['marker_screen_x']<748]
        error=math.sqrt(sum((trajectory(r['mid_ms'],lag)-r['marker_screen_x'])**2 for r in moving)/len(moving)) if moving else None
        settled=[r for r in samples if abs(r['marker_screen_x']-714.5)<=.1]
        groups.append({'refresh_hz':rate,'repeat':repeat,'samples':samples,'fitted_pipeline_offset_ms':lag,
            'moving_sample_rmse_px':round(error,2) if error is not None else None,
            'first_settled_capture_mid_ms':round(settled[0]['mid_ms'],1) if settled else None})
(root/'data/position-summary.json').write_text(json.dumps([{k:v for k,v in g.items() if k!='samples'} for g in groups],indent=2)+'\n')
with (root/'data/positions.csv').open('w') as f:
    writer=csv.DictWriter(f,fieldnames=flat[0].keys());writer.writeheader();writer.writerows(flat)

# Two plots with horizontal capture-bound bars. Every plotted dot is observed.
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="570" viewBox="0 0 1080 570">',
 '<rect width="1080" height="570" fill="#10191d"/>',
 '<style>text{font-family:Arial,sans-serif;fill:#eef4f1;font-size:13px}.small{font-size:11px}</style>',
 '<text x="42" y="30" font-size="20">Actual ChordSlot position after the first-render correction</text>',
 '<text x="42" y="53">Dots: captured magenta marker; bars: capture bounds. Lines: fixed 160 ms OutCubic with fitted renderer-start offset.</text>']
colors=['#ffbd6b','#80dcff','#bee69b']
for panel,rate in enumerate((60,144)):
    x0=65+panel*530;y0=100;w=455;h=330
    sx=lambda t:x0+(t+50)/550*w
    sy=lambda x:y0+(752-x)/42*h
    svg.append(f'<text x="{x0}" y="82" font-size="18">{rate} Hz output</text>')
    for t in range(0,501,100):
        x=sx(t);svg.append(f'<path d="M{x},{y0}V{y0+h}" stroke="#2e4249"/><text x="{x-9}" y="{y0+h+21}">{t}</text>')
    for value in (715,725,735,745):
        y=sy(value);svg.append(f'<path d="M{x0},{y}H{x0+w}" stroke="#2e4249"/><text x="{x0-35}" y="{y+4}">{value}</text>')
    svg.append(f'<path d="M{sx(0)},{y0}V{y0+h}" stroke="#b8c5c9" stroke-dasharray="3 4"/>')
    for g in [g for g in groups if g['refresh_hz']==rate]:
        color=colors[g['repeat']];lag=g['fitted_pipeline_offset_ms']
        points=' '.join(f'{sx(t):.2f},{sy(trajectory(t,lag)):.2f}' for t in range(-40,501,4))
        svg.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="1.2" opacity=".75"/>')
        for r in g['samples']:
            y=sy(r['marker_screen_x']);a=sx(r['capture_start_after_dock_ms']);b=sx(r['capture_end_after_dock_ms']);x=sx(r['mid_ms'])
            svg.append(f'<path d="M{a:.2f},{y:.2f}H{b:.2f}" stroke="{color}" stroke-width="2"/><circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="{color}"/>')
        label=f"{'Cold' if g['repeat']==0 else 'Warm'+str(g['repeat'])}: fitted offset {lag} ms, moving RMSE {g['moving_sample_rmse_px']} px"
        svg.append(f'<text x="{x0}" y="{y0+h+53+g["repeat"]*20}" style="fill:{color}" class="small">{label}</text>')
svg+=['<text x="65" y="550">x-axis: ms after one-shot presented=true log. y-axis:marker screen x (px). Offset is renderer latency, not FPS-scaled duration.</text>','</svg>']
(root/'position-over-time.svg').write_text('\n'.join(svg)+'\n')
lines=['# Actual position over time','',
 'The corrected ChordSlot copies log `UI016_DOCK_START` once when `presented` becomes true; there is no per-frame QML logging. A magenta 10 px marker follows the real retained bay. Three open/close cycles at each actual 60/144 Hz output are captured as 115×115 PNG crops. The raw JSON records the wall-time bounds of each capture, IPC latency, marker centroid and one-shot start event.','',
 '[Measured positions and fixed-duration model](position-over-time.svg), [CSV](data/positions.csv), [numeric summary](data/position-summary.json).','',
 '| Output | Repeat | Fitted software start offset | First settled capture after docking event | Moving-sample model RMSE |',
 '|---|---:|---:|---:|---:|']
for g in groups:
    lines.append(f"| {g['refresh_hz']} Hz | {g['repeat']} ({'cold' if g['repeat']==0 else 'warm'}) | {g['fitted_pipeline_offset_ms']} ms | {g['first_settled_capture_mid_ms']} ms | {g['moving_sample_rmse_px']} px |")
lines+=['',
 'The overlay keeps the configured 160 ms OutCubic duration fixed at both refresh rates and fits only a start offset. All measured visible entry positions stay within the intended x 714–749 px band and settle at 714.5 px. Warm openings at 60 and 144 Hz have similar elapsed-time trajectories; software first-paint and render-job startup add latency, especially on the first opening. The fit is descriptive evidence, not a proof of perfect pacing or an exact 160 ms cold opening. All table times are relative to the logged docking event and exclude the preceding open-to-first-render gate delay. Individual frames may predate capture start by an output interval, and millisecond logging, pixel quantisation, capture load and missed renders limit precision.','',
 'The first native-Animator attempt entered from scene-graph x≈0 before its intended entry pose had synced. The failed captures are preserved in [attempts/first-sync](attempts/first-sync/README.md). The final implementation waits for the first render with `afterAnimating` and `frameSwapped`, guards queued delivery by bay generation, and then disconnects these handlers. The captured trajectory confirms the corrected entry direction.','',
 'Fast-close requests of 35/70 ms executed at 57–122 ms under synchronous software rendering and screenshot load. Corrected markers remain within the entry/exit corridor and disappear as the outgoing slot retires. Those sparse samples do not establish strict 35 ms interruption continuity or 144 fps hardware smoothness. Actual open/close times, crops and marker data are retained in verification/interruption/after-60 and after-144.','',
 'Reproduce the final entry samples with `python3 docs/design/smooth/run-position.py after 60`, then `after 144`. Rebuild this plot with `python3 docs/design/smooth/summarise-positions.py`.']
(root/'POSITION.md').write_text('\n'.join(lines)+'\n')
print(json.dumps([{k:v for k,v in g.items() if k!='samples'} for g in groups],indent=2))
