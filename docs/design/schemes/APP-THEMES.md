# Generated application schemes — UI-015

`shell/lib/schemes.mjs` is the colour source for both the live shell and the
application exports. `tools/gen-scheme-themes.mjs` reads the established app
files in `themes/` as shape/format templates, resolves semantic colour roles,
and writes `themes/schemes/<id>/`. Do not edit generated files by hand.

```sh
node tools/gen-scheme-themes.mjs
node tools/gen-scheme-themes.mjs --check
```

Both commands check contrast before writing or comparing output. `--check`
reports missing, changed and unexpected files, exits nonzero on divergence,
and never writes. Generation is deterministic, without timestamps or remote
dependencies. Unknown files are reported for review rather than deleted.

The twelve schemes produce **446 files**: 36 app templates and one derived
palette per scheme, plus the catalog and contrast evidence. Each directory
mirrors the existing paths, so the [placement instructions](../../../themes/README.md)
apply with `themes/schemes/<id>/` as the root. These exports work with Saturated
and Insane. PIYTI/THEARS shape variants remain separate where they already
exist; shared native-toolkit and terminal files serve both.

| App | Generated path inside each scheme | Scope |
| --- | --- | --- |
| kitty | `kitty/aerolith.conf` | Opaque colours, ANSI roles, selection, cursor and tabs |
| Alacritty | `alacritty/aerolith.toml` | Native TOML palette, font and padding |
| foot | `foot/aerolith.ini` | Existing 1.26+ dark-colour format |
| btop | `btop/aerolith.theme` | Existing semantic theme keys |
| GTK 3 / GTK 4 | `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css` | Native widget overrides and readable selected rows |
| Qt | `qt/aerolith.conf`, `qt/aerolith.qss` | 22-role active/inactive/disabled palette and existing Fusion shapes |
| Hyprland | `hyprland/{aerolith,piyti,thears}.{conf,lua}` | Appearance only, both existing syntax forms |
| Firefox | `firefox/{piyti,thears}/` | Static-theme manifest, browser chrome and exact start-page URLs |
| Discord | `discord/{piyti,thears}.theme.css` | Local Vencord theme, native roles/presence retained |
| Steam | `steam/{piyti,thears}/` | Local Millennium theme and its three standard CSS targets |
| LibreOffice | `libreoffice/` | Named schemes for application chrome; existing document colours retained |
| PhotoCraft | `artcraft/{piyti,thears}/tokens.json` | Existing debug-build Studio adapters only |

Generated manifests and selectable app themes have unique names and IDs for
every scheme/direction. Firefox keeps automatic website colour appearance.
Steam retains native game artwork/controller layout, Discord retains role and
presence colours, and LibreOffice retains white paper and its established
document/editor marking colours. The PhotoCraft adapter is compiled out of
release builds; it is not a production live-theme mechanism.

No application file is installed or loaded by this task. Live shell selection
is immediate; choosing and reloading external app payloads requires the narrow
[systems integration](SYSTEMS-REQUESTS.md). CSS-only exports cannot control app
lifecycle, authentication, browser profile preferences or global motion settings.

## Colour derivation and contrast

Interaction uses `signal`; PIYTI's application-continuity rails use the scheme's
`link`. Warning, error and success keep amber, red and green semantics. ANSI
red/green/yellow follow those stable status roles; blue/magenta/cyan retain
their conventional hues, deriving lightness and saturation from `link`. All 16
terminal foregrounds remain readable, including black/bright black.

Decorative `grid` is not treated as a text surface. The generator derives a
bounded `pressed` fill between `surface2` and `grid`, stopping before secondary
or semantic status/link text can fall below 4.5:1. GTK hover, Qt's QSS hover role, Firefox's active button
fill and Discord's highest surface use that readable fill. This fixes the main
app-theme weakness found during review: direct grid hover fills could weaken
secondary-label contrast, especially in the warmer/brighter palettes. Final
numeric review also found critical text on the earlier derived Lichen/Helios
pressed fills at 4.4259:1 and 4.3306:1. Bounding against every semantic role
darkens only those two fills, to `#3f4831` and `#394753`, restoring 4.5632:1 and
4.5268:1. This protects native status text left under app control as well as
the explicitly styled normal labels.

[`themes/schemes/contrast.json`](../../../themes/schemes/contrast.json) records
**780 pairs**: normal/secondary text and semantic colours on five surfaces,
dark selection ink on all bright fills, focus pairs, all
terminal ANSI foregrounds and composited 14% Studio selection tints. All pass;
the minimum tested text/selection ratio is **4.527:1**, above the 4.5:1 gate.
Focus is checked against 3:1. These are measured palette pairs, not a claim
that every third-party widget/state has been rendered.

## Verification

[`app-themes-validation.log`](app-themes-validation.log) records the commands
and results. The reusable [format validator](verify-app-themes.py) uses Python
stdlib plus `tinycss2`/`cssselect2` installed in a temporary directory:

```sh
python3 -m pip install --target /tmp/aerolith-ui015-css tinycss2 cssselect2
PYTHONPATH=/tmp/aerolith-ui015-css python3 docs/design/schemes/verify-app-themes.py
```

All **168 CSS files / 6,612 declarations** parse, and all **1,476 web selector
rules** compile. GTK-only pseudo-classes are left to GTK rather than passed to
the web selector compiler. Also validated: 86 JSON, 48 XML/XCU, 12 Alacritty TOML,
12 Qt palettes, 12 kitty ANSI tables and 12 btop key sets. Native parsers in
`aerolith-dev` accept all **72 Hyprland fragments** and **12 foot configs**.
`--check` verifies all 446 generated files and repeats all contrast checks.

The formats and selectors are inherited from the prior app-theme work; the
[native-format sources](../thears-piyti/APP-FORMATS.md) and
[Steam/Discord/Hyprland primary references](../thears-piyti/MOD-FORMATS.md)
remain applicable. No new format, remote import, privileged app bridge,
continuous animation or polling loop is introduced. Native kitty, Alacritty,
btop and GTK rendering, signed-in Steam/Discord states and a real Hyprland
session were not exercised here. Existing application update caveats remain.
