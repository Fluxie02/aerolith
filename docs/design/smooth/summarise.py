"""Build tables from raw summaries after the sequential benchmark matrix."""
import json,math,statistics
from pathlib import Path

root=Path(__file__).resolve().parent
data=root/'data'
rows=[]
for phase in ('before','after'):
    for rate in (60,144):
        for intensity in ('saturated','insane'):
            path=data/f'{phase}-{rate}-{intensity}-cpu'/'summary.json'
            if path.exists():
                s=json.loads(path.read_text()); cpu=s['cpu']
                rows.append({'phase':phase,'refresh_hz':s['refresh_hz'],'intensity':intensity,
                    'idle_cpu_one_core':cpu['idle']['cpu_percent_one_core'],
                    'active_cpu_one_core':cpu['active']['cpu_percent_one_core'],
                    'idle_seconds':cpu['idle']['seconds'],'active_seconds':cpu['active']['seconds']})
timing=[]
for path in sorted(data.glob('*-timing/summary.json')):
    s=json.loads(path.read_text()); parts=path.parent.name.split('-'); phase,rate,intensity=parts[:3]
    for category,surface in (('deck-open','aerolith-deck'),('deck-close','aerolith-deck'),('bay-switch','aerolith-deck'),('workspace-switch','aerolith-ground'),('spectra-switch','aerolith-deck'),('background','aerolith-ground')):
        intervals=[]; all_intervals=[]; misses=0; callbacks=0; seconds=0
        for segment in s['segments']:
            if segment['event'].startswith(category) and surface in segment['surfaces']:
                value=segment['surfaces'][surface]; intervals+=value['analysed_intervals_ms']
                all_intervals+=value['all_intervals_ms']; callbacks+=value['callbacks']
                seconds+=segment['seconds']
                misses+=value['missed_refresh_opportunities_estimate'] or 0
        timing.append({'phase':phase,'refresh_hz':int(rate),'intensity':intensity,'category':category,'surface':surface,
            'callbacks':callbacks,'observed_event_windows_seconds':seconds,'analysed_intervals':len(intervals),
            'median_ms':statistics.median(intervals) if intervals else None,
            'p95_ms':sorted(intervals)[math.ceil(len(intervals)*.95)-1] if intervals else None,
            'max_full_gap_ms':max(all_intervals) if all_intervals else None,
            'missed_refresh_opportunities_estimate':None if category=='spectra-switch' else misses})
(data/'aggregate.json').write_text(json.dumps({'cpu':rows,'timing':timing},indent=2)+'\n')
lines=['# UI-016 measured frame callbacks and CPU','',
    'All runs use fresh headless Sway/pixman and Qt Quick software containers at 1920×1080, scale 1. `outputs.json` proves each actual 60,000 or 144,000 mHz output mode. The copied Hyprland mock reports the matching refresh rate. Before retains its original `DP-1` name; after uses `HEADLESS-1` to match the actual screen for the new output-specific refresh readout. No production hosts or services are modified by this harness.','',
    'CPU cases run sequentially, with no other agent tests or headless sessions during timed samples. Each idle sample is 120 seconds after startup; active samples run the same five open/switch/close/workspace cycles and five Spectra selections. CPU is the shell process user+system ticks divided by wall time, as a percentage of one core. Timing logging and screenshots are disabled in CPU cases.','',
    'Orchestration correction: the final before/144/Insane wrapper exited 2 after its Docker session had completed successfully (`UI-016 cpu done` in result.txt). A wrapper edit during execution changed the remaining shell parse position. Both complete 120.0518 s idle and 13.1549 s active CPU JSON samples were intact; `analyse-timing.py docs/design/smooth/data/before-144-insane-cpu` parsed them successfully. The wrapper and scenarios were syntax checked and frozen before all after runs. This was an orchestration error, not an entirely clean matrix run.','',
    'Before Spectra evidence consists of the recorded keyboard scenario plus actual palette repaint callbacks; its final configuration was not saved. After runs additionally copy `config-final.json` after the timed workload so the applied final scheme can be verified without changing the CPU sample.','',
    '| Source | Hz | Intensity | Idle CPU | Active CPU | Idle / active sample seconds |',
    '|---|---:|---|---:|---:|---:|']
for r in rows:
    lines.append(f"| {r['phase']} | {r['refresh_hz']:g} | {r['intensity']} | {r['idle_cpu_one_core']:.3f}% | {r['active_cpu_one_core']:.3f}% | {r['idle_seconds']:.2f} / {r['active_seconds']:.2f} |")
lines+=['','Frame intervals below come from actual per-surface `wl_surface.frame` → `wl_callback.done` protocol callbacks. These are compositor callback intervals, not GPU presentation timestamps. Full callback lists, every original interval and raw logs are retained. A missed refresh opportunity is `max(0, round(interval / refresh_period) - 1)` summed over intervals; it includes application/render latency and is **not an observed dropped-frame counter**. Deck and workspace gaps are kept even above 100 ms. Background rests of at least 100 ms are excluded only from its active statistics and remain in the raw data. Spectra changes the palette atomically; its redraw gaps have no animation-drop estimate.','',
    '| Source | Hz | Intensity | Operation / surface | Callbacks / window s | Intervals | Median ms | p95 ms | Max full gap ms | Estimated missed opportunities |',
    '|---|---:|---|---|---:|---:|---:|---:|---:|---:|']
for r in timing:
    number=lambda v:'—' if v is None else str(v)
    lines.append(f"| {r['phase']} | {r['refresh_hz']} | {r['intensity']} | {r['category']} / {r['surface'].removeprefix('aerolith-')} | {r['callbacks']} / {r['observed_event_windows_seconds']:.2f} | {r['analysed_intervals']} | {number(r['median_ms'])} | {number(r['p95_ms'])} | {number(r['max_full_gap_ms'])} | {number(r['missed_refresh_opportunities_estimate'])} |")
lines+=['','The software backend is a pacing and correctness harness. It cannot establish 144 fps hardware smoothness. Millisecond Wayland callback timestamps also quantise the 6.944 ms target. WAYLAND_DEBUG logging adds overhead to timing runs; CPU numbers come from separate uninstrumented runs. Hardware Hyprland, render-thread Animators, VRR, presentation feedback and real GPU dropped frames still require systems validation.','',
    'Reproduction: `bash docs/design/smooth/run-benchmark.sh before 60 saturated cpu`, changing the four arguments for each case. First preserve `shell/` as `build/ui016/before-shell`, then the completed tree as `build/ui016/after-shell`. `prepare-session.py` creates disposable session/mock copies; SHA-256 source manifests identify each measured snapshot. `python3 docs/design/smooth/summarise.py` rebuilds this table.','',
    'Position evidence: `python3 docs/design/smooth/run-position.py before 60` (and after/144 variants) attaches a magenta 10 px marker only to a copied production ChordSlot. The saved PNG crops follow the actual rendered transform. `positions.json` records both capture bounds and IPC latency; the animation starts before IPC returns, so that offset must be considered when comparing an analytic curve. These sparse samples show time-based travel and settling, not a 144 fps recording.']
(root/'TIMING.md').write_text('\n'.join(lines)+'\n')
print('updated TIMING.md and data/aggregate.json')
