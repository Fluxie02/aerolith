# UI-015 systems handoff

The shell's `theme.scheme` setting applies live through the visual token layer.
App exports are generated in `themes/schemes/<id>/`, with the existing app path
layout and optional PIYTI/THEARS variants. No installer, maintenance CLI,
service, host, profile, process or system configuration was changed for UI-015.

## Scheme activation for external apps

Claude should add an opt-in adapter, after systems review, that reads the
validated scheme ID from `theme.scheme` and selects its generated files.
`themes/schemes/index.json` is the allowlist and `shell/lib/schemes.mjs` is the
source of truth. Keep custom `theme.palette` overrides shell-only unless a
separate explicit export action is designed; the shipped files represent the
named schemes, not arbitrary runtime overrides.

Reuse the installer's ownership manifest, atomic writes, existing backup rules
and uninstall restoration. Change only files/includes owned by AEROLITH; merge
with user configuration. Apply a selection once in response to the setting,
with no polling, permanent watcher or background helper. Rapid changes should
coalesce and stale work must not overwrite the latest choice. A missing app,
mod or permission should leave the live shell selection intact and report a
clear optional integration result.

| Target | Requested systems behaviour |
| --- | --- |
| kitty / Alacritty / foot | Select the generated include/import using the app's supported reload path when available; otherwise mark it as applying to new windows. Preserve non-theme settings and running sessions. |
| btop | Offer/install the named generated theme in its supported theme location; use a supported theme reload if one exists. |
| GTK / Qt | Preserve the chosen toolkit/backend, fonts and existing custom CSS; update only managed palette/includes. Do not force a global toolkit environment variable. |
| Hyprland | Choose one existing config syntax and one direction, then update a managed appearance include and request one supported config reload. Preserve monitor, binding, process, fullscreen and lifecycle policy. |
| Firefox | Offer the unique named static theme or managed profile CSS explicitly. Resolve the chosen profile and preserve its preferences/customizations. Permanent static add-on distribution requires signing; CSS requires its existing preference and restart. No theme-triggered forced restart. |
| Discord / Steam | Require the already supported Vencord/Millennium theme mechanism and resolve its installed path/version. Keep account sessions, native security state and artwork outside the adapter. No unsupported client modification. |
| LibreOffice | Offer the generated extension-source tree as a package and its uniquely named PIYTI/THEARS choices through the supported appearance mechanism. Preserve document settings and white document paper. |
| PhotoCraft | Release builds lack the debug loader. Keep the built-in dark appearance plus external compositor decoration until upstream offers a supported release theme mechanism. Never deploy the debug polling adapter as a production service. |

## Optional terminal command and installer choice

If the existing maintenance CLI exposes appearance choices, add a
`theme.scheme` selector using the same validated IDs and immediate config
update path as Settings. The concrete command spelling and completion wiring
belong to Claude. The installer may offer the twelve scheme names and source
their previews from the catalog, defaulting to `limb`; it must not keep a second
hand-maintained list or palette. Neither feature is implemented in UI-015.

## Motion and verification boundary

The app CSS keeps its existing bounded interaction feedback and each app's
`prefers-reduced-motion` handling. Shell `theme.motion`/`lowEffects` does not
automatically propagate to third-party applications. If the owner wants a
single master motion control, use a supported desktop/app preference route;
do not inject scripts or introduce timers. Keep the UI-013 idle CPU budget and
fullscreen resource-release contract throughout activation.

The generated payloads pass numeric contrast, reproducibility, syntax and the
available foot/Hyprland native parsers. Systems acceptance still needs real
app reload tests, failure/race tests, ownership/restoration checks and real
Hyprland/fullscreen verification. No signed-in app or live external theme
integration is claimed by these artifacts.
