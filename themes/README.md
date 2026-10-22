# AEROLITH application appearance — UI-008

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
