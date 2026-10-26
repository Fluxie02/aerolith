# UI-009 · before / after

Original headless screenshots, without compositing or retouching. Full desktop
captures are 1920×1080. `small/` captures are 1280×720, uiScale 1.5, Noto fallback
fonts, motion off and opaque lowEffects. Insane keeps its additional engraving;
Saturated remains the default. [Review](../REVIEW.md) · [Verification](verification/RESULTS.md).

| Surface | Saturated | Insane |
| --- | --- | --- |
| Ground | [Before](before/saturated/full/ground.png) → [After](after/saturated/full/ground.png) | [Before](before/insane/full/ground.png) → [After](after/insane/full/ground.png) |
| Actual first-boot assembly | [Before](before/saturated/full/boot-03.png) → [After](after/saturated/full/boot-03.png) | [Before](before/insane/full/boot-04.png) → [After](after/insane/full/boot-04.png) |
| Command / navigation | [Before](before/saturated/full/command.png) → [After](after/saturated/full/command.png) | [Before](before/insane/full/command.png) → [After](after/insane/full/command.png) |
| Navigator | [Before](before/saturated/full/navigator.png) → [After](after/saturated/full/navigator.png) | [Before](before/insane/full/navigator.png) → [After](after/insane/full/navigator.png) |
| Systems | [Before](before/saturated/full/systems.png) → [After](after/saturated/full/systems.png) | [Before](before/insane/full/systems.png) → [After](after/insane/full/systems.png) |
| Signal | [Before](before/saturated/full/signal.png) → [After](after/saturated/full/signal.png) | [Before](before/insane/full/signal.png) → [After](after/insane/full/signal.png) |
| Routines | [Before](before/saturated/full/routines.png) → [After](after/saturated/full/routines.png) | [Before](before/insane/full/routines.png) → [After](after/insane/full/routines.png) |
| Help | [Before](before/saturated/full/help.png) → [After](after/saturated/full/help.png) | [Before](before/insane/full/help.png) → [After](after/insane/full/help.png) |
| Settings | [Before](before/saturated/full/settings.png) → [After](after/saturated/full/settings.png) | [Before](before/insane/full/settings.png) → [After](after/insane/full/settings.png) |
| AI console | [Before](before/saturated/full/ai.png) → [After](after/saturated/full/ai.png) | [Before](before/insane/full/ai.png) → [After](after/insane/full/ai.png) |
| Notices | [Before](before/saturated/full/notice.png) → [After](after/saturated/full/notice.png) | [Before](before/insane/full/notice.png) → [After](after/insane/full/notice.png) |

| At 1280×720 / uiScale 1.5 | Saturated | Insane |
| --- | --- | --- |
| Ground identity and entry controls | [Before](before/saturated/small/ground.png) → [After](after/saturated/small/ground.png) | [Before](before/insane/small/ground.png) → [After](after/insane/small/ground.png) |
| Navigation and readable results | [Before](before/saturated/small/command.png) → [After](after/saturated/small/command.png) | [Before](before/insane/small/command.png) → [After](after/insane/small/command.png) |
| Settings viewport | [Before](before/saturated/small/settings.png) → [After](after/saturated/small/settings.png) | [Before](before/insane/small/settings.png) → [After](after/insane/small/settings.png) |
| Lock failure | [Before](before/views/lock/saturated-small-failed.png) → [After](after/views/lock/saturated-small-failed.png) | [Before](before/views/lock/insane-small-failed.png) → [After](after/views/lock/insane-small-failed.png) |
| Session menu | [Before](before/views/session/saturated-small-menu.png) → [After](after/views/session/saturated-small-menu.png) | [Before](before/views/session/insane-small-menu.png) → [After](after/views/session/insane-small-menu.png) |
| OSD, including unknown volume | [Before](before/views/osd/saturated-small-unknown.png) → [After](after/views/osd/saturated-small-unknown.png) | [Before](before/views/osd/insane-small-unknown.png) → [After](after/views/osd/insane-small-unknown.png) |
| AI action review / long literal output | [Approved](after/saturated/ai-actions/a2-approved.png), [last proposal](after/saturated/ai-states/q4-last-proposal.png) | [Approved](after/insane/ai-actions/a2-approved.png), [last proposal](after/insane/ai-states/q4-last-proposal.png) |
| Sharing, multiple outputs and DND | [Events](after/saturated/events/e3-sharing-multi-dnd.png) | [Events](after/insane/events/e3-sharing-multi-dnd.png) |

[Popup / Saturated](after/saturated/notices/n1-popup.png) and
[Insane](after/insane/notices/n1-popup.png), plus
[notices over Deck](after/insane/notices/d1-notices.png), keep the same material.

[Reduced-motion Saturated](after/saturated/reduced/command.png) and
[Insane](after/insane/reduced/command.png) retain the complete instrument.
[Real themed foot / Saturated](after/saturated/terminal/08-terminal-with-shell.png)
and [Insane](after/insane/terminal/08-terminal-with-shell.png) show an actual
Wayland application with the shell. The harness uses sway; native Hyprland
rounding and GPU memory release require a real Hyprland/GPU session.

Lock, OSD and session images are production **view** previews with synthetic
inputs in ordinary overlay windows; the lock preview does not secure a session.
AI replies, proposals and provider errors come from fake CLIs. Counters and
telemetry vary between captures; no fictitious system metrics were painted.
`captures.json` records PNG dimensions, run provenance and SHA-256 hashes.
