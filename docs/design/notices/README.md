# D03 — Notices beside the Deck

Astra, 26 October 2026. Base: `4f9944bad72557ba0a2b57c2fcea57555688fd7d`.

The fault was inside `DeckView`: its `z: 10` notice stack shared the rail’s
upper-right origin. At 1280×720/uiScale 1.5, the old stack occupied
`(695, 57, 570, 207)` and intersected the rail at `(57.6, 54, 1164.8, 101)`.
The notification and real volume result covered tabs and Help controls.
The standalone column correctly hid while the Deck was mapped.

## Placement rule

* Reserve one right-hand notice lane, one theme pad below the whole rail.
  Its width is the smaller of 380 scaled pixels and 32% of the output.
* While notices exist, subtract the lane width plus two pads from both
  retained bay widths. Preserve their parents, vertical space and lifecycle.
  Apply the reservation immediately; no control animates underneath a card.
* Bound both notice hosts to the usable output height. Overflow scrolls
  vertically with a passive position mark. Motion off cancels inertia.
* Keep popups first, then shell notices, in existing arrival order. Preserve
  keyed records, typography, semantic colors, plain text, activation and
  service-owned expiry. No shaders or new ambient animation.

At 1280×720/uiScale 1.5, the lane starts at `(855.4, 170)`, is 409.6 pixels
wide and has a 535-pixel height budget. The settled bay ends at x=782.8,
leaving about 73 pixels between its working rectangle and the lane.

## Evidence

| Compact PIYTI / Insane | Before | After |
| --- | --- | --- |
| Help + volume | [Before](before/piyti-insane-720large-help.png) | [After](after/piyti-insane-720large-help.png) |
| Settings | [Before](before/piyti-insane-720large-settings.png) | [After](after/piyti-insane-720large-settings.png) |

[Eight-card burst](after/piyti-insane-720large-multiple.png),
[scrolled to the last card](after/piyti-insane-720large-multiple-scrolled.png).
Other screenshots cover THEARS, Saturated, 1080p and lowEffects/bottom-edge.
All PNGs are untouched headless captures. Literal `<b>plain text</b>` is an
intentional fixture string.

Run `tests/scenarios/notices-layout-matrix.sh build/headless/D03-layout`.
The probe checks actual rendered geometry in disposable shell copies;
production IPC and systems files need no diagnostic changes.
Seventeen profiles passed 340 snapshots, including the installed AI console.
[Checks and reproduction](verification/CHECKS.md) list commands, results,
source hashes, complete logs and the demonstrated failure on old QML.

## Limits and handoff

Headless sway/software rendering does not establish real Hyprland or GPU
pacing. Bursts can require scrolling before existing timeouts expire. Bays
wrap or elide more text while narrowed, then regain their width.

Read-only systems review found no D03-blocking host change. Opus need not
change `NoticeColumn.visible`, surface existence, `Deck.qml` or services.
A timing-sensitive fullscreen test assertion is documented for Sol in
[the review notes](verification/CHECKS.md#systems-review).
