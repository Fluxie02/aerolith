# Application formats and placement — UI-012

Primary references checked on 23 October 2026. These are opt-in review
artifacts. Nothing installs or modifies a host profile. The matching shell
directions continue SHEAR's mineral surfaces, phosphor and angled joints;
PIYTI adds ice as the application-continuity cue.

## Firefox

Choose `themes/firefox/thears/` or `themes/firefox/piyti/`. Copy its
`userChrome.css` and optional `userContent.css` into the selected Firefox
profile's `chrome/` directory, preserving or merging existing user rules.
Find the profile through `about:support` or `about:profiles`. Set
`toolkit.legacyUserProfileCustomizations.stylesheets` to `true` in
`about:config`, then restart Firefox. Remove the files or reset the
preference to revert. No `user.js` or preference is installed by this work.
[Mozilla's customization guidance](https://support.mozilla.org/en-US/kb/contributors-guide-firefox-advanced-customization)
documents the preference, profile location and the unsupported stability of
internal UI selectors.

THEARS uses faceted active-tab backgrounds, a phosphor lower registration
and a mineral toolbar. PIYTI uses open, narrow ice rails on the active tab
and address field, with a phosphor task-registration edge. Native toolbar
order, address/permission controls, tab close controls, private-window
indicators and the chosen sidebar visibility remain in Firefox's control.
Focus retains a visible 2 px ring; hover/focus transitions are 110–130 ms
and become immediate with the OS reduced-motion preference. No scripts,
network assets, web-page inversion, continuous animation or extra process
is introduced.

The optional `userContent.css` is restricted to exact `about:home` and
`about:newtab` URLs. It changes the existing search and shortcut surfaces,
without injected links, shell buttons or application-state claims. Website
colours, forms, document canvases and browser security/error pages keep
their own appearance.

Each direction also supplies an independent `manifest.json` static theme
for Firefox 128+. It needs no userChrome preference and defines documented
theme colours plus dark browser chrome with automatic content appearance.
For temporary review, load that manifest through `about:debugging` → This
Firefox → Load Temporary Add-on. Permanent distribution requires Mozilla
signing; a loose manifest is not a permanently installed signed add-on.
CSS provides the shape treatment and can be used without the manifest.
[MDN's static-theme schema](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/theme)
defines its colour roles and signing requirement. Firefox internals can
change between releases; real-app evidence records the actual tested build.

PIYTI's browser-to-shell continuity is a design contract, not a browser
extension implementation. A stylesheet cannot supply tab metadata, MPRIS,
or privileged shell commands. See `SYSTEMS-REQUESTS.md` for Claude's work.

## LibreOffice

`themes/libreoffice/thears.xcu` and `piyti.xcu` register two selectable
`org.openoffice.Office.UI/ColorScheme/ColorSchemes` entries, named
**AEROLITH THEARS** and **AEROLITH PIYTI**. RGB values use decimal integers,
matching the [upstream 25.8 UI configuration schema](https://github.com/LibreOffice/core/blob/libreoffice-25-8/officecfg/registry/schema/org/openoffice/Office/UI.xcs)
and [its component-data example](https://github.com/LibreOffice/core/blob/master/officecfg/registry/data/org/openoffice/Office/UI.xcu).
The schemes cover Writer's workspace and markers, Calc's grid/focus and
formula roles, Draw's grid, HTML syntax, links, spelling/grammar and the
native application palette. Document paper stays white with dark automatic
text, retaining a trustworthy document surface. Neither scheme edits a
document's saved styles, colours or print settings.

The directory is an extension source tree for **LibreOffice 25.8+**:
`description.xml`, `META-INF/manifest.xml` and both `.xcu` files belong at
the root of a ZIP archive named `aerolith-appearance.oxt`. To prepare a
review package without installing it, run from the repository root:

```sh
(cd themes/libreoffice && python3 -m zipfile -c /tmp/aerolith-appearance.oxt description.xml META-INF/manifest.xml thears.xcu piyti.xcu)
```

After owner approval Claude can offer that package through LibreOffice's
Extension Manager. In Tools → Options → LibreOffice → Appearance, select
the desired AEROLITH theme and enable application theming. Keep **Use white
document background** enabled. The extension registers choices and does not
force a current scheme, appearance mode or global toolkit environment.
The 25.8 minimum is deliberate: 25.2 used separate `Light` and `Dark`
properties where these schemes use the current `Color` property.
[LibreOffice's Appearance help](https://help.libreoffice.org/latest/en-US/text/shared/optionen/01012000.html)
documents those controls and theme extensions. The corresponding test
profile values are `/org.openoffice.Office.UI/ColorScheme`
`CurrentColorScheme="AEROLITH THEARS"` or `"AEROLITH PIYTI"`, and
`/org.openoffice.Office.Common/Appearance` `LibreOfficeTheme=1`,
`ApplicationAppearance=2`, `UseOnlyWhiteDocBackground=true`.

When LibreOffice uses its GTK 3 VCL backend, the existing
`themes/gtk-3.0/gtk.css` supplies the companion widget typography, focus and
menu shapes. The `.xcu` controls application-owned colours. Other VCL
backends, icon sets and sandboxed file pickers may retain platform details;
a colour scheme does not switch backend, replace icons or change ribbon
layout. THEARS and PIYTI therefore share native office navigation and keep
their separate shell continuity outside the editing canvas.

## ArtCraft identification and Linux support

The high-confidence match is [ArtCraft's Crafting Apps](https://getartcraft.com/apps):
the official catalogue lists thirteen native Rust creative/office apps,
including PhotoCraft, VectorCraft, FilmCraft, LightCraft, PdfCraft,
EffectCraft and DesignCraft. This is separate from the site's AI-compositor
hero. [PhotoCraft's official page](https://getartcraft.com/apps/photocraft)
advertises Linux x86_64/ARM64 Flatpak, AppImage, Debian, RPM and tarball
downloads; it linked v0.10.0 during this review. The plain x86_64 tarball is
`https://github.com/storytold/photocraft/releases/download/v0.10.0/photocraft-0.10.0-linux-x86_64.tar.gz`.

The release app uses egui/wgpu and built-in themes, so GTK CSS is not a
release theme mechanism. `themes/artcraft/{thears,piyti}/tokens.json` uses
the exact keys accepted by PhotoCraft's `live::apply_overrides`, including
hex colours and numeric radii. **This loader is debug-build-only and
compiled out of release builds.** Its debug watcher requests a repaint at
400 ms; do not enable it as a production background integration.
[Upstream development docs](https://github.com/storytold/photocraft/blob/main/docs/development.md)
and [the actual loader source](https://github.com/storytold/photocraft/blob/main/crates/ui-egui/src/theme.rs)
establish that limitation. No file-loading support is assumed for the other
Crafting Apps.

For a released native app, choose its built-in Pro (Dark) or Studio (Dark)
theme, then apply the compositor fragment from `themes/hyprland/` after
approval. Any release screenshot must label that scope accurately: actual
app and exterior integration, **AEROLITH token recolour not applied**.
For the JSON designs, select **Studio (Dark)** in a PhotoCraft debug build,
then use `PHOTOCRAFT_THEME_FILE=/absolute/path/to/tokens.json`. These tokens
use light `accent_text` on dark rows and an alpha `accent_soft` tint, matching
Studio's semantic roles; the bright primary button has its separate dark
`primary_text`. They are not a Pro-theme override. The loader updates token
consumers after applying built-in egui visuals, so complete native-widget
recolouring is not proven by accepting JSON. Palette, selection and layout
must be judged in that debug build before a production loader is approved.
Deeper creative-suite continuity should use verified, opt-in document/
render events. Artwork pixels, ICC settings and media timing stay with the
creative app; the shell never invents progress or polls its render engine.

## File validation

- Firefox: all four CSS files passed recursive stylesheet, at-rule and
  declaration parsing with **tinycss2 1.5.1** inside the disposable
  `aerolith-ui012-apps` container. Both JSON manifests parse; each theme's
  37 colour names and two property names match Mozilla's actual
  [`ThemeType` schema](https://github.com/mozilla-firefox/firefox/blob/main/toolkit/components/extensions/schemas/theme.json).
- LibreOffice: `xml.etree.ElementTree` parses both `.xcu` files and both
  extension XML files. All 67 colour nodes and each `Color`/`IsVisible`
  property match the 25.8 schema; RGB integers stay in `0..16777215`.
  Native `unopkg add` accepted the corrected extension dependency namespace
  in the throwaway LibreOffice 26.8.1 container. The earlier version claim
  was tightened to 25.8 after checking the actual older schema.
- ArtCraft: both JSON objects parse; every key and value type matches
  PhotoCraft's debug `apply_overrides` implementation. All foregrounds use
  the established palette. Review corrected `accent_text` to light text and
  made `accent_soft` an alpha tint for Studio's selection semantics; the
  pressed fill is darker than the separator so dim text stays above 4.5:1
  there. Neither release loading nor recoloured native rendering is claimed.

The final cross-app syntax run covers **22 payloads: 12 CSS, six JSON and
four XML/XCU files**, with 123 style rules, 451 declarations, 14 at-rules
and no errors. [Numeric colour-pair checks](verification/app-contrast.json)
separate text (4.5:1) from focus/icon cues (3:1), including alpha-composited
Studio selection tints. These are palette checks, not a claim that every
unseen app widget or account state was exercised. Exact parser output is in
[theme-validation.log](verification/theme-validation.log).

Real-app screenshots and exact shell checks are listed in the main README.
