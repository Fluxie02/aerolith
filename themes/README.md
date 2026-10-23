# AEROLITH application appearance — UI-008 / UI-010 / UI-012

Optional, uninstalled theme fragments for owner review. Claude will integrate
these with the installer after approval. They share Limb's palette and work
with both Saturated and Insane; intensity changes shell instrumentation, not
application colours. The shell does not rewrite application configuration.

| Application | Fragment | Integration point for Claude |
| --- | --- | --- |
| kitty | `kitty/aerolith.conf` | `include /absolute/path/to/aerolith.conf` in the existing kitty config |
| Alacritty | `alacritty/aerolith.toml` | Add the absolute file path to `[general].import` in the existing config |
| foot 1.26+ | `foot/aerolith.ini` | `include=/absolute/path/to/aerolith.ini` in the main section, or run `foot --config /absolute/path/to/aerolith.ini` for a temporary preview |
| btop | `btop/aerolith.theme` | Theme search directory, then select AEROLITH in btop's theme chooser |
| Hyprland 0.55+ Lua | `hyprland/aerolith.lua` | `dofile("/absolute/path/to/aerolith.lua")` in the existing Lua config |
| Hyprland hyprlang | `hyprland/aerolith.conf` | `source = /absolute/path/to/aerolith.conf` in the existing config |

Use the Hyprland fragment matching the user's existing configuration language.
Both were checked with the dev image's real `Hyprland --verify-config` parser.
They change only decoration and spacing: 20 px circular corners, 2 px borders,
6 px inner / 14 px outer gaps, phosphor focused and engraved inactive borders,
opaque windows, no blur or shadows. They leave bindings, monitors, layout and
animation policy alone. Real GPU/Hyprland rendering remains unverified.

Terminals use JetBrains Mono at 12 pt, 14 px inner padding, opaque obsidian,
light text, and dark text on phosphor selection. Fonts are optional system
families, not bundled; the terminal's font fallback applies if unavailable.
The shell's Inter family remains for interface labels. btop inherits the font
of its terminal. For rounded btop boxes Claude can set its separate
`rounded_corners = true` preference; shape is not a btop `.theme` property.
Native terminal-window rounding is provided by the compositor, not terminal
colour files. There is no blur dependency or startup command in any fragment.

All 16 ANSI foreground colours pass 4.5:1 against obsidian, including black
and bright black as readable mineral greys. Error, caution, success and
information remain distinct red, amber, green and cyan/blue semantic hues.
Selection is 14.45:1. Exact ratios are in
`../docs/design/settings/verification/theme-contrast.json`. The rounded shell
keeps the established palette roles and their existing contrast tests.

Validation: foot 1.28 `--check-config` and actual headless Wayland launch;
Alacritty TOML parsed with Python `tomllib`; kitty options cross-checked
against the upstream reference; btop keys checked against its upstream theme and theme parser source.
Only foot and Hyprland have been exercised with their native parsers here.
Do not claim kitty, Alacritty or btop rendering has been tested.

Upstream format references checked on 22 October 2026:

- [kitty configuration](https://sw.kovidgoyal.net/kitty/conf/)
- [Alacritty configuration](https://alacritty.org/config-alacritty.html)
- [foot example configuration](https://codeberg.org/dnkl/foot/src/branch/master/foot.ini) (the exact packaged example at `/etc/xdg/foot/foot.ini` was used when the site denied automated access)
- [btop theme format](https://github.com/aristocratos/btop/blob/main/themes/nord.theme)
- [Hyprland Lua example](https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua)
- [Hyprland decoration options](https://wiki.hypr.land/Configuring/Basics/Variables/)

## GTK 3 — system monitors, audio/network settings, file dialogs

For Claude's later integration, merge an `@import url("/absolute/path/to/themes/gtk-3.0/gtk.css");`
at the end of the existing `$XDG_CONFIG_HOME/gtk-3.0/gtk.css` (normally
`~/.config/gtk-3.0/gtk.css`). Keep the user's existing CSS and make the import
removable. The fragment sits above stock Adwaita; it is not a named GTK theme.
GTK 3.24 is the target. Choose Adwaita's dark variant in GTK settings when
integrating, so untouched native widgets also start dark. Inter labels inherit
the user's font size; `.monospace` content uses JetBrains Mono with fallbacks.

This covers GTK versions of apps such as pavucontrol, nm-connection-editor and
system monitors, plus GTK file pickers, menus and dialogs. Actual coverage
depends on the toolkit each installed version uses. It does not restyle web
content or applications that paint their own controls. Rounded CSD windows use
20 px corners, controls and popovers 10 px; maximized/tiled edges stay square.
Server-decorated window clipping comes from the existing Hyprland fragment.

## GTK 4 / libadwaita — modern settings and portal dialogs

Merge `@import url("/absolute/path/to/themes/gtk-4.0/gtk.css");` into the end
of `$XDG_CONFIG_HOME/gtk-4.0/gtk.css`. Keep Adwaita/libadwaita as the underlying
stylesheet. The fragment provides named window/view/headerbar/sidebar,
accent and semantic colours, then narrow shape, selection and keyboard-focus
overrides. Current libadwaita still maps these named colours into its CSS
variable defaults; no GTK 4.16-only variable syntax is required in this file.
Prefer dark appearance through the desktop/portal setting at integration time;
do not force a global `GTK_THEME` environment variable for libadwaita apps.

User CSS can override accessibility themes. Keep this opt-in, and omit these
imports when the user chooses high contrast. Apps with their own CSS or
per-widget colour variables may retain individual app colours. Sandboxed apps
and portal file pickers are separate processes: they need access to the import
target and the corresponding GTK config; host CSS alone does not guarantee
Flatpak/portal coverage. Claude should verify those paths during integration.

## Qt 5 / Qt 6 — Widgets settings, monitors and file dialogs

Place `qt/aerolith.conf` in **both** `$XDG_CONFIG_HOME/qt5ct/colors/` and
`$XDG_CONFIG_HOME/qt6ct/colors/` as `aerolith.conf` for installed Qt versions.
In qt5ct/qt6ct, choose **Fusion**, enable a custom palette and select AEROLITH.
The same file supplies every QPalette role for active, inactive and disabled
states, including opaque placeholder text and Qt 6.6+ Accent. Qt 5 ignores the
extra Accent role. This is the matching stock-Qt palette; Kvantum is unnecessary.

Set the general font to Inter at the user's normal interface size, and the
fixed font to JetBrains Mono (Noto Sans / Noto Sans Mono if unavailable).
For rounded Widgets controls, place `qt/aerolith.qss` in each manager's `qss/`
directory and enable it under **Style Sheets**. It adds 10 px corners and
2 px focus borders to buttons and entries while using palette colours.
Compound spin/combo controls, views, indicators and scrollbars stay with Fusion.
The colour scheme alone cannot set fonts or corner radii. Hyprland supplies
the 20 px outer window rounding, including server-side titlebars.

The qt5ct/qt6ct platform-theme plugins must be selected for their corresponding
Qt runtime (per-app `QT_QPA_PLATFORMTHEME=qt5ct` or `qt6ct`); a single global
value is not a portable way to configure mixed Qt 5/6 installations. Leave that
session wiring to Claude. Applications using a KDE platform theme, a private
palette, custom Qt Quick controls or a sandbox may bypass qt*ct preferences.

## Graphical-app validation

Text and selection pairs meet 4.5:1; opaque 2 px keyboard-focus indicators
meet 3:1 against adjacent fills. Filled GTK accent/error controls use a dark
inset ring. Inactive selection keeps the same contrast. Disabled rendering may
still be dimmed by the toolkit; it is not covered by the enabled-text claim.
Exact commands, ratios, app availability and preview limitations are recorded
in [`docs/design/apps/README.md`](../docs/design/apps/README.md).
No package or user/session configuration is installed by these files.

Format references checked for UI-010 on 23 October 2026:

- [GTK 3 CSS properties](https://docs.gtk.org/gtk3/css-properties.html)
- [GTK 4 CSS nodes and selectors](https://docs.gtk.org/gtk4/css-overview.html)
- [libadwaita colour roles](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html)
- [libadwaita named-colour compatibility mapping](https://github.com/GNOME/libadwaita/blob/main/src/stylesheet/_colors.scss)
- [qt6ct palette reader](https://github.com/trialuser02/qt6ct/blob/master/src/qt6ct-common/qt6ct.cpp)
- [Qt QPalette roles](https://doc.qt.io/qt-6/qpalette.html)

## THEARS and PIYTI — UI-012

**THEARS — The Harmonized Exterior: Apps Resonate with SHEAR; visual integration makes familiar apps feel native to the same mineral airframe.**

**PIYTI — Place Into Your Task Instrument; deeper integration carries known app windows into a shared shell bus, with richer task adapters specified for Claude.**

Choose one direction per app. Both build on SHEAR/Limb and work with either
Saturated or Insane shell intensity. THEARS uses the existing phosphor focus;
PIYTI adds ice `#81e6ed` as the application-link cue. Fonts fall back to system
sans/mono. App content, native layouts, document colours and security indicators
stay under the app's control. These are uninstalled, opt-in review files.
Claude will wire installation after owner approval.

The shell's direction is currently a visual seam in `Theme.applicationDirection`,
defaulting to THEARS. PIYTI captures use the same production components with
that default changed in a disposable copy. A supported user setting, reliable
app events and full-screen GPU-resource suspension are explicit
[systems requests](../docs/design/thears-piyti/SYSTEMS-REQUESTS.md).
Shell motion preferences and each app's reduced-motion preference are separate;
the added app CSS respects `prefers-reduced-motion`.

### Firefox

Use `firefox/thears/` or `firefox/piyti/`. Merge `userChrome.css` and optional
`userContent.css` into `<Firefox profile>/chrome/` (find that profile in
`about:profiles`). Set `toolkit.legacyUserProfileCustomizations.stylesheets=true`
in `about:config`, then restart Firefox. Keep any existing customization and
make removal reversible. The content file only styles `about:home` and
`about:newtab`; it does not recolour websites or permission/error pages.

Each directory also contains an independent static-theme `manifest.json` for
Firefox 128+. It supplies native colour roles without the stylesheet preference.
Temporary review: `about:debugging` → This Firefox → Load Temporary Add-on →
select the manifest. Permanent distribution needs Mozilla signing. The CSS
adds the SHEAR shape treatment; the manifest alone adds colours. No mod or
shell bridge is required. Internal chrome selectors can change across Firefox
updates. [Format sources and placement](../docs/design/thears-piyti/APP-FORMATS.md#firefox).

### LibreOffice suite

`libreoffice/thears.xcu` and `libreoffice/piyti.xcu` register selectable
**AEROLITH THEARS** and **AEROLITH PIYTI** application colour schemes for
LibreOffice **25.8+**. The directory is an extension source: package both XCU
files, `description.xml` and `META-INF/manifest.xml` at the root of an `.oxt`
ZIP, then offer it through Extension Manager after approval. Do not replace
`registrymodifications.xcu` with these fragments. In Tools → Options →
LibreOffice → Appearance choose the desired scheme and enable application
theming. Keep **Use white document background** enabled. No mod is needed.

With the GTK 3 VCL backend, the existing `gtk-3.0/gtk.css` is the companion
widget theme; the XCU supplies application-owned colours for Writer, Calc,
Draw and the shared suite. It does not change the active backend, icons,
document styles, printed output or ribbon arrangement. Other backends and
sandboxed dialogs can differ. [Package command, native-test profile values
and schema references](../docs/design/thears-piyti/APP-FORMATS.md#libreoffice).

### Steam — requires Millennium

Copy the **whole** `steam/thears/` or `steam/piyti/` directory into the installed
Millennium version's active themes folder, then select **AEROLITH THEARS** or
**AEROLITH PIYTI** in Steam → Millennium → Themes. The documented Linux quick
start uses `~/.steam/steam/steamui/skins/`; newer installations may keep themes
under `~/.local/share/millennium/`. Resolve the installed version's path before
writing files. Do not put these CSS files directly into Steam's base UI tree.

Each folder contains Millennium's `skin.json` with `UseDefaultPatches: true`,
plus its three standard targets: `libraryroot.custom.css`, `friends.custom.css`
and `bigpicture.custom.css`. No JavaScript plugin, remote asset, account access
or store-page injection is needed. Native game artwork and controller layout
remain visible. Syntax/format validation passed; signed-in rendering remains
unverified. [Official format and path references](../docs/design/thears-piyti/MOD-FORMATS.md#steam--millennium).

### Discord — requires Vencord

Copy **one** of `discord/thears.theme.css` or `discord/piyti.theme.css` into
Vencord's local themes directory, opened through Settings → Vencord → Themes
→ Local Themes → Open Themes Folder. Enable that theme and choose Discord's
**Dark** appearance. The standalone CSS includes Vencord's name/author/version/
description metadata header; it needs no additional Vencord plugin or remote
import. Discord's role, presence and mention colours retain their meaning.

These files cover legacy and Visual Refresh colour variables with limited
chrome selectors. Discord can change those internal names. No account session
was used, so live rendering and selector coverage remain unverified. CSS does
not provide call state, unread data or shell commands.
[Format references and limits](../docs/design/thears-piyti/MOD-FORMATS.md#discord--vencord).

### ArtCraft / Crafting Apps

The identified suite is [ArtCraft's thirteen Crafting Apps](https://getartcraft.com/apps),
including the Linux-native [PhotoCraft](https://getartcraft.com/apps/photocraft).
It is distinct from ArtCraft's AI compositor. `artcraft/thears/tokens.json`
and `artcraft/piyti/tokens.json` are exact-key **PhotoCraft debug-build** palette
adapters. For debug review, select **Studio (Dark)**, then load with
`PHOTOCRAFT_THEME_FILE=/absolute/path/to/tokens.json`.
That upstream debug loader polls and is compiled out of release builds; it is
not a production idle-power integration or a universal suite theme format.

For a released app, choose its built-in Pro/Studio dark appearance. The
Hyprland fragments below cover the confirmed PhotoCraft window identity
`ai.storyteller.photocraft`. GTK CSS does not recolour its egui/wgpu interface.
The actual PhotoCraft screenshot shows its release UI and CPU-renderer fallback,
**without AEROLITH token recolouring**. Artwork, ICC and export pixels stay
with the app. No mod is required; deeper creative-task events need Claude's
approved adapter. [Adapter instructions and primary sources](artcraft/README.md).

### Hyprland — per-app rules

Alongside the existing `hyprland/aerolith.lua` or `.conf` base decoration
fragment, include **one** app-rule direction matching the user's config syntax:

| Direction | Hyprland 0.55+ Lua | Hyprland 0.54 hyprlang |
| --- | --- | --- |
| THEARS | `dofile("/absolute/path/to/themes/hyprland/thears.lua")` | `source = /absolute/path/to/themes/hyprland/thears.conf` |
| PIYTI | `dofile("/absolute/path/to/themes/hyprland/piyti.lua")` | `source = /absolute/path/to/themes/hyprland/piyti.conf` |

These add 20 px rounding, 2 px focused/inactive borders, no blur/shadow,
modal-dialog placement, Steam Friends/Settings windows, Discord popouts and
Firefox Picture-in-Picture rules. Full-screen/maximized windows are excluded;
Steam game classes are not decorated as the Steam client. Localized auxiliary
titles may need adjustment; check actual app identities with `hyprctl clients`.
All four fragments pass native `Hyprland --verify-config` on 0.56.2. Real
Hyprland rendering and GPU-memory release remain unverified. These rules do
not implement shell suspension. [Matching rules and format sources](../docs/design/thears-piyti/MOD-FORMATS.md#hyprland-app-rules).

The [design and evidence](../docs/design/thears-piyti/README.md) distinguish
actual apps, shell renders with compositor fixtures, and untested account apps.
No host application or profile was installed or changed for UI-012.
