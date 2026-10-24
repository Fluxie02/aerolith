# UI-015 palette propagation review

Astra's independent verification sub-agent reviewed the in-progress scheme catalogue, picker and shared visual sources. This is a local sub-agent review, not a dispatch of Claude.

## Finding and one correction

**P2 — A visible recorder trace retained its prior palette until a new sample.** Affected file: `shell/components/Trace.qml`, formerly handlers at lines 19–24. The Canvas repainted only after sequence, visibility or size changes; its signal/grid/caution ink reads Theme in `onPaint`, so a live scheme switch could leave stale colours. Minimal proposed correction: event-driven `onColorChanged`, and Theme `paletteChanged`/`lowEffectsChanged` handlers that request a paint only while visible. No timer or sampling change.

Root Astra applied exactly those handlers. Follow-up source inspection confirms the correction. No second revision is requested.

## Remaining source audit

The active shell's literal palette hex colours are confined to `shell/lib/schemes.mjs`; views bind Theme roles. InstrumentField, ShearField, Bezel, ChordSlot, InstrumentTabs, CircularField, Deck elevation and LockView all already repaint Canvas faces on palette changes. OSD and Session read Theme directly. PIYTI application edges now resolve the chosen specimen's link colour; THEARS uses signal through the same visual seam.

The picker keeps keyboard cursor and active scheme separate. Each specimen has an explicit ACTIVE label, a strong signal rim, light cursor corners, readable type/inverse selection and a fixed band order. All displayed strings use plain text. It adds no timers, Canvas, shader or layer. Existing ambient jobs retain the single Theme.ambient gate and event-driven exposure checks.

The current twelve opaque palettes independently measured at least 5.35:1 across all text/status/application foreground roles against the three base planes; full composited-plane and focus ratios are recorded by the scheme test and generated contrast report. Custom user palette overrides can lower contrast and are visibly disclosed in the picker.
