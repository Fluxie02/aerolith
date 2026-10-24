# UI-016 — motion at the output cadence

PIYTI is the base. THEARS remains available in both intensities; its selection
belongs to Claude's one-time installation integration, not Settings.

The visual layer uses millisecond durations and Qt's animation driver. Deck
docking, workspace registration, application seams, gauge fills, tab markers
and focus feedback use retained transform/opacity Animators. A quick retirement
retargets the visible pose instead of resetting an opening scalar. Bezel
engagement no longer repaints its large Canvas each frame. The OSD retains
observable property animation for its exit contract, with JavaScript only on
completion. Shared process-latched startup remains a finite, time-based scalar;
its cached canvases do not repaint for that scalar.

Settings reports the current output's existing, notified Hyprland monitor
refresh metadata through `Theme.refreshRate`: for example, **Motion: synced to
144 Hz**. Missing or mismatched data says unavailable. This is detected output
rate, not a measurement of achieved fps. Off, reduced and lowEffects remain
available and cancel ongoing authored visual transitions. The sole ambient
gate remains `Theme.ambient`.

Ambient strokes retain their duration and use full output cadence. At higher
refresh rates the interval between strokes grows in proportion to Hz/60,
amortizing their drawing cost without a frame-rate cap. Saturated's full-motion
cycle is 9.28 s at 60 Hz and 22.272 s at 144 Hz; Insane's is 5.12 s and
12.288 s. Both retain 960 ms of motion per cycle. Unknown refresh metadata uses
the existing cadence. No config/schema setting, shader or service poll is added.

## Verification status

Measurement and final scenario runs are in progress. This README is a saved
checkpoint and will be completed with before/after tables and exact results.
No claim of 144 fps is made from advertised monitor metadata.

The reproducible headless measurement scripts are in this directory. They copy
the existing session/mock into `build/ui016`, request a real Sway headless
1920×1080 mode at 60 or 144 Hz, and retain `outputs.json` as evidence. CPU runs
use uninstrumented snapshots and exclude logging/screenshots; timing runs
record Wayland frame callbacks separately. Diagnostic marker/capture builds
are separate from both. The immutable before snapshot is in
`build/ui016/before-shell`; a source hash manifest accompanies its evidence.

The full inventory is in [AUDIT.md](AUDIT.md). Protected integration findings,
including duplicate compositor layer motion and the Deck's retained exit
deadline after live motion disable, are in
[SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md). Host files, services, config/schema
and git history are not modified.

Qt's [Animator documentation](https://doc.qt.io/qt-6/qml-qtquick-animator.html)
explains scene-graph animation and current-value Behavior endpoints. The
[Behavior contract](https://doc.qt.io/qt-6/qml-qtquick-behavior.html) explains
property retargeting. These describe the implementation mechanism; measured
software-renderer evidence determines the performance claims below.
