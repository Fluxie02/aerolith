# App mod formats and validation

Checked 23 October 2026. These files are opt-in payloads for a later installer.
Nothing here was installed on the host. Steam and Discord were not launched,
signed in, or represented as real-app screenshots.

## Steam / Millennium

`themes/steam/thears/` and `themes/steam/piyti/` are separate, self-contained
Millennium themes. Each contains `skin.json`, `libraryroot.custom.css`,
`friends.custom.css`, and `bigpicture.custom.css`. The manifest uses the documented
`UseDefaultPatches: true`, which routes those CSS files to the main client,
Friends, and Big Picture windows respectively. There are no scripts, imports,
remote assets, or store/community page injections. The files are vanilla CSS.
[Millennium file structure](https://docs.steambrew.app/themes/basics/structure),
[manifest reference](https://docs.steambrew.app/themes/basics/config).

After approval, copy one entire folder into the active Millennium themes folder
and select its name in Steam → Millennium → Themes. The documentation's Linux
quick start uses `~/.steam/steam/steamui/skins/`; the current user FAQ also names
`~/.local/share/millennium/` for Linux skins/plugins. Resolve the active directory
from the installed Millennium version instead of hardcoding one in the installer.
Marketplace-only GitHub and image metadata are intentionally omitted from these
local themes rather than pointing at an invented published repository.
[Quick start](https://docs.steambrew.app/themes/introduction/quick-start),
[Linux locations](https://docs.steambrew.app/users/getting-started/faq).

THEARS carries the native chrome into obsidian, comfortable rounded controls,
phosphor primary actions, and clear keyboard outlines. PIYTI adds the shell's
ice registration seam to the library column, title rail, launch strip, and Friends
header. Big Picture keeps its native controller layout, with a phosphor focus
outline. Game artwork, labels, hit targets, scrolling and library density remain
native. All added motion is a 120 ms hover feedback transition; reduced motion
removes it. No animation runs while idle.

Steam's internal CSS is not a stable API. Partial symbolic class stems and native
`Dialog*` classes limit changes to chrome; they still need a real signed-in client
review after Steam updates. Selector/declaration syntax validation does not prove
that each selector matches the current Steam build.
[Millennium selector guidance](https://docs.steambrew.app/themes/basics/selectors).

## Discord / Vencord

`themes/discord/thears.theme.css` and `themes/discord/piyti.theme.css` are standalone
local Vencord themes, with the `/** @name … @author … @version … @description … */`
metadata block used by Vencord's own header parser. After approval, use Settings →
Vencord → Themes → Local Themes → Open Themes Folder, copy one file there, enable
it, and choose Discord's **Dark** appearance. Enable one direction at a time.
No Vencord plugins beyond theme loading are required. There are no external
imports, fonts, images, scripts, or ThemeAttributes dependency.
[Vencord header parser](https://github.com/Vendicated/Vencord/blob/main/src/main/themes/index.ts),
[official theme support](https://vencord.dev/support/).

THEARS follows the shell's dark surfaces and phosphor selection. PIYTI makes
the channel sidebar, title rail, composer and menus read as a communication bay:
ice edges locate the app; phosphor indicates an active field or selection.
Native role colours, mention treatment, presence colours, message ordering and
layout stay under Discord's control. These are visual cues from Discord's DOM;
CSS does not expose unread counts, calls, media, or messages to the shell.

The palette includes legacy and Visual Refresh variable aliases. Hash suffixes
are avoided, but the remaining class stems and variable names can change.
No account session was used to claim visual compatibility. Added interaction
feedback is bounded to 120/140 ms and respects `prefers-reduced-motion`.
Discord's own reduced-motion preference and the shell's `theme.motion` are
separate; propagation needs systems work if the owner wants one master switch.

## Hyprland app rules

Choose **one** direction and **one** syntax:

| Direction | Hyprland 0.55+ Lua | Hyprland 0.54 hyprlang |
|---|---|---|
| THEARS | `themes/hyprland/thears.lua` | `themes/hyprland/thears.conf` |
| PIYTI | `themes/hyprland/piyti.lua` | `themes/hyprland/piyti.conf` |

Source the selected fragment from the user's existing config after approval.
Lua uses `hl.window_rule`; hyprlang uses `windowrule = match:class …, …`.
[Current window-rule reference](https://wiki.hypr.land/Configuring/Basics/Window-Rules/),
[0.54 reference](https://wiki.hypr.land/0.54.0/Configuring/Window-Rules/).

Firefox, LibreOffice, Steam, Discord, Vesktop and PhotoCraft get 20 px corners, 2 px borders,
an inactive grid border, and no added blur/shadow outside fullscreen/maximize.
THEARS uses phosphor for focus; PIYTI uses ice. App-specific modal windows float
and center. Narrow English-title rules cover Steam Friends/Settings, Discord
Popout and Firefox Picture-in-Picture; omit or adapt those titles in other
locales. They do not alter activation/focus or force a window above others.
Check actual classes with `hyprctl clients`; Flatpak and alternate builds vary.
`steam_app_*` game classes are deliberately excluded.

PhotoCraft's exact class is `ai.storyteller.photocraft`, confirmed by its upstream
`APP_ID` passed to `with_app_id()` and by `StartupWMClass` in its desktop entry.
Other ArtCraft apps need their own confirmed identities; no speculative
suite-wide class matcher is installed.
[PhotoCraft window identity](https://github.com/storytold/photocraft/blob/main/apps/photocraft/src/main.rs),
[Linux desktop entry](https://github.com/storytold/photocraft/blob/main/packaging/linux/ai.storyteller.photocraft.desktop).

Fullscreen/maximize decoration matching is false. These fragments do not add
an overlay. The shell has no verified fullscreen surface-unmapping mechanism;
that inherited systems gap is the required S1 handoff in
[SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md). CPU measurements and decoration
rules do not demonstrate GPU-memory release.

## Verification and self-review

- `tinycss2 1.5.1` parsed every declaration and `cssselect2 0.10.1` compiled every
  selector in all 8 CSS files: **0 errors**. Parsers were downloaded to
  `/tmp/aerolith-ui012-css`, outside the repository, without changing the host
  application setup. Both `skin.json` files parsed with Python `json`; all three
  default patch targets exist in each folder.
- `luac -p /repo/themes/hyprland/thears.lua /repo/themes/hyprland/piyti.lua`
  inside a throwaway `aerolith-dev` container: **exit 0**.
- For each of `thears.lua`, `piyti.lua`, `thears.conf`, `piyti.conf`:
  `docker run --rm -v /home/user/aerolith-astra:/repo:ro --entrypoint Hyprland aerolith-dev --verify-config --config /repo/themes/hyprland/FILE --i-am-really-stupid`
  reported **config ok, exit 0**, using Hyprland **0.56.2**. No container was kept.
- Biggest app-theme weakness found in self-review: a partial `unread_` selector
  could recolour a whole unread text container in Discord. Removed it immediately;
  native unread signalling remains intact. Real Steam/Discord account-state
  rendering remains unverified and is clearly separated from format validation.
