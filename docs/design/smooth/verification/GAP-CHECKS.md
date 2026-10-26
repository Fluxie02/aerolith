# UI-016 provisional gap checks

All source files in this test snapshot matched production at completion (`provisional-current-comparison.json`). Final source freeze follows rendered interruption review; final scenario results are recorded separately.

`node tests/js/run-node.mjs`: 118 passed. Qt V4 shared suite: 118 passed. `python3 -m pytest -q tests/py`: 71 passed, 1 skipped. All three exit 0; exact command records and stdout are in `unit-final/` (Node/Python) and `unit-provisional/` (Qt).

The provisional smoke scenario passed. The synchronous live-disable fixture confirmed the existing protected host deadline finding documented in `SYSTEMS-REVIEW.md` for both off and lowEffects. The final visual ChordSlot implementation separately hides its outgoing face immediately when animations are disabled; the remaining mapped host lifetime needs Claude.

The extra-view fixture loads actual production `OsdView`, legacy `CircularField`, `LockView` and `SessionView` in an ordinary overlay in a disposable copy. It performs no authentication/session action. OSD full/off/reduced/lowEffects exits each emitted exactly one `settled()`. An immediate close/reopen emitted no obsolete signal. Legacy progress retargeting loaded without QML errors. The three final PNGs were inspected: OSD/CircularField geometry, lock prompt and session rows render legibly with complete Bezel edges.

The first extra-view wrapper ended with exit 109 because the diagnostic IPC method name `show` collided with an inherited method. Its logs and partial OSD statuses are preserved under `runs/provisional-extra-views/`; no production QML failed. Renaming the fixture method `setKind` produced the passing `provisional-extra-views-retry` (exit 0), including static Lock and Session captures.

All four retained QML logs were audited: zero parse/type/reference/assignment/binding-loop/error-pattern findings. Known absent PipeWire (fixtures without AUDIO), system D-Bus/RTKit, unsupported Hyprland shortcut/toplevel protocols under Sway remain in the logs. These are functional checks with overlapping containers; no CPU or frame-pacing claim is derived from this gap.
