# UI-016 independent source review

Reviewed the provisional production diff on 2026-10-24 after the motion audit,
with particular attention to clipping, corner placement, interrupted motion,
live off/reduced/lowEffects and the retained startup scalar. This review did
not modify production code and does not establish rendered frame cadence.

## Medium finding R1 — corrected: ambient round-trip endpoints changed in flight

**Affected files:** `shell/components/Counterphase.qml` and
`shell/components/ShearField.qml`.

**Evidence:** before UI-016, the return half of each Counterphase round trip
bound `from` directly to `machine.direction`, `machine.stroke` and bearing
geometry, and both halves bound duration directly to Theme. A workspace or
settings event between the two halves could therefore change the return
half's start without changing the position already reached by the outward
half. `restartCadence()` also restarted the Timer with `triggeredOnStart`,
which restarted each stroke from its endpoint. Breathing similarly bound its
return peak and duration to mutable reduced-motion tokens.

**Minimal correction applied:** store home/tip/duration (or peak/duration)
once before starting a finite stroke, skip starts while it is running, and
let ordinary state changes affect the next stroke. Explicit reduced-motion
cancellation still settles immediately so a full-amplitude stroke cannot
continue after reduced motion was selected.

**Source verification:** final Counterphase captures `home`, `tip` and
`strokeMs` before `cycle.start()` and uses those same values for both halves.
The return vernier uses the same pattern. ShearField captures `peak` and
`strokeMs` before breathing starts. Workspace changes no longer restart the
cadence. This fixes the source-level discontinuity; pixel continuity and
timing evidence is separate from this source review and was pending when
this review was written.

## High finding R2 — corrected in source: cold docking starts before scene-graph synchronization

Runtime follow-up and source correction reviewed on 2026-10-25.

**Affected file:** `shell/components/ChordSlot.qml`.

**Rendered evidence:** the first native Animator candidate's normal-open
captures missed the marker in its expected region. A full-frame follow-up
showed the cold bay starting around x=0 before settling around x=710, instead
of entering from its intended x=744 pose. An initialized slot later followed
the expected path. This was a real initialization defect that source-only
Behavior review did not detect. The rejected captures, event times, marker
centroids and explanation are retained in
[attempts/first-sync](attempts/first-sync/README.md). Their software-renderer
load delayed nominal fast-close timers; actual logged event times remain
authoritative.

**Minimal correction applied:** keep the initial entry pose registered until
the host window has animated and swapped its first frame, then queue docking
on the GUI event loop. `afterAnimating` arms that one-shot synchronization;
`frameSwapped` queues the dock. Both Connections handlers are enabled only
while the visible chord is not presented. `presentationGeneration` changes
on slot release/reuse, and the deferred callback verifies its captured
generation before presenting. `dockQueued` prevents duplicate requests.
Focus, keyboard handling, bay creation and service demand never wait for
this visual gate.

**Source verification:** the final gate replaces the earlier
`Component.onCompleted`/`onBayChanged` immediate `Qt.callLater(dock)` path.
Once `presented` becomes true, those render-event handlers disconnect, so
there is no ongoing per-frame JavaScript or independent motion clock. Off
and lowEffects retain immediate settled geometry/opacity. Corrected rendered
entry/interrupt probes and final scenarios remain required separately;
the rejected samples must not be described as final AFTER results.

## Geometry verification

**TapeGauge:** for a fixed inner width `W` and clamped fraction `f`, the new
fill spans `[(f-1)W, fW]`, clipped to `[0,W]`. Its visible region is therefore
`[0,fW]`, matching the old width-driven fill. Both dimensions, the inner
border inset, graduation positions and threshold positions remain fixed.
The caret now follows the same finite easing without integer-position
rounding. No gauge move affects parent layout.

**Application seam:** the same clipped-translation construction preserves
the old left-anchored Scale seam's visible endpoints while keeping its
geometry fixed. PIYTI/THEARS visibility, the five application definitions,
activation keys, focus matching and service calls remain unchanged.

**Bezel corners:** the top insert still starts at `(0.5, cut+20)` and turns
through `(0.5, cut+0.5)` and `(cut+0.5, 0.5)`. Rotating the second small Canvas
180 degrees about its center and placing it at the bottom-right maps those
points exactly to the old bottom-right path. At active engagement, the end
is still `cut+62`. Inactive engagement now fades the same fixed-length path;
the old path also shortened to `cut+48.32`. That deliberate small difference
keeps feedback retained rather than repainting a path during activation.

## Completion and remaining uncertainty

The new transform and opacity Behaviors use current values rather than
fixed `from` endpoints where retargeting is required. Theme changes complete
running travel/fades for off, reduced and lowEffects. OSD keeps observable
opacity for host lifetime and invokes exit JavaScript at completion, rather
than once per frame. Help cancels existing kinetic scrolling on motion-off.
The one finite startup scalar remains GUI-driven and time-based, as recorded
in the audit; it is not a steady-state ambient loop.

The initial source-only pass found no further regression; subsequent rendered
self-review exposed R2 and led to the first-sync correction above. Final
interruption continuity, docking initialization and software-renderer
throughput require the corrected capture/timing observations. The protected
host findings remain in [SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md), not silently
treated as fixed by the visual diff.
