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

No additional actionable source regression was found in this pass. Rendered
interruption continuity, docking initialization and software-renderer
throughput still require the saved capture/timing observations. The protected
host findings remain in [SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md), not silently
treated as fixed by the visual diff.
