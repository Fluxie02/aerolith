# COUNTERPHASE / UI-013 systems handoff

## S1 — Fullscreen and game suspension (required, Claude)

The visual seam is implemented in `shell/core/Theme.qml`:

```qml
property bool ambientSuspended: false
readonly property bool ambient: animate && !lowEffects && !ambientSuspended
```

Set `Theme.ambientSuspended = true` **before** suspending a visual surface
on the selected output. Set it false only after the output's fullscreen/game
condition ends and the surfaces can be restored. This is a runtime systems
hook, not a new config key. Motion off and lowEffects already close the same
gate; reduced keeps only 3 logical pixels of carrier stroke and .07 opacity
variation. Actual windows determine carrier direction; the app direction
determines its ink. Neither represents a CPU, network or audio sample.

The gate stops the carrier timer and all ambient Animator jobs. Background
workspace/focus/app-continuity transitions and startup ignition also respect
it. Local exposure guards stop work on hidden windows; Ground rests while
the Deck is requested. Stopped marks return to their registered coordinates.

**The gate alone does not release VRAM.** Please provide an event-driven,
selected-output fullscreen/game state in the systems layer and use it to
unmap AND release visual content/scene graphs in Ground, Strip, Deck and
Notices, preserving services, commands, shortcuts and their demand lifetimes.
Opening an explicit shell bay needs a defined wake/suspension policy. Do not
infer this state from our idle visual timer or a stale Navigator snapshot.
GroundSurface currently keeps Ground loaded whenever ground is enabled;
that is insufficient for the owner's near-zero game VRAM requirement.

Restore from CPU-side geometry and configuration. Cached Canvas images are
repainted on remap/size/theme changes, and native Item geometry reconstructs
without depending on previous GPU resources. Do not replay boot ignition on
restore. Validate repeated enter/leave, output removal, active notice and
Deck exit while suspending, plus real GPU VRAM before/during/after a game.
This software-rendered Sway/Hyprland-mock environment cannot validate VRAM.

## S2 — Existing app-direction setting seam (inherited)

`Theme.applicationDirection` remains `thears` by default; `piyti` selects
the application instrument and its existing five app adapters. Neither the
schema nor the adapters changed in this round. A supported persistent choice
still belongs to Claude, as recorded in UI-012. Verification changes the
default only in a disposable shell copy to exercise PIYTI.

## S3 — Portrait headless Deck input observation

The required scaled/rotated mock Deck test passes with the harness's normal
1920×1080 physical Sway output. With a matching 1440×2560 / scale 1.5 Sway
output, the same test lost `vol 33` after reopening Command during exit, twice.
No QML runtime error was logged. Logs and both outcomes are retained in
`verification/`; this is an additional harness/host focus observation, not a
reason to change visual key handlers. Please reproduce and inspect the host
focus/remap sequence before treating portrait hardware as verified.
