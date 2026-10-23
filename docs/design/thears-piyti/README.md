# UI-012 · THEARS / PIYTI

**THEARS — The Harmonized Exterior: Apps Resonate with SHEAR; familiar apps acquire the airframe's material, focus and geometry.**

**PIYTI — Place Into Your Task Instrument; app windows become a shell instrument, with ice rails joining their native surfaces to the workspace.**

Both extend Limb and SHEAR. Saturated retains three structural fins; Insane
exposes five and the denser annular instrument. Direction and intensity are
independent. THEARS makes the desktop a coherent place to work. PIYTI gives
that place an application bus: Browse, Compose, Play, Connect and Create.
Its focused socket latches along an ice datum when application focus changes,
and the bay's faceted housing carries the same registration colour.
The native apps keep their familiar working layouts and artwork.

The production default is THEARS. Both compositions are implemented in shared
production `shell/` components; PIYTI review builds change only the default of
`Theme.applicationDirection` in a disposable shell copy. A supported Settings
choice belongs to Claude's approved systems work. No installer is wired here.

| App | THEARS | PIYTI | Delivered files |
| --- | --- | --- | --- |
| Firefox | Mineral toolbar, faceted tabs, phosphor focus | Exposed ice tab/address/sidebar rails with phosphor registration | Two `userChrome.css` / `userContent.css` pairs and independent static-theme manifests |
| LibreOffice | Dark native application planes around white paper | Ice selection/field/navigation cues; dark editing workspace | Two selectable XCU schemes and an OXT source package for 25.8+; companion existing GTK 3 theme |
| Steam | Rounded mineral client and Friends chrome | Library/title/launch registration seam; controller focus in Big Picture | Two complete Millennium themes, each with its manifest and three native patch targets |
| Discord | Phosphor focus and shared mineral surfaces | Communication-bay edges on sidebar, header and composer | Two standalone Vencord theme files with metadata |
| ArtCraft | Phosphor creative-suite token adapter | Ice edges and tighter creative-tool radii | Two exact-key PhotoCraft **debug-only** token adapters; released-app compositor rules |
| Hyprland | Phosphor active border and rounded app exteriors | Ice active border and matching app exteriors | Two directions in both Lua and hyprlang, including modals, popouts and Picture-in-Picture |

| Shell evidence | Saturated | Insane |
| --- | --- | --- |
| THEARS | [Desktop](thears/saturated/00-settled.png) · [Command](thears/saturated/03-dock-settled.png) | [Desktop](thears/insane/00-settled.png) · [Navigator](thears/insane/05-window-bay-settled.png) |
| PIYTI | [Desktop](piyti/saturated/00-settled.png) · [App focus](piyti/saturated/02-creative-handoff-settled.png) | [Desktop](piyti/insane/00-settled.png) · [App focus](piyti/insane/02-creative-handoff-settled.png) |

Watch the actual [PIYTI app handoff](piyti/insane/motion/02-creative-handoff/motion.webp),
[bay docking](piyti/insane/motion/03-dock/motion.webp) and
[release](piyti/insane/motion/06-release/motion.webp). Each gesture has six
full-resolution PNGs, an 18-frame animation, a contact sheet and timing data.
[720p / Noto / 1.25 scale / off + lowEffects](accessibility/piyti/insane/off/01-idle.png)
shows the compact layout. These are actual shell renders with compositor-event
fixtures; none is a real Steam or Discord window.

Exact files, destinations, required mods and reversal guidance are in
[themes/README.md](../../../themes/README.md). [Application format research](APP-FORMATS.md)
and [Millennium/Vencord/Hyprland research](MOD-FORMATS.md) link the primary sources.
All assets live under `themes/<app>/`; no host application or user profile was changed.

ArtCraft is identified with high confidence as the official
[Crafting Apps suite](https://getartcraft.com/apps), including Linux-native
[PhotoCraft](https://getartcraft.com/apps/photocraft). Released PhotoCraft
cannot load the debug token files. Its real screenshot shows its native dark
appearance and CPU-renderer fallback, **without AEROLITH token recolouring**.
GTK does not recolour its egui/wgpu chrome. This limitation is part of the
integration design rather than a guessed theme-install path.

PIYTI currently reads existing compositor snapshots, labels them **known
windows**, and opens Navigator for linked apps or Command search for the rest.
Navigator owns refresh. Counts do not mean tabs, documents, calls or jobs.
No browser extension, game launcher, call control or creative-job monitor is
invented. Those richer integrations have precise inputs, outputs, failure cases
and acceptance checks in [SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md).

Startup assembly, SHEAR strain, workspace articulation, docking and release
remain bounded to their triggering events. The new socket latch settles once
per app-focus change. Reduced motion removes travel; off and lowEffects stop
animation. No timers, shaders, blur, thumbnails, webviews or extra service demand
were added. The design requires full-screen/game suspension to release GPU
allocations near zero; the inherited hosts do not implement that feature yet.
Claude's S1 lifecycle request is required before either direction ships.
Headless CPU results cannot establish GPU-memory release.

Real application captures are [documented separately](real-apps/README.md):
Firefox 158.0.1, LibreOffice 26.8.1 and PhotoCraft 0.10.0, all run inside a
throwaway `docker run --rm` container based on the unchanged `aerolith-dev` image.
Fixture web/document content is visibly labelled. Sway manages those real app
windows; the shell's Hyprland protocol fixture is separate. Steam and Discord
were not logged into or rendered. Shell event captures are actual QML renders
with simulated compositor events, and are labelled as such.

**Biggest weakness found and fixed:** at 1280×720 with 1.25 UI scale, the new
application bus covered the desktop shortcuts and the focused-window title.
The compact layout now uses a single-line identity, a smaller workspace numeral
and a higher shortcut block, leaving the bus and the existing controls readable.
The same review tightened snapshot wording, added socket focus outlines and
Enter/Space activation, and preserved Discord unread styling.

Node **104/104**, Qt V4 **104/104**, Python **71 passed / 1 skipped**.
All **16** required final smoke/full/Deck/AI runs pass across both directions and
intensities; the four motion and eight compact checks also pass. All 34 final
Quickshell logs have no runtime QML errors or crashes. The 22 CSS/JSON/XML payloads and all four native Hyprland configs
pass validation; 346 checked text/selection/focus pairs meet their thresholds.
Frozen 120-second idle measurements are **0.10–0.11% of one core**; idle after
use is **0.10–0.13%**, against SHEAR's recorded 0.14% baseline. Initial RSS is
about 125 MiB. Software-renderer measurements establish CPU cost, not VRAM.

[Verification results](verification/RESULTS.md) record exact commands, retries,
source hashes, performance and the QML-log audit. [One review of Claude's
systems work](CLAUDE-REVIEW.md) found the inherited full-screen release gap;
no protected host, service, config/schema or AI API was changed. Git remained
read-only during this work; Claude handles the final commit and systems review.
