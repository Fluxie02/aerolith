# Judged desktop captures · UI-006

Both intensities keep the chosen Limb composition, phosphor registrations,
mineral planes and asymmetry. Normal views were judged at 1920×1080;
`small/`, `states/`, `codex/`, `annunciators/` and `edges/` at 1280×720 with
uiScale 1.5 and Noto fallback fonts. Screenshots are original harness captures.

| Judgement | Saturated | Insane |
|---|---|---|
| Complete desktop; strip remains quiet and readable | [Desktop](saturated/full/01-strip.png) | [Desktop](insane/full/01-strip.png) |
| AI disclosure, reply, warning and per-action review share the Limb hierarchy | [Answer](saturated/ai/a1-answer.png) | [Answer](insane/ai/a1-answer.png) |
| Large-scale command input leaves two complete result rows | [Command](saturated/small/command.png) | [Command](insane/small/command.png) |
| Disconnected compositor has a dedicated explanation | [Offline](saturated/small/navigator.png) | [Offline](insane/small/navigator.png) |
| Empty audio and broken routines have readable recovery states | [Signal](saturated/small/signal.png), [routines](saturated/small/routines.png) | [Signal](insane/small/signal.png), [routines](insane/small/routines.png) |
| Missing optional AI offers a concrete setup command | [Missing AI](saturated/small/ai.png) | [Missing AI](insane/small/ai.png) |
| Busy, cancelled and authentication faults remain distinguishable | [Busy](saturated/states/q1-busy.png), [cancelled](saturated/states/q2-cancelled.png), [fault](saturated/states/q6-auth-fault.png) | [Busy](insane/states/q1-busy.png), [cancelled](insane/states/q2-cancelled.png), [fault](insane/states/q6-auth-fault.png) |
| Long output scrolls; markup remains literal; last proposal is reachable | [Last proposal](saturated/states/q4-last-proposal.png) | [Last proposal](insane/states/q4-last-proposal.png) |
| Native Codex approval fits above the permanent key reference | [Approved](saturated/codex/c3-approved.png) | [Approved](insane/codex/c3-approved.png) |
| All strip annunciators coexist without hiding sharing | [Stress fixture](saturated/annunciators/g1-all-annunciators.png) | [Stress fixture](insane/annunciators/g1-all-annunciators.png) |
| Real multi-output, DND and sharing events preserve the single-display layout | [Sharing](saturated/edges/e3-sharing-multi-dnd.png) | [Sharing](insane/edges/e3-sharing-multi-dnd.png) |
| Notices and notification popups retain the same material and type hierarchy | [Notice](saturated/edges/e4-notice.png), [popup](saturated/popups/n1-popup.png) | [Notice](insane/edges/e4-notice.png), [popup](insane/popups/n1-popup.png) |
| Reduced motion and opaque lowEffects remain complete | [Reduced](saturated/reduced.png), [lowEffects](saturated/low.png) | [Reduced](insane/reduced.png), [lowEffects](insane/low.png) |

`annunciators/` is a presentation stress fixture: a copied FlightStrip forces
battery, temperature and other alert values to show every cell together. It
checks layout and plain text, not live UPower or sensor integration. `edges/`
uses real shell services with the Hyprland protocol mock, headless sway outputs,
DND and notification events. `states/` uses a writable fake CLI; no provider
network calls occur. The production services are never replaced or edited.

The remaining `full/` captures cover every bay and a completed routine. Help
wraps long shortcuts; PgUp/PgDn reaches the complete reference. Signal and
routines use PgUp/PgDn to expose content below the viewport. Every selected
proposal is revealed without introducing animation or sampling.

All 70 PNGs, dimensions and hashes: [capture manifest](captures.json).
Exact commands, outcomes, limitations and CPU comparison:
[verification](verification/RESULTS.md).
