# UI-016 — motion at the output cadence

Motion is time-based and follows Qt's output pacing, with retained Animators
for Deck docking, workspace registration, application seams, gauges, tab
markers and focus feedback. **Uniform 144 fps is not established:** the
software renderer produces fast callback bursts but still stalls during
Deck/bay operations. The recorded limitations are part of this result.

PIYTI is the base for changes and review captures. THEARS remains available in
both intensities, with no new development or Settings selector; Claude wires
the installation-only choice.

## What changed

- Docking and interruption use current-value transform/opacity Behaviors.
  The entry pose is committed before a cold Animator starts, with one-shot
  render callbacks and generation guards. Keyboard/focus/actions remain
  independent of animation completion.
- Bezel activation no longer repaints its large Canvas every frame. Gauges
  and application seams translate inside fixed clips. Workspace and focus
  motion transform retained geometry. OSD JavaScript runs on completion.
- Settings shows **Motion: synced to 144 Hz** from the selected output's
  existing, notified monitor data. Unknown or mismatched metadata stays
  unavailable. The readout reports detected Hz, not achieved fps.
- Off, reduced and lowEffects remain intact, including live cancellation.
  `Theme.ambient` remains the sole ambient gate. No shader, service poll,
  schema change or frame-rate cap was added.

Ambient strokes keep their 960 ms full-motion duration and native cadence.
Their rest grows with Hz/60: Saturated's cycle is 9.28 s at 60 Hz and 22.272 s
at 144 Hz; Insane's is 5.12 s and 12.288 s. This amortizes ambient drawing cost
while each stroke runs at the output cadence. Unknown refresh metadata keeps
the previous cadence. Shared startup retains a finite, time-based scalar;
its cached canvases do not repaint for each startup frame.

## CPU before and after

Percent of one core, PIYTI, 1920×1080/scale 1, Qt software/Sway pixman. Each
idle sample is 120 seconds; active samples execute the same five Deck/bay/
workspace cycles and five Spectra picks in about 13 seconds. Runs were
sequential, without test containers, screenshots or timing logging.

| Hz | Intensity | Idle before → after | Active before → after |
| ---: | --- | ---: | ---: |
| 60 | Saturated | 1.400% → 1.250% | 54.031% → 59.882% |
| 60 | Insane | 3.799% → 3.466% | 66.581% → 73.737% |
| 144 | Saturated | 1.933% → 0.716% | 59.242% → 70.166% |
| 144 | Insane | 5.139% → 2.049% | 73.281% → 83.495% |

All after idle results meet UI-013's approximate 2% Saturated / 4% Insane
budgets. **Active software CPU cost increased.** CPU seconds also increased;
the active percentage change is not merely a shorter workload denominator.
[Full CPU data and sample lengths](TIMING.md) retain both measures.

## Frame timing and time correctness

Actual Sway output JSON confirms modes of 60,000 and 144,000 mHz. The matching
Hyprland fixture supplies metadata; it does not establish throughput.
At 144 Hz, compositor callback intervals (median/p95 milliseconds) were:

| Operation | Before | After |
| --- | ---: | ---: |
| Deck open | 6 / 25 | 6 / 23 |
| Deck close | 8 / 32 | 7 / 34 |
| Bay switch | 6 / 46 | 6 / 49 |
| Workspace switch | 6 / 8 | 6 / 9 |
| Background active stroke | 6 / 7 | 6 / 7 |
| Spectra atomic redraw | 7 / 126 | 8 / 104 |

[All 60/144 Hz intervals, counts and estimates](TIMING.md),
[aggregate JSON](data/aggregate.json) and
[raw benchmark logs](raw-benchmark-logs.tar.gz) are retained. Spectra applies palette changes atomically, avoiding a whole-scene
Canvas repaint on every colour-tween frame. Its redraw gaps are not a
continuous-animation fps measure. Long ambient rests remain in raw data and
are excluded only from active-stroke statistics.

Estimated missed refresh opportunities include application/render latency;
**they are not observed dropped-frame counters**. Millisecond timestamps,
headless timer quantisation and WAYLAND_DEBUG overhead limit these timing
runs. The stalls exceed the physical 6.944 ms budget, so GPU-backed Hyprland,
VRR and actual presentation/drop telemetry still need validation.

[Actual position over time](POSITION.md) and the
[measured plot](position-over-time.svg) compare rendered marker samples with
a fixed 160 ms OutCubic curve at both rates. Only software start latency is
fitted; moving-sample error is 0.56–4.48 px. Warm settled samples are about
190–206 ms and cold samples about 322–325 ms after the diagnostic docking
start, excluding the preceding render-gate wait. Capture bounds and CSV are
saved. This supports similar time-based travel while exposing startup delay.
Requested 35/70 ms closes executed at 57–122 ms under capture load; strict
35 ms continuity remains unmeasured.

## Review, verification and artifacts

[Watch the actual motion recording](video/motion.mp4): 12.433 seconds,
1920×1080, H.264, nominal 30 fps, recorded on the configured 144 Hz output.
It shows Deck/bay, Spectra, workspace and ambient motion. This illustrates
behaviour; it is excluded from CPU/timing measurements and cannot demonstrate
144 fps. [Recording metadata and replay](video/README.md) retain the original
stream, timestamps and capture limitations.

The [self-review](SELF-REVIEW.md) found the biggest weakness in the first
Animator conversion: cold slots entered from an uninitialised scene-graph
position near x0. Corrected markers stay in the intended x714–749 band and
settle at x714.5. [Rejected frames and source identity](attempts/first-sync/README.md)
remain archived. [Source review](SOURCE-REVIEW.md) and the complete
[69-file motion audit](AUDIT.md) explain each retained or changed path.

Node and Qt V4 each passed 118/118; pytest passed 71 with one skipped. Shared
unit inputs are unchanged by the later ChordSlot-only correction. Corrected
smoke, cold/rapid slot replacement, off/reduced/lowEffects and static-pixel
checks passed; OSD, legacy CircularField, Lock and Session fixtures loaded
cleanly. The final campaign passed **13/13, without retries**: PIYTI
smoke/full/deck/ai in both intensities, THEARS smoke/deck in both intensities,
and notify. Twenty retained verification QML logs contain no engine errors.
[Exact final command index](verification/final-command-index.json) records
commands, environments, source identity and exit codes.

[Settings captures](verification/settings/RUN.md) cover full, reduced, off,
lowEffects, missing current-output data, and compact layouts. Exact unit and
scenario commands, source fingerprints, retries and QML-log audits are in
[verification/README.md](verification/README.md).

## Reproduction and systems handoff

[Before source](before-source.tar.gz), [after source](after-source.tar.gz),
[before hashes](before-source-hashes.json), [after hashes](after-source-hashes.json)
and [environment/image identity](environment.json) make the measured builds
reviewable without a git operation. Extract the snapshots into
`build/ui016/before-shell` and `build/ui016/after-shell`, then use
`run-benchmark.sh`, `run-position.py` and the verification driver. Scripts
create disposable session/mock copies; production hosts and services remain
untouched.

Fifteen visual files changed from the saved baseline. All fourteen protected
hosts/services/config/schema files are byte-identical. No git mutation or
commit was performed by this agent. [SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md)
records duplicate compositor layer motion, the confirmed retained Deck exit
deadline after live motion disable, and real-output presentation validation.
Claude has the next systems review; one revision is available.
