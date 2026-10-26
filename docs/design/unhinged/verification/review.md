# UI-011 review

## Claude systems review (one pass)

Reviewed Claude commit `5649b02` and the current surface implementations read-only:

- `shell/core/Ui.qml`: Settings is present in the accepted bay ids.
- `shell/modules/deck/Deck.qml`: Ctrl+7 selects Settings while Ctrl+1–6 retain their mapping; Help remains F1. Retiring a bay immediately clears active demand and focus, then releases its component and surface hold after the bounded exit.
- `shell/services/ShellCommands.qml`: Settings command registration agrees with the UI and loader routing.
- `shell/modules/ground/GroundSurface.qml`: background surface retains no keyboard focus and tracks the selected display.
- `shell/modules/notices/NoticeColumn.qml`: notices remain nonexclusive and hide while the Deck is mapped.

No actionable systems findings. No systems files were edited.

## UI-011 visual implementation review (one pass)

Reviewed `InstrumentField.qml`, `ShearField.qml`, `Instrumentation.qml`, `WorkspaceOrbit.qml`, `DeckView.qml`, `ChordSlot.qml`, and `Bezel.qml` for bindings, component APIs, V4 syntax, motion modes and hidden surfaces.

1. **P2 — desktop workspace targets leak into the Deck.** `Instrumentation.qml` instantiates `WorkspaceOrbit` with `visible: !rig.compact`, replacing the component's `visible: !instrument` binding. `WorkspaceOrbit.qml` no longer hides each station in instrument mode, so the Deck can expose desktop-only workspace targets. Minimal correction: set the caller's visibility to `!rig.instrument && !rig.compact`.
2. **P2 — hidden hosts can animate the workspace arm.** `WorkspaceOrbit.qml:21` enables the rotation behavior using only `Theme.travel && orbit.visible`; QML item visibility does not become false simply because its host window is unmapped. A workspace event can therefore start the 520 ms animation in an invisible host. Minimal correction: include actual `Window.window.visible` exposure, and stop/settle the named arm animation when exposure is lost.

Both findings were sent to the root agent for the single revision; this review made no implementation changes.

**Revision status: both fixed.** The frozen final source at `build/ui011-final-shell/shell` contains `visible: !rig.instrument && !rig.compact` at the `WorkspaceOrbit` call site. The orbit now derives `exposed` from both item and host-window visibility, gates its named `indexMotion` with exposure, and completes the animation when hidden or travel is disabled. Shear blade rotation has the same completion guards. The core sample height animation was removed.

`git diff --check` exited 0. Bezel-specific `qmllint` exited 0 with unqualified singleton-access warnings only. Full scenario and motion verification is recorded separately by the root agent.

## Additional accessibility matrix

Ran the following against the frozen final shell, with the existing `build/ui011/accessibility.sh` scenario:

```bash
CONFIG=build/ui011/saturated-off.json AUDIO=1 SHELL_PATH=build/ui011-final-shell/shell RES=1920x1080 tools/headless/run.sh build/ui011/accessibility.sh docs/design/unhinged/accessibility/saturated-off
CONFIG=build/ui011/insane-reduced.json AUDIO=1 SHELL_PATH=build/ui011-final-shell/shell RES=1920x1080 tools/headless/run.sh build/ui011/accessibility.sh docs/design/unhinged/accessibility/insane-reduced
CONFIG=build/ui011/saturated-low-effects.json AUDIO=1 SHELL_PATH=build/ui011-final-shell/shell RES=1280x720 tools/headless/run.sh build/ui011/accessibility.sh docs/design/unhinged/accessibility/saturated-low-effects
```

All three completed with exit 0 and `accessibility: ok`. Each exercised workspace/focus events, literal `<i>Window title remains plain text</i>` input, typed `vol 45` plus Return with the actual PipeWire volume assertion, Systems, Settings and close. Their `status.json` reports zero config/routine errors, no mapped Deck after close, 5000 ms telemetry and zero audio-detail demand. Evidence directories contain all six screenshots, `qs.log` and `status.json`; exact console output is in `verification/runs/accessibility-<name>.txt`.

Judged the 720p screenshots with UI scale 1.25 and Noto Sans/Noto Sans Mono. Main readings, command input/results, tabs, Settings controls and key hints remain legible and inside the working surface. Judged the synthetic title in both full-size and 720p settled screenshots: its literal angle-bracket tags remain visible as plain text. No QML type/reference/assignment/syntax/binding errors appeared in the successful runs' `qs.log` files. The logs retain expected headless compositor/UPower/RTKit warnings; Insane reduced also has a PipeWire connection warning at shutdown after the scenario passed.

The first Saturated-off attempt, run concurrently with the other two, failed its volume assertion because typed text did not reach the input. Its command screenshot shows an empty input, and the log has Wayland keyboard-leave/focus warnings without QML engine errors. The unchanged scenario passed when rerun serially. Initial evidence is preserved in `accessibility/saturated-off-attempt1/` and `verification/runs/accessibility-saturated-off-attempt1.txt`; no implementation was changed to obtain the passing result. These functional runs were finished before further CPU measurements.
