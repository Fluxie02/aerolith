# AEROLITH application appearance — UI-008 / UI-010

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
