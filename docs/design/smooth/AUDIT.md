# UI-016 motion audit

Scope: all 69 QML files under `shell/`, including 29 module files and 21 shared
visual components, every bay, Settings/Spectra, lock, OSD and session. The source inventory used
`rg` for `Animation`, `Animator`, `Behavior`, `Transition`, `Timer`,
`requestPaint`, `Canvas`, change handlers and kinetic scrolling. There is no
`FrameAnimation`, frame-counted movement, visual sampling loop or shader.
Time durations use Theme tokens. Native Qt animations use the compositor's
frame cadence rather than a 60 Hz motion clock.

## Motion-bearing paths

| Path | Baseline behavior and cost | UI-016 disposition |
| --- | --- | --- |
| `core/Theme.qml` | One process-latched, time-based startup scalar; shared palette/motion tokens and the sole ambient gate. | Keep wall-time startup and latching. Read selected-output monitor metadata without polling. Space ambient strokes farther apart at higher refresh to preserve the idle budget; do not slow individual strokes or cap their cadence. |
| `components/ChordSlot.qml` | Time-based Deck progress scalar fed x/y/opacity; restarting with fixed endpoints can jump on rapid retirement/reopen. | Retained-item Animators for docking and fading, with a first-render synchronization gate before entry. One-shot `afterAnimating`/`frameSwapped` handlers disconnect when presented; queued docking is guarded by the slot's generation. No ongoing per-frame JavaScript, animated size or anchor. |
| `components/Bezel.qml` | Engagement NumberAnimation caused a large face Canvas repaint on every engagement change. | Keep the engraved face cached and animate a small retained engagement mark. |
| `components/InstrumentTabs.qml` | Highlight x/y NumberAnimations; static track Canvas; short color feedback. | Move highlight with Animators; preserve finite color feedback and complete it on live motion-off. Track repaints only for discrete geometry/tokens. |
| `components/ShearField.qml` | Workspace rotation is time-based; focus recoil restarts from a fixed impulse; finite opacity breathing uses Animators. | Retained transforms/opacity and retargetable focus response. Do not repaint blade geometry during movement. |
| `components/WorkspaceOrbit.qml` | Time-based workspace rotation; Canvas-free retained arm; hidden/travel/ambient completion guards. | RotationAnimator with interruption and gate completion. |
| `components/AppContinuity.qml` | Application-focus reach scalar drives a seam Scale transform. | Animate only the retained seam within a clipped track; preserve PIYTI and THEARS semantics, keys and matching. |
| `components/Counterphase.qml` | One low-frequency Timer starts finite X/Y Animator strokes and finite breathing. It does not increment position or count frames. A workspace/scale/intensity change can restart a stroke from its origin. | Keep the Timer as a rest scheduler. Freeze endpoints/duration for each stroke and apply ordinary cadence/state changes to the next stroke. Reduced/off cancellation, ambient gate, exposure, reduced amplitude and finite rest remain intact. |
| `components/TapeGauge.qml` | NumberAnimation changes fill width for sampled data; no layout dependency, but unnecessary geometry mutation. | Retained clipped fill and fluid finite easing. Keep unknown values unavailable. |
| `components/CircularField.qml` | Compatibility Canvas includes a progress-change repaint hook. | Cache static circle geometry; animate retained opacity/transform only, removing motion-to-Canvas coupling. |
| `modules/osd/OsdView.qml` | Time-based opacity and Translate.y; `onOpacityChanged` calls JavaScript for every fade frame to detect exit. | Retain observable opacity for lifecycle; move exit detection to animation completion and disabled-mode settlement. Translation is a transform, not layout. |
| `modules/settings/SettingControl.qml` | Boolean knob NumberAnimation on x. | XAnimator with no fixed `from`; reduced/off/lowEffects jump immediately, including a live loss of travel. Numeric marker remains a discrete data change. |
| `modules/help/HelpBay.qml` | Native Flickable velocity is time-based, enabled only for Theme.animate; off jumps. | Keep native kinetic scrolling and cancel an already-running flick on live motion-off. No visual clock added. |

## Surface and bay coverage

| Paths | Classification |
| --- | --- |
| `modules/deck/DeckView.qml` | Composes the two ChordSlots, static rail/engraving and instrument field. `fieldProgress` is a finite visibility target; a retained OpacityAnimator supplies command-elevation feedback and completes on live motion-off. Animated child movement does not resize this scene. |
| `modules/deck/Deck.qml` | Protected systems host. One exit Timer enforces resource lifetime; motion is in the view. Current demand/focus end at retirement. Live disable of an already-retired slot is a medium finding; see SR-016-2. |
| `modules/ground/Ground.qml`, `GroundSurface.qml` | Ground composes InstrumentField/Instrumentation; host owns background-layer mapping. Existing one-time `Theme.ignite()` and shared ambient primitives supply motion. No per-frame host work. |
| `modules/strip/FlightStrip.qml`, `WorkspaceTape.qml` | Event-driven workspace/title/status updates. Workspace cells change discretely; there is no stepped animation. Native Flickable scrolling is time-based. Protected namespace/exclusive-zone/focus behavior stays exact. |
| `modules/strip/StripClock.qml` | SystemClock updates at minute precision by default, seconds only on request. This is data sampling rather than a motion clock. |
| `modules/notices/NoticeStack.qml`, `NoticeColumn.qml` | Keyed static cards; services own expiry. No card animation, visual Timer or layout animation. Surface handoff to Deck stays in hosts. Compositor layer animation is a high integration finding; see SR-016-1. |
| `modules/command/CommandCore.qml`, `ResultRow.qml` | Static result/filter/selection updates, native ListView scrolling and shared Bezel feedback. No additional motion. |
| `modules/navigator/SpatialNavigator.qml`, `Sector.qml` | Static workspace/window selection plus native Flickable/ListView scrolling. Keyboard reveal adjusts content once per input; no frame loop. Shared Bezel and gauges cover their visual motion. |
| `modules/systems/SystemsBay.qml`, `CoreBus.qml` | Existing demand-driven telemetry updates, shared gauges/traces and native scrolling. Core data changes do not introduce timers or perpetual animation. |
| `modules/signal/SignalRack.qml`, `DeviceRow.qml`, `StreamRow.qml`, `PlayerCard.qml` | Native scrolling, shared gauges, discrete device/player state. Existing 1000 ms MPRIS position refresh reports media data; it does not step a decorative motion path. Audio demand and service calls stay exact. |
| `modules/routines/RoutineConsole.qml` | Static execution/selection changes and native scrolling. Shared Bezel feedback only. |
| `modules/help/HelpBay.qml` | Native time-based flicking for command list; direct keyboard page reveal for reference. No sampling or drawing loop. |
| `modules/settings/SettingsBay.qml`, `SchemePicker.qml` | Spectra applies palette changes as discrete state updates, and static specimens remain cached. No crossfade repaints of whole surfaces. Shared motion readout reports full/reduced/off/lowEffects and actual current-output rate. No new setting, PIYTI/THEARS selector or config mutation path. |
| `modules/lock/LockView.qml` | Static engraving and state changes; minute SystemClock; masked text entry. No spinner, shake, animated geometry or decorative loop. Authentication and lock lifecycle remain systems work. |
| `modules/session/SessionView.qml` | Static action/confirmation changes. List highlight movement duration is explicitly zero; native scrolling only. No motion clock or process/session call in view. |
| `modules/AiLoader.qml`, `ControlSurface.qml` | Systems composition/IPC/shortcut loading. No visual animation or motion sampling. Optional AI bay lives outside `shell/`; its keys, service contract and shared visual primitives stay intact. |

## Static and event-painted components

`InstrumentField.qml` paints its large Canvas only on discrete workspace,
level, geometry, appearance and host remap changes; animated elements are
retained children. `Instrumentation.qml` composes retained readouts and shares
the finite startup scalar. `Trace.qml` repaints on a visible sample-sequence
change or visual/geometry change, independently of display Hz.

`Annunciator`, `AppGlyph`, `KeyHint`, `Label`, `MetricTape`, `Readout`, `Ruler`,
`ScrollMark` and `StatusLine` contain no authored animation or Timer. Their
bindings update from input/data changes. Scroll marks follow native content
movement without a separate clock.

## Systems Timer classification

`Ui` and `Notifications` schedule expiry from absolute arrival deadlines;
`Wait` handles asynchronous results; `Store` debounces persistence; `Exec`
enforces process deadlines; `Registry` supplies V4-safe deferred jobs;
`Routines` debounces validation; `Telemetry` samples existing service demand.
None advances a visual position per tick. These files are not changed.

## Remaining integration findings

Rendered self-review exposed a first-use scene-graph initialization defect in
the first native Animator candidate: a cold Deck plane began near x=0 rather
than its intended entry pose. The correction waits for the entry pose's first
actual render before enabling docking, and invalidates stale queued callbacks
on slot release/reuse. The rejected pixels are preserved in
[attempts/first-sync](attempts/first-sync/README.md); they are not final AFTER
evidence. See [SOURCE-REVIEW.md](SOURCE-REVIEW.md) for this correction and its
separate rendered acceptance requirement.

The two actionable systems findings and minimal corrections are recorded in
[SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md). The read-only host review is in
[verification/SYSTEMS-REVIEW.md](verification/SYSTEMS-REVIEW.md). Physical GPU,
Hyprland layer-animation and variable-refresh validation remains distinct
from the software-renderer harness evidence.
