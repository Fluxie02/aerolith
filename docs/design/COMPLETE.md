# Desktop completion · UI-006

Saturated and Insane retain the chosen Limb direction. The AI Bridge now uses
its chord frame, a persistent data-flow disclosure and prompt, a scrollable
plain-text response register, and individually reviewed action rows. Its
standalone package, service code, request/cancel/approval flows, keyboard
handlers, pending query and busy-only timer are preserved.

The strip stacks annunciators on compact displays, bounds long owner/media
labels, keeps sharing visible, and shows unknown temperature/audio as N/A.
Command Core makes room for complete results at 720p / uiScale 1.5. Navigator
has a dedicated disconnected view. Signal and routines scroll, including
keyboard paging; Help documents the actual handlers and wraps long shortcuts.
Missing AI, empty audio, invalid routines, notices and popups use Limb's
existing material, typography and state colours in both intensities.

[70 judged screenshots](complete/README.md) and [exact verification](complete/verification/RESULTS.md)
are saved. Node and Qt: 104/104 each; Python: 71 passed, 1 skipped. Smoke,
full, signal, scaled deck, notify and AI pass in both intensities; the signal
harness skips routing on its unlinked graph. All 63 QML logs were read with no
QML regressions. Native Codex console checks pass in both intensities; its
required scenario has the fixture mismatch below. Idle: 0.29% / 0.32% of one
core, versus 0.29% baseline; assembly runs once and survives switch/remap.

GroundSurface.qml, Deck.qml, NoticeColumn.qml, services, schema/config logic,
FlightStrip's visibility binding and the startup latch are unchanged. No Git
writes or commits were attempted.

Systems review finding P2: `tests/scenarios/ai.sh` assumes the Claude fixture
(two proposals, Claude flags, volume approval) and fails with `AI_PROVIDER=codex`,
whose fixture returns one media proposal. Claude should branch the scenario's
expectations by provider. A separate native Codex console check verifies its
read-only invocation, explicit send, dismiss without side effects and approval.
Real Hyprland/GPU transitions and a real UPower battery remain integration checks.
