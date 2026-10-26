# UI-016 systems requests

The visual implementation reads the selected output's existing
`HyprlandMonitor.lastIpcObject.refreshRate` through `Theme.refreshRate`. This
property is notified by Quickshell, so no polling or new process is needed.
The match must be exact against `Ui.screenName`: another output's rate must
never be presented as the current rate. Missing, nonnumeric or nonpositive
metadata remains unavailable. Settings displays the detected rate even when
motion is off, reduced or disabled by low effects. The detected number is
output metadata; it is not a measurement of achieved rendering throughput.

No schema addition or 60 fps ambient cap is requested. Finite ambient strokes
keep their wall-time duration and use the output's native cadence. Longer
rests between strokes amortize their work on high-refresh outputs. The one
`Theme.ambient` gate still owns suspension.

## SR-016-1 — high: suppress duplicate compositor layer animation

**Affected systems files:** `installer/aerolith_install/hypr.py`, its installer
tests, and the installed Hyprland fragment. The production surface hosts are
unchanged by UI-016.

**Evidence:** `fragment()` currently generates autostart and binds only.
`GroundSurface.qml`, `Deck.qml`, `NoticeColumn.qml` and `FlightStrip.qml` expose
the stable layer namespaces `aerolith-ground`, `aerolith-deck`,
`aerolith-notices`, and `aerolith-strip`; none supplies a compositor animation
policy. Hyprland's layer entrance/exit can therefore stack with the shell's
own transition and continue when `theme.motion` is off. Sway screenshots do
not exercise Hyprland layer animation.

**Minimal correction:** Claude should add installer-managed rules disabling
Hyprland animation for those four exact namespaces in both supported config
dialects. Preserve unrelated rules and the existing fragment's idempotent
apply/update/uninstall behavior. Apply the same policy when lock, OSD or
session hosts are integrated. No blur rule or shader is requested.

**Acceptance:** on real Hyprland, full motion produces one bounded shell
transition per Deck event; off and lowEffects map/unmap without compositor
travel or fading; notices and the strip never receive a second compositor
transition. Check first installation, update, repeated apply and uninstall.

## SR-016-2 — medium: release an outgoing Deck when motion becomes disabled

**Affected systems file:** `shell/modules/deck/Deck.qml`.

**Evidence:** `BaySlot.retire()` snapshots `deck.exitMs` into
`exitTimer.interval` at retirement. Later changing motion to off or enabling
lowEffects makes `deck.exitMs` zero, but leaves a previously outgoing bay and
the mapped surface alive until the old deadline. See the single systems
review in [verification/SYSTEMS-REVIEW.md](verification/SYSTEMS-REVIEW.md).
The existing deck scenario disables motion before opening/closing and does
not cover disabling it during an exit.

**Minimal correction:** when `exitMs` becomes zero, release each `leaving`
slot immediately and recompute the held surface. Preserve a current bay,
its focus, the immediate demand release on retirement, and the no-remap
contract. Keep the Timer as a lifecycle deadline; it does not step motion.

**Acceptance:** close during a full transition, immediately set motion off
or lowEffects, and assert the outgoing slot and closed surface release in
that event turn. Repeat while switching bays; the requested bay remains
mapped, focused and responsive. Restore full motion and verify a subsequent
open/close has one map cycle.

## Integration verification

On a real output, change its mode between 60, 120 and 144 Hz without restarting
the shell and verify Quickshell updates the matched monitor snapshot and the
Settings readout. Unplug/reselect the output and verify unavailable metadata
never reuses another output's rate. If a compositor mode-change event does
not refresh Quickshell's snapshot, refresh monitor metadata from that existing
event in `Compositor.qml`; do not add a timer in a visual component.

Physical Hyprland/GPU pacing, VRR and compositor animation cannot be approved
from the pixman/Sway harness. Its measured timings and renderer limits belong
in the adjacent README and data rather than being inferred from mock metadata.


## Measured follow-up — real-output presentation and cold-start latency

The final software-rendered marker probes preserve a 160 ms curve at both
rates but expose render-job startup latency: warm settled samples are about
190–206 ms and cold samples about 322–325 ms after the diagnostic docking
start event, excluding the preceding render-gate wait. See POSITION.md and
TIMING.md. CPU-active cost is also reported alongside idle cost.

Claude should repeat open/close, bay replacement, workspace and palette
operations on a GPU-backed 144 Hz Hyprland output using presentation feedback
or QSG timing, including the first use of both retained slots. Check the
one-shot first-render gate with rapid release/reuse and verify there is no
cold wrong-way entry or added compositor transition. Report presentation
intervals, cold input-to-first-frame latency and actual dropped frames where
available. Do not infer achieved fps from Theme.refreshRate or replace the
wall-time strokes with a 60 Hz timer to hide renderer cost. The current
headless callback estimates are not a hardware presentation certificate.
