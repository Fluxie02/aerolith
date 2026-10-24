# UI-016: single read-only review of Claude's systems contracts

Reviewed once on 2026-10-24: `shell/services/Compositor.qml`, `shell/core/Ui.qml`, `shell/modules/ControlSurface.qml`, `shell/modules/deck/Deck.qml`, `shell/modules/ground/GroundSurface.qml`, and `shell/modules/notices/NoticeColumn.qml`. Git history contains no new Claude integration commit after the previously reviewed host/Settings contracts. The canonical worktree remains on Claude's older branch; no uncommitted Claude change was present to review. No protected host, service, existing test, tool or git metadata was changed.

## Finding S1 — medium: disabling motion during an exit retains the old host deadline

Evidence: `Deck.qml:244–247` snapshots `deck.exitMs` into `exitTimer.interval` only when `BaySlot.retire()` runs. `exitMs` itself recomputes to zero for motion off or lowEffects (`Deck.qml:34`), but no handler releases a previously leaving slot when that value changes. Its old Timer is not rebound. A mid-exit disable can therefore retain the Deck surface until the remaining old deadline, even though a fresh close while disabled releases immediately. The current `tests/scenarios/deck.sh` disables motion *before* opening/closing; that case does not check a live disable during exit.

Minimal correction for Claude: on `exitMs` becoming zero, release each leaving slot immediately and update the held surface. Keep the current bay, focus, demand release and map-count contracts. This task explicitly forbids editing `Deck.qml`; the finding belongs in `../SYSTEMS-REQUESTS.md`. The targeted runtime probe confirmed both modes: before disable `exitMs:160, mapped:true, leaving:true`; immediately after disable `exitMs:0, mapped:true, leaving:true`. By 0.3 s the Deck was unmapped. Evidence is retained in `runs/provisional-mid-exit/{off,lowEffects}-immediate.json` and matching settled statuses. The inspection-only IPC in a copied `shell.qml` calls close/disable synchronously; the copied `Deck.qml` is byte-for-byte production.

## Existing boundaries retained

`Compositor.monitorGeometry()` returns logical geometry/scale and drops refresh rate. Hyprland monitor snapshots remain the correct systems source for refresh metadata; the visual Settings implementation must not assume the mock's advertised rate proves the real Sway/Qt output refresh. Root's request file owns that interface specification.

Deck demand and focus end as soon as a bay retires, independent of the visual exit Timer. Notices expire from arrival timestamps and are keyed, so their timers manage lifecycle rather than stepping animation. The one `Theme.ambient` gate and future `ambientSuspended` hook remain intact. Host unmap/unload for fullscreen/game GPU-memory release and real-lock/PAM integration remain inherited systems work, outside software-rendering verification.
