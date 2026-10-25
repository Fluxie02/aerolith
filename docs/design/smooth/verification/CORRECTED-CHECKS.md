# Corrected cold-slot runtime checks

The retained snapshot in `build/ui016/verification/corrected-shell` matches `corrected-source-hashes.json`. Its sole production difference from the final-unit source is `components/ChordSlot.qml`; shared test and library files are unchanged. No unit engine was rerun after this QML-only correction.

All three commands exited 0; exact environment, command, start time, exit and elapsed time are retained under `results/corrected-*.json` with complete stdout in the sibling text files.

| Check | Result |
| --- | --- |
| Production smoke | Strip and settled Command rendered; close completed |
| Cold rapid slot lifecycle | Cold A/B opens, requested close delays of 0/35/70/100 ms, Command→Settings→Navigator replacement and eight rapid four-bay reuse cycles passed; no retained Deck, telemetry or audio demand |
| Live motion modes | Full/reduced/off mode changes with Command/Settings entry/exit; five rapid full/off/reduced sequences and lowEffects passed |

The requested delay values in the functional rapid scenario are shell sleeps between IPC calls; they are not claims of measured exact frame/event intervals. The separate QML-timed marker probe retains actual timestamps and render pixels.

`runs/corrected-motion-modes/stationary-pixels.json` records a native-pixel comparison of the ground region `[100,220,1400,1000]` in two samples 0.3 s apart. Off and lowEffects have no changed pixels. The ROI excludes the live clock, strip and notice column so independent status text does not masquerade as ambient motion. Screenshots and saved states remain in the matching run directory.

The aggregate audit after these checks covered seven retained QML logs with zero error-pattern findings. Functional containers overlapped each other and were stopped before corrected timing/pixel probes or after CPU benchmarks; their wall time is not a CPU/frame-rate measurement.
