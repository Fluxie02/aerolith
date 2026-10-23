# Independent reviews / UI-013

Two actual Codex sub-agents reviewed the work while it was being built;
another ran verification. These are local delegated agents, not a claim of
a cloud dispatcher or an installed review-agent plugin.

## Visual reviewer

Read DESIGN_BRIEF.md and the owner's UI-013 instruction, then viewed the
baseline, first production frame, compact and native 4K screenshots, and
actual motion frames in both intensities.

* Medium: 1280×720 / uiScale 1.5 active window title was horizontally clipped
  by the application bus. Confirmed independently by Astra's self-review.
  Fixed immediately: compact hero numeral .19h → .15h, leaving the class and
  title at their configured font sizes with clearance above the bus.
* Low: the lone right return carrier looked unattached. Fixed with a static
  seven-mark vernier; its position now reads against measured bounds.
* Native 4K scale 2, scale 1.5 and scale 1 with uiScale 1.5: no readability,
  soft-raster, thin-geometry or panel-boundary blocker. Large console space
  reads deliberately; do not fill it with decoration.
* Actual motion frames: opposed carriers and the Insane return path move;
  numerals, focus text, controls and primary fin remain registered. No motion
  readability blocker. Off and lowEffects ROI pairs are identical. Document
  the deliberate movement/rest cadence rather than implying constant travel.

## Motion/performance reviewer

* P1: live full → reduced can retain old Animator job endpoints/duration.
  Fixed with deferred cadence restarts after bindings settle, including
  scale, intensity and workspace-direction changes. Live frame evidence
  demonstrates a 2 px observed reduced stroke within the 3 px bound.
* P2: PauseAnimation makes a grouped sequence ineligible for the all-Animator
  render-thread path. Fixed by using a single slow Timer to start finite
  groups containing only X/Y/OpacityAnimator. No per-frame JavaScript or
  Canvas repaint is used for ambient motion.
* Every new ambient job is downstream of Theme.ambient plus local exposure.
  Finite background focus/orbit/app-latch and boot motion were also gated.
  The app latch now scales its fixed-width ink instead of animating width.

Qt primary references checked during the review:
[Animator semantics](https://doc.qt.io/qt-6/qml-qtquick-animator.html) and
[Animator job construction](https://github.com/qt/qtdeclarative/blob/v6.10.0/src/quick/util/qquickanimator.cpp).

## Single review of Claude-owned systems work

* P1, inherited: GroundSurface.qml:15/28, FlightStrip.qml:17,
  NoticeColumn.qml:16 and Deck.qml:83 have no common fullscreen suspension
  lifecycle. Compositor exposes fullscreen only through a window snapshot.
  Minimal correction: event-driven selected-output suspension and visual
  unload/unmap, preserving services and IPC. Recorded as S1; those protected
  files were not edited. This requires Claude's systems implementation.
* No additional defect found in the latest Settings/Deck integration.
  An extra portrait-output harness input observation is recorded as S3.

One systems implementation/revision by Claude remains the handoff. No
repeated review loop or unsanctioned systems fix was attempted.

## Tools and skill selection

Available tool discovery found Figma/image-generation tools but no callable
review-agent plugin. Actual sub-agents supplied independent review. The
imagegen skill was read and evaluated: its instructions exclude visuals
better built as native code/vector geometry. COUNTERPHASE uses native QML,
so adding a bitmap would weaken 4K sharpness and resource teardown. No
generated raster ships. Figma imports, Sites, Pets and unrelated connected
apps have no role in validating this running Wayland shell; they were not
invoked merely to increase tool count. Verification used real Quickshell,
Docker, Sway output captures, pixel comparisons, Qt V4, Node, pytest and
the repository's perf.sh. Relevant Qt behaviour was checked against primary
documentation while implementing the fix.
