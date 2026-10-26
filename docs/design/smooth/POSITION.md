# Actual position over time

The corrected ChordSlot copies log `UI016_DOCK_START` once when `presented` becomes true; there is no per-frame QML logging. A magenta 10 px marker follows the real retained bay. Three open/close cycles at each actual 60/144 Hz output are captured as 115×115 PNG crops. The raw JSON records the wall-time bounds of each capture, IPC latency, marker centroid and one-shot start event.

[Measured positions and fixed-duration model](position-over-time.svg), [CSV](data/positions.csv), [numeric summary](data/position-summary.json).

| Output | Repeat | Fitted software start offset | First settled capture after docking event | Moving-sample model RMSE |
|---|---:|---:|---:|---:|
| 60 Hz | 0 (cold) | 112 ms | 321.9 ms | 2.69 px |
| 60 Hz | 1 (warm) | 62 ms | 189.8 ms | 3.84 px |
| 60 Hz | 2 (warm) | 41 ms | 201.0 ms | 4.48 px |
| 144 Hz | 0 (cold) | 102 ms | 325.0 ms | 0.95 px |
| 144 Hz | 1 (warm) | 42 ms | 206.2 ms | 2.93 px |
| 144 Hz | 2 (warm) | 37 ms | 203.2 ms | 0.56 px |

The overlay keeps the configured 160 ms OutCubic duration fixed at both refresh rates and fits only a start offset. All measured visible entry positions stay within the intended x 714–749 px band and settle at 714.5 px. Warm openings at 60 and 144 Hz have similar elapsed-time trajectories; software first-paint and render-job startup add latency, especially on the first opening. The fit is descriptive evidence, not a proof of perfect pacing or an exact 160 ms cold opening. All table times are relative to the logged docking event and exclude the preceding open-to-first-render gate delay. Individual frames may predate capture start by an output interval, and millisecond logging, pixel quantisation, capture load and missed renders limit precision.

The first native-Animator attempt entered from scene-graph x≈0 before its intended entry pose had synced. The failed captures are preserved in [attempts/first-sync](attempts/first-sync/README.md). The final implementation waits for the first render with `afterAnimating` and `frameSwapped`, guards queued delivery by bay generation, and then disconnects these handlers. The captured trajectory confirms the corrected entry direction.

Fast-close requests of 35/70 ms executed at 57–122 ms under synchronous software rendering and screenshot load. Corrected markers remain within the entry/exit corridor and disappear as the outgoing slot retires. Those sparse samples do not establish strict 35 ms interruption continuity or 144 fps hardware smoothness. Actual open/close times, crops and marker data are retained in verification/interruption/after-60 and after-144.

Reproduce the final entry samples with `python3 docs/design/smooth/run-position.py after 60`, then `after 144`. Rebuild this plot with `python3 docs/design/smooth/summarise-positions.py`.
