# Limb intensity · UI-005

Saturated is the production default. Insane is the owner's second choice;
Dense is dropped. Both reproduce the round-three prototypes using one shared
Limb field, instrument bus, workspace arc, strip and set of functional bays.

Show the owner [Saturated](intensity/01-saturated.png) and
[Insane](intensity/02-insane.png) first, then the paired Command Core and
Navigator screenshots in `intensity/{saturated,insane}/full/`.

Switch from a terminal with `aerolith intensity insane` or
`aerolith intensity saturated`; query with `aerolith intensity`.
Inside Command Core, enter `intensity insane` or `intensity saturated`.
The setting is `theme.intensity`; installation-time selection remains deferred.

Theme exposes `intensity` and `insane`. Shared geometry and readouts bind to
the selected intensity; Canvas explicitly clears and repaints on changes.
Insane adds its outer ribs, index spine, command matrix and extra history tapes;
Saturated restores its single-line wordmark, larger window register and
capacity/audio route. Switching preserves the open bay and keyboard input.
No second set of whole bay or host files is created.

The startup latch lives in Theme for the process lifetime: 2.08 s in Saturated,
2.60 s in Insane. Its selected duration is fixed at ignition. Reduced/off motion
and lowEffects skip assembly. Switching intensity does not replay it. Surface
visibility and Canvas availability trigger reconstruction after remapping.
There are no added timers, sample demand, shaders or idle animation loops.
Unknown values remain N/A; unknown cores use hollow frames. Functional planes
are 97% opaque, or fully opaque under lowEffects. The existing AI component API,
keys, demand lifetimes and notice ordering are preserved.

Node and Qt V4: 104/104 each. Pytest: 71 passed, 1 skipped. Smoke, full, signal,
scaled/rotated deck, notify and ai passed in both intensities. Live switching,
input retention and surface unmap/remap passed. Every QML log is audited.
Performance results and exact commands: [verification](intensity/verification/RESULTS.md).

No host, service, schema, configuration logic or ai-bridge file was edited.
The available hosts predate Claude's full-screen changes: return was tested by
unmapping/remapping their supported ground/strip visibility settings. Real
Hyprland, game transitions and GPU-memory release remain integration checks.
