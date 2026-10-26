# UI-016 verification

All required unit engines and the final 13-case functional campaign passed. The final 80-file production source matches the timing harness's corrected after source exactly and remained unchanged through verification (`source-comparison.json`, `final-unit-timing-comparison.json`, `final-summary.json`).

Node passed 118/118, Qt V4 passed 118/118, and pytest passed 71 with 1 skipped. [Exact commands, original logs and source identity](unit-final/README.md) preserve the executions. The sole later source change is `components/ChordSlot.qml`; shared libraries and unit suites are unchanged. Its corrected initialization received the targeted runtime checks below and final smoke/Deck scenarios.

## Final scenarios

Every case below exited 0 without a retry. Full uses audio, media, PipeWire output and the routines fixture. Deck uses audio and the rotated/scaled Hyprland monitor fixture on a native 1920×1080 headless Sway output. AI uses the fake provider and audio, checks one-proposal approval, then removes the module while the core keeps working.

| Scenario | PIYTI Saturated | PIYTI Insane | THEARS Saturated | THEARS Insane |
| --- | --- | --- | --- | --- |
| smoke | pass | pass | pass | pass |
| full | pass | pass | not run | not run |
| deck | pass | pass | pass | pass |
| ai | pass | pass | not run | not run |

The notification scenario also passed using the explicit notification-server fixture. THEARS is the compatibility seam; its frozen source differs only in the installation-direction default, independently checked in `source-comparison.json`.

The [complete command index](final-command-index.json) records exact commands, environment, source fingerprints, timestamps, elapsed times and exit codes. Each text record below retains complete stdout. Screenshots, statuses and verbatim `qs.txt` copies are in the matching `runs/` directory.

| Run | Exit | Command and output |
| --- | ---: | --- |
| piyti-insane-full-ai | 0 | [piyti-insane-full-ai](results/piyti-insane-full-ai.txt) |
| piyti-insane-full-deck | 0 | [piyti-insane-full-deck](results/piyti-insane-full-deck.txt) |
| piyti-insane-full-full | 0 | [piyti-insane-full-full](results/piyti-insane-full-full.txt) |
| piyti-insane-full-smoke | 0 | [piyti-insane-full-smoke](results/piyti-insane-full-smoke.txt) |
| piyti-saturated-full-ai | 0 | [piyti-saturated-full-ai](results/piyti-saturated-full-ai.txt) |
| piyti-saturated-full-deck | 0 | [piyti-saturated-full-deck](results/piyti-saturated-full-deck.txt) |
| piyti-saturated-full-full | 0 | [piyti-saturated-full-full](results/piyti-saturated-full-full.txt) |
| piyti-saturated-full-notify | 0 | [piyti-saturated-full-notify](results/piyti-saturated-full-notify.txt) |
| piyti-saturated-full-smoke | 0 | [piyti-saturated-full-smoke](results/piyti-saturated-full-smoke.txt) |
| thears-insane-full-deck | 0 | [thears-insane-full-deck](results/thears-insane-full-deck.txt) |
| thears-insane-full-smoke | 0 | [thears-insane-full-smoke](results/thears-insane-full-smoke.txt) |
| thears-saturated-full-deck | 0 | [thears-saturated-full-deck](results/thears-saturated-full-deck.txt) |
| thears-saturated-full-smoke | 0 | [thears-saturated-full-smoke](results/thears-saturated-full-smoke.txt) |

The campaign runs at most two of its own containers and starts only after the timing harness's explicit benchmark release. An illustrative recording may overlap these functional checks; no CPU or frame-pacing measurements are derived from the overlap. Reproduce with `python3 docs/design/smooth/verification/scripts/campaign.py` after recreating the approved frozen source with `python3 docs/design/smooth/verification/scripts/verify.py freeze`. The driver retains successful cases while resuming the same manifest.

## Targeted checks and review

[Provisional gap checks](GAP-CHECKS.md) loaded production legacy CircularField, OSD, Lock and Session views in an ordinary visual fixture. OSD normal/off/reduced/lowEffects exits each settled once, and immediate reopening emitted no obsolete exit. The fixture performs no authentication or session action. Its first wrapper hit a fixture-only IPC method-name collision; that attempt and the successful corrected retry are preserved.

[Corrected checks](CORRECTED-CHECKS.md) passed cold A/B-slot reuse, close/reopen, rapid bay replacement and live motion-mode changes. Off and lowEffects ground ROIs were pixel-identical between samples 0.3 s apart. The [motion review](MOTION-REVIEW.md) records the actual cold scene-graph defect found after the first functional pass: native Animators could read an uninitialized origin on the first retained slots. Rejected source/pixels remain under `../attempts/first-sync/`. The final guarded, one-shot first-render initialization passed corrected 60/144 Hz marker probes in the intended entry band and through exits. Capture load delayed requested 35/70 ms closes to 57–122 ms; strict 35 ms interruption remains unmeasured.

The [final log audit](log-audit.json) covers 20 retained QML logs with zero parse/type/reference/assignment/binding-loop/crash findings. Known headless diagnostics remain in full: unavailable system D-Bus/RTKit, PipeWire context failures in deliberately audio-free fixtures, and unsupported Hyprland shortcut/toplevel protocols under Sway. The routines fixture deliberately contains the rejected broken example; full status still records zero configuration errors.

The single read-only review of Claude-owned systems is in [SYSTEMS-REVIEW.md](SYSTEMS-REVIEW.md). A confirmed protected-host edge remains requested for Claude: disabling motion/lowEffects during an outgoing Deck exit retains the old host deadline, while the final visual outgoing face hides immediately. Minimal correction is to release already-leaving slots when exitMs becomes zero. No protected host, service, existing tool/test or git metadata was modified by this verification subtask.

UI-013 idle budgets are approximately 2% of one core for Saturated and 4% for Insane. CPU and timing data belong to the separate timing harness under `../data/`; verification containers were stopped during its exclusive measurements. Sway/pixman software rendering and Hyprland protocol fixtures do not establish real GPU/Hyprland/PAM or VRAM behaviour.
