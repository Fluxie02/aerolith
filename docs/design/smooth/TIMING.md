# UI-016 measured frame callbacks and CPU

All runs use fresh headless Sway/pixman and Qt Quick software containers at 1920×1080, scale 1. `outputs.json` proves each actual 60,000 or 144,000 mHz output mode. The copied Hyprland mock reports the matching refresh rate. Before retains its original `DP-1` name; after uses `HEADLESS-1` to match the actual screen for the new output-specific refresh readout. No production hosts or services are modified by this harness.

CPU cases run sequentially, with no other agent tests or headless sessions during timed samples. Each idle sample is 120 seconds after startup; active samples run the same five open/switch/close/workspace cycles and five Spectra selections. CPU is the shell process user+system ticks divided by wall time, as a percentage of one core. Timing logging and screenshots are disabled in CPU cases.

Orchestration correction: the final before/144/Insane wrapper exited 2 after its Docker session had completed successfully (`UI-016 cpu done` in result.txt). A wrapper edit during execution changed the remaining shell parse position. Both complete 120.0518 s idle and 13.1549 s active CPU JSON samples were intact; `analyse-timing.py docs/design/smooth/data/before-144-insane-cpu` parsed them successfully. The wrapper and scenarios were syntax checked and frozen before all after runs. This was an orchestration error, not an entirely clean matrix run.

Before Spectra evidence consists of the recorded keyboard scenario plus actual palette repaint callbacks; its final configuration was not saved. After runs additionally copy `config-final.json` after the timed workload so the applied final scheme can be verified without changing the CPU sample.

| Source | Hz | Intensity | Idle CPU | Active CPU | Active CPU seconds | Idle / active sample seconds |
|---|---:|---|---:|---:|---:|---:|
| before | 60 | saturated | 1.400% | 54.031% | 7.10 | 120.03 / 13.14 |
| before | 60 | insane | 3.799% | 66.581% | 8.81 | 120.03 / 13.23 |
| before | 144 | saturated | 1.933% | 59.242% | 7.81 | 120.03 / 13.18 |
| before | 144 | insane | 5.139% | 73.281% | 9.64 | 120.05 / 13.15 |
| after | 60 | saturated | 1.250% | 59.882% | 7.55 | 120.03 / 12.61 |
| after | 60 | insane | 3.466% | 73.737% | 9.40 | 120.03 / 12.75 |
| after | 144 | saturated | 0.716% | 70.166% | 9.02 | 120.03 / 12.86 |
| after | 144 | insane | 2.049% | 83.495% | 10.78 | 120.03 / 12.91 |

Frame intervals below come from actual per-surface `wl_surface.frame` → `wl_callback.done` protocol callbacks. These are compositor callback intervals, not GPU presentation timestamps. Full callback lists, every original interval and raw logs are retained. A missed refresh opportunity is `max(0, round(interval / refresh_period) - 1)` summed over intervals; it includes application/render latency and is **not an observed dropped-frame counter**. Deck and workspace gaps are kept even above 100 ms. Background rests of at least 100 ms are excluded only from its active statistics and remain in the raw data. Spectra changes the palette atomically; its redraw gaps have no animation-drop estimate.

| Source | Hz | Intensity | Operation / surface | Callbacks / window s | Intervals | Median ms | p95 ms | Max full gap ms | Estimated missed opportunities |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| after | 144 | saturated | deck-open / deck | 144 / 2.23 | 139 | 6 | 23 | 75 | 89 |
| after | 144 | saturated | deck-close / deck | 63 / 2.18 | 58 | 7.0 | 34 | 42 | 70 |
| after | 144 | saturated | bay-switch / deck | 178 / 2.24 | 173 | 6 | 49 | 72 | 157 |
| after | 144 | saturated | workspace-switch / ground | 439 / 4.10 | 434 | 6.0 | 9 | 28 | 24 |
| after | 144 | saturated | spectra-switch / deck | 30 / 2.06 | 25 | 8 | 104 | 121 | — |
| after | 144 | saturated | background / ground | 169 / 30.03 | 163 | 6 | 7 | 4995 | 0 |
| after | 60 | saturated | deck-open / deck | 79 / 2.28 | 74 | 18.0 | 41 | 74 | 9 |
| after | 60 | saturated | deck-close / deck | 37 / 2.18 | 32 | 20.5 | 42 | 44 | 14 |
| after | 60 | saturated | bay-switch / deck | 92 / 2.24 | 87 | 17 | 49 | 59 | 46 |
| after | 60 | saturated | workspace-switch / ground | 186 / 4.08 | 181 | 18 | 19 | 33 | 4 |
| after | 60 | saturated | spectra-switch / deck | 25 / 2.07 | 20 | 58.5 | 97 | 113 | — |
| after | 60 | saturated | background / ground | 206 / 30.04 | 198 | 16.0 | 17 | 5135 | 0 |
| before | 144 | saturated | deck-open / deck | 197 / 2.19 | 192 | 6.0 | 25 | 67 | 57 |
| before | 144 | saturated | deck-close / deck | 61 / 2.15 | 56 | 8.0 | 32 | 37 | 74 |
| before | 144 | saturated | bay-switch / deck | 227 / 2.24 | 222 | 6.0 | 46 | 79 | 121 |
| before | 144 | saturated | workspace-switch / ground | 591 / 4.03 | 586 | 6.0 | 8 | 32 | 20 |
| before | 144 | saturated | spectra-switch / deck | 28 / 2.08 | 23 | 7 | 126 | 159 | — |
| before | 144 | saturated | background / ground | 506 / 30.03 | 498 | 6.0 | 7 | 4994 | 2 |
| before | 60 | saturated | deck-open / deck | 85 / 2.20 | 80 | 16.0 | 43 | 63 | 14 |
| before | 60 | saturated | deck-close / deck | 38 / 2.13 | 33 | 21 | 38 | 46 | 17 |
| before | 60 | saturated | bay-switch / deck | 97 / 2.19 | 92 | 16.0 | 53 | 68 | 33 |
| before | 60 | saturated | workspace-switch / ground | 231 / 4.04 | 226 | 18.0 | 19 | 28 | 4 |
| before | 60 | saturated | spectra-switch / deck | 24 / 2.06 | 19 | 69 | 100 | 100 | — |
| before | 60 | saturated | background / ground | 208 / 30.03 | 200 | 16.0 | 17 | 4967 | 0 |

The software backend is a pacing and correctness harness. It cannot establish 144 fps hardware smoothness. At the final 144 Hz setting, Deck callback p95 is 23 ms for opening, 34 ms for closing and 49 ms for bay switches, against a nominal 6.944 ms output period. Uniform 144 fps is not demonstrated: the software callback stream has substantial stalls, and actual hardware presentation remains unverified. Light ambient motion delivers approximately 6–7 ms callback intervals, but headless timer quantisation and millisecond timestamps do not reproduce a physical 6.944 ms presentation clock. WAYLAND_DEBUG logging adds overhead to timing runs; CPU numbers come from separate uninstrumented runs. Hardware Hyprland, render-thread Animators, VRR, presentation feedback and real GPU dropped frames still require systems validation.

Reproduction: `bash docs/design/smooth/run-benchmark.sh before 60 saturated cpu`, changing the four arguments for each case. First preserve `shell/` as `build/ui016/before-shell`, then the completed tree as `build/ui016/after-shell`. `prepare-session.py` creates disposable session/mock copies; SHA-256 source manifests identify each measured snapshot. `python3 docs/design/smooth/summarise.py` rebuilds this table.

Position evidence: `python3 docs/design/smooth/run-position.py before 60` (and after/144 variants) attaches a magenta 10 px marker only to a copied production ChordSlot. The saved PNG crops follow the actual rendered transform. Baseline capture bounds are relative to IPC return, and its animation may begin before that return. Final AFTER probes instead log `UI016_DOCK_START` once after the first-render gate and retain absolute capture bounds. [POSITION.md](POSITION.md) and its plot compare those logged times with a fixed-duration model, including renderer-start uncertainty. These sparse samples show time-based travel and settling, not a 144 fps recording.
