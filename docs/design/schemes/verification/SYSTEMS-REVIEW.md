# UI-015 systems contract review

Astra performed the required single read-only review of Claude-owned systems on 2026-10-24. No systems, service, host, installer or test files were edited during this review.

Reviewed `shell/core/Config.qml`, `shell/lib/config.mjs`, `shell/services/ShellCommands.qml`, `shell/modules/deck/Deck.qml`, `shell/modules/ground/GroundSurface.qml`, `shell/modules/notices/NoticeColumn.qml`, plus the Settings bay schema traversal and mutation/key contracts.

No new actionable finding was identified in the scheme integration seam. `Config.setValue` validates against the schema, writes atomically, applies the same text immediately, preserves unrelated raw keys and restores disk state after a save failure. Invalid JSON keeps the last good settings and refuses writes until repaired. Scheme controls should call this existing path and leave these behaviours intact. The sole approved configuration extension is `theme.scheme` as an enum; no registry or terminal command is implied.

Deck slots set outgoing bays inactive before their exit, so telemetry/audio demand ends immediately. Settings holds no service demand. Notices retain their separate no-focus host and move into the Deck while it is mapped. Existing full/deck/ai scenarios cover these system contracts; their UI-015 results will be recorded separately.

The existing `Theme.ambientSuspended` hook is a documented future systems integration point, not a new UI-015 defect. Real compositor/GPU suspension and VRAM release cannot be established by the software-rendered headless harness.

Review disposition: no revision requested of Claude. Any terminal selection, app-file activation or installer support belongs in `../SYSTEMS-REQUESTS.md` under the owner's scope limit.
