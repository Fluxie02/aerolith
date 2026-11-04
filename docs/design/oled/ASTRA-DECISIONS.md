# Astra decisions — OLED-REVIEW

4 November 2026. One review of the seven requested screenshots and current
tokens/components. Sol/Terra implement; existing PIYTI composition stays.

1. **OLED palette: retain the planes; dim the cyan continuity role too.**
   Keep opaque `background = obsidian = #000000`, surface RGB multiplier
   `0.55`, and existing floor/separation/cap rules. Limb surfaces remain
   `#0f1618` / `#141e20`; grid/separators retain RGB multiplier `0.55`
   (`#202d2e`). Keep decoration opacity `0.55`, applied once to decoration
   only. Keep text/textDim unchanged and semantic accent RGB multiplier
   `0.80`. Add `profile.appLink`: resolved `Theme.appLink` RGB × `0.80`,
   rounded, with the existing foreground contrast repair. Limb cyan becomes
   `#67b8be`; green `signal` remains separate (`#a5bc8a`). Use appLink for
   continuity edges/labels. Require every text-bearing role, including appLink,
   to meet `MIN_TEXT_CONTRAST = 4.5` on its actual composited fill. Current
   12-scheme minimum: `4.993:1`; proposed Limb cyan minimum: `7.422:1`.
   Existing surface separation is sufficient in the captures.

2. **OLED idle: hide persistent content; exempt the glance clock from dimming.**
   Keep `idleDimAfter = 300 s`, `idleDimLevel = 0.65`, and
   `hideDecorationWhenIdle = true`. Apply `0.65` only to decoration; current
   whole-surface dimming makes the clock unnecessarily faint. With hiding on,
   hide Ground's entire presentation: ring, workspace numeral, telemetry,
   labels, hatch/frame, window register, buttons and app bar; retain black
   backing. Hide Strip branding, workspace tape/title, date, routine status
   and separators. Keep time only (12/24-hour preference, no seconds), existing
   size/position, `profile.textDim`, effective opacity `1.0` (`11.006:1` on
   Limb black). Sharing/privacy and caution/critical indicators also stay
   opaque. Deck controls and transient notices/OSD/session foregrounds bypass
   idle dimming. Retained functional text bypasses dimming even with hiding
   off. Reuse existing downward-fade durations; restore immediately on input;
   add no idle loop.

3. **OLED Deck interiors: inherit the destination output's complete profile.**
   Pass its existing profile through all bays/nested visuals, including AI:
   `bg/background`, `surface`, `surface2`, `grid`, `text`, `textDim`, `signal`,
   `caution`, `critical`, `nominal`, `appLink` (decision 1), `decorationOpacity`.
   Map backplates → `surface`, recessed inputs → `bg`, selected/hovered rows →
   `surface2`, borders/separators → `grid`. Functional focus outlines use opaque
   `profile.signal`; decoration alone takes `decorationOpacity`. Keep Theme
   geometry/type/motion. Never dim the entire bay; check text against rendered
   selected/tinted/translucent fills. This removes the standard teal slab in
   `deck-oled-2.png` without flattening its material hierarchy.

4. **Two outputs: show the bottom app bar on the primary output only.**
   Ground `AppContinuity` visibility = `output is primary AND existing visibility
   conditions`, also respecting decision 2. Do not relocate it on focus changes
   or reflow its vacant space. Keep instrumentation/Strip on both outputs,
   focused-output Deck placement and per-output fullscreen release. Removing
   the duplicated launcher row is sufficient; retain the composition. A single
   remaining output receives the bar as primary. Hardware follow-up: verify
   near-black separation, clock readability and input resume at the owner's
   actual 4K scaling. Software captures establish no panel brightness or
   retention-protection claim.
