# UI-008 — integrated Limb

The rounded visual pass and application themes are saved. The tested Settings
bay is ready as [SettingsBay.patch](SettingsBay.patch), but applying it to the
production source is pending release of Claude's SHELL-008 lock. The rest of
the visual source changes are in place. See [verification](verification/RESULTS.md).

Limb's circular instrument, command chord and workspace arc remain. Outer
planes now have 20 px corners; controls use a shared, scaled 10 px radius.
Panel titles and navigation labels use the interface sans font. Saturated
keeps the established information density; Insane retains its richer engraving
and instrument readouts. Both use the same shapes, controls and palette.

The Deck rail follows a shallow continuous arc, aligned with the command
chord. Full bay names and explicit Ctrl+number / F1 labels replace abbreviations
and caret notation. A single rounded selection registration moves between
stations; the selected name and shape, hover feedback and larger pointer
areas make state and availability clear. Its order is unchanged, including
Help before Settings; AI remains conditional on the installed module.
Command Core scopes share this component with their existing Tab/Shift+Tab
and click behavior. The Flight Strip workspace selector and Ground workspace
arc use the same soft focus ring. Navigator sectors retain their shallow arc.
Other horizontal rows were checked: Settings choices are value controls,
Systems readouts are measurements, and session confirmation choices are
buttons. Their roles and existing keyboard behavior remain distinct.

Full motion retargets the selection registration over Theme.normal with
OutCubic easing. Reduced motion changes its position immediately and keeps
only colour feedback; off/lowEffects are immediate. There is no idle animation,
new sampling, shader, blur or persistent GPU state.

The Settings register still generates every supported row and section from
the schema. It shows ON/OFF switches, all enum choices, numbers with their
range and step controls, and text fields. A wide-screen inspector explains
the selected setting; compact layouts wrap the selected description in its
row. Pointer controls call the existing change/apply functions. Amber marks
an uncommitted text draft; a wrapping feedback strip shows READY, SAVED or
REFUSED above fixed keyboard hints. All free text, descriptions and messages
remain plain text. Help documents Ctrl+7 and the bay's keys.

The traversal, value lookup, stepping, commit, movement and key blocks are
unchanged. One presentation binding (`enabled: bay.editing`) disables the
hidden editor outside its visible draft state, resolving the reproduced
focus-retention defect without changing any protected function or key handler.

The same rounding reaches shared Bezels, command results, audio devices and
streams, routine rows, AI prompt/proposal presentation, notices, password and
session controls, and OSD. Hosts, services, configuration logic and schema
are unchanged. No commit was made.

## Before and after

| Intensity | Original tabs | Rounded integrated tabs | Settings | Real themed foot |
| --- | --- | --- | --- | --- |
| Saturated | [Before](tabs/before/saturated/01-command-all.png) | [After](tabs/after/saturated/01-command-all.png) | [Settings](saturated/01-register.png) | [foot + shell](tabs/after/saturated/08-terminal-with-shell.png) |
| Insane | [Before](tabs/before/insane/01-command-all.png) | [After](tabs/after/insane/01-command-all.png) | [Settings](insane/01-register.png) | [foot + shell](tabs/after/insane/08-terminal-with-shell.png) |

[Pointer evidence](pointer/), [motion frames](motion/), [1280×720 at 1.25 scale](compact/),
[lock/session/OSD previews](views/), and [all production bays](surfaces/).
`captures.json` gives a SHA-256 manifest of every PNG.

## Application themes

[themes/README.md](../../../themes/README.md) documents all six **uninstalled**
fragments: kitty, Alacritty, foot, btop, and Hyprland Lua/hyprlang. They share
Limb's palette, opaque backgrounds, JetBrains Mono, readable semantic ANSI
colours and phosphor selection. All 16 ANSI foregrounds pass 4.5:1 against
obsidian; selection is 14.45:1. Native foot and Hyprland parsers pass.
Hyprland decoration uses matching 20 px rounding, focus/inactive borders and
gaps without blur. Claude integrates these only after owner approval.

Foot captures are actual Wayland windows beside Ground and the Flight Strip.
The harness uses sway, whose rectangular window decoration is visible there;
the Hyprland rounding fragment was parsed but needs a real GPU session for
visual verification. The Deck intentionally covers application windows while
open, so the real terminal capture shows the idle shell, not a fabricated
terminal layered over the Settings bay.
