# ArtCraft / THEARS and PIYTI

The owner's creative suite is identified as [ArtCraft's Crafting Apps](https://getartcraft.com/apps),
including PhotoCraft, VectorCraft, FilmCraft, LightCraft and the other Rust
creative and office apps. [PhotoCraft has native Linux downloads](https://getartcraft.com/apps/photocraft).
This is distinct from the main ArtCraft AI image/video compositor, whose
landing page advertises macOS, Windows and web.

`thears/tokens.json` and `piyti/tokens.json` are **PhotoCraft debug-build token
overrides**, checked against the upstream `live::apply_overrides` accepted keys.
They are not release-build themes, GTK CSS, or a universal ArtCraft format.
For a debug build only, choose **Studio (Dark)** and launch with
`PHOTOCRAFT_THEME_FILE` pointing to the chosen absolute file path. The selection
uses light text over a translucent accent tint; primary buttons keep dark text
on phosphor. Native debug rendering still needs review: token consumers can
coexist with widgets whose colours are separately hardcoded upstream.
Upstream's debug watcher polls at 400 ms; this
development workflow is unsuitable for a production idle-power target.

Released PhotoCraft currently compiles that loader out. Choose its built-in
**Pro (Dark)** or **Studio (Dark)** appearance for normal use; the matching
Hyprland fragments provide exterior focus/rounding integration. GTK CSS does
not recolour its egui/wgpu chrome. Do not copy these JSON files into a guessed
configuration directory and claim they have loaded. No app build or host
configuration is changed here.

THEARS uses phosphor selection and broader mineral panels. PIYTI exposes ice
field edges, compact radii and phosphor primary actions. Both keep artwork,
colour-management and export pixels out of scope; neither draws fake task
or render progress. The shell's deeper creative-task continuity requires the
approved event adapter in `docs/design/thears-piyti/SYSTEMS-REQUESTS.md`.

Upstream references checked 23 October 2026:

- [PhotoCraft development and debug theme loader](https://github.com/storytold/photocraft/blob/main/docs/development.md)
- [Exact token fields and accepted overrides](https://github.com/storytold/photocraft/blob/main/crates/ui-egui/src/theme.rs)
- [Native appearance choices and portal behaviour](https://github.com/storytold/photocraft/blob/main/docs/ui-design.md)
