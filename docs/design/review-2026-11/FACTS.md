# Review November 2026: verified facts

The shared fact base for the design, customization and onboarding review.
Everything here was checked in code on `main` at 9729b47 (after #12). Astra,
Sol and Opus work from this file instead of re-exploring the codebase. Check
a claim before building on it; line numbers drift.

## Configuration and customization

**Schema.** `shell/lib/config.mjs:31-182`, schema version 1. Three things are
generated from it:
- the JSON schema, by `tools/gen-schema.mjs`;
- the table in `docs/CONFIGURATION.md`, by `tools/gen-config-doc.mjs`;
- the Settings bay rows, in `SettingsBay.qml:43-67`. Every bool, enum, int,
  number and string gets a row; map and array keys are skipped.

**Sections:**
- **display:** `primary`, `outputs{strip,ground,profile standard|oled}`,
  `oled{idleDimAfter,idleDimLevel,hideDecorationWhenIdle}`, `overlayOn`,
  `noticesOn`. Also `output` (deprecated) and `warnOnMultipleDisplays`
  (retired).
- **theme:**
  - `scheme`, one of 12;
  - `density` compact|standard|comfortable;
  - `uiScale` 0.75–2;
  - `motion` full|reduced|off;
  - `intensity` saturated|insane;
  - `lowEffects`;
  - `fontSans`, `fontMono`;
  - `palette` (a map of colour roles).
- **strip:** `visible`, `edge` top|bottom, `showWindowTitle`, `telemetry`
  off|alert|always, `clock`, `showDate`, `showSeconds`, `workspaceCount`.
- **Small sections:** `ground.enabled`, `tour.enabled`.
- **Other sections:** `commandCore`, `telemetry`, `audio`, `lock`,
  `navigator`, `routines`, `notifications` and `logging`.

**Settings outside `config.json`:**
- **Direction** (piyti|thears) is in `installation.json`. It is read once,
  has no watch, and is set only by `aerolith install`.
- **AI** settings are in `ai.json`.
- **Routines** are in `routines.json`.
- **Keybinds** are in `hypr-binds.json`, applied by `aerolith hypr apply`.

**How config behaves:**
- The file is watched and reloads on change.
- A bad value falls back to its default and is reported as an error.
- Unknown keys are kept, but their warnings are only logged and never shown.
- With broken JSON, the last good config stays in effect.
- The migration mechanism exists, but no migrations are defined yet.

**Customizable today:**
- **Scheme:** in Settings it applies when chosen (Enter or click); moving the
  cursor does not preview. Also the `settings.scheme` command and
  `aerolith scheme`.
- **Density, motion, intensity, strip edge, low effects and strip telemetry:**
  each has its own command.
- **Fonts:** free text, applied live.
- **Per-output:** strip, ground and OLED profile.
- **Palette:** colour overrides in the config file only, with no contrast
  check; unknown roles are dropped silently.

**Not customizable:**
- transparency or blur levels (the opacity tokens are fixed in
  `tokens.mjs:68`);
- type sizes (they follow density × uiScale only);
- which strip indicators appear, or their order;
- ground widgets;
- workspace names;
- presets, profiles, import/export, undo, a staged preview, or reset to
  defaults inside the shell (only `aerolith config reset` in the CLI).

**Settings writes:**
- Each arrow press or toggle calls `Config.setValue`, which writes the whole
  file at once (`Config.qml:115-131`).
- Unknown keys survive.
- It refuses to write while the JSON is broken, and rolls back if a save
  fails.

**Risks:**
- **A CLI change can be lost.** `aerolith scheme` and `aerolith intensity`
  replace the file atomically, and the file watch may miss an atomic replace
  (`Config.qml:126-129`). The shell then keeps its stale copy, and the next
  Settings write overwrites the CLI's change.
- **Validation holes:**
  - `setPath` skips validation for array and map values
    (`config.mjs:377`);
  - palette keys are unchecked;
  - `noticesOn`, `primary` and the font names are free text, with no pickers.
- **Settings clutter:** the retired and deprecated keys appear as editable
  rows.
- **Stale doc:** `CONFIGURATION.md:36-37` says the profile does not change
  colours, but it does.
- **Needs a restart or a re-apply:** `telemetry.gpu`, direction, keybinds.

## Desktop integration and onboarding

**CLI** (`installer/aerolith_install/cli.py:1275-1365`): install, uninstall,
status [--json], doctor, themes, ai, config {validate,path,reset}, intensity,
scheme, hypr {show,apply,remove}, run/restart/stop, --version.

**No update command:**
- To update, run `git pull && ./install.sh` again; install notices it's an
  update and prunes files that are no longer shipped.
- Nothing checks for a newer version.
- The version lives only in `installer/aerolith_install/__init__.py`
  (0.1.0a1), and is written to `~/.local/state/aerolith/manifest.json`.

**Startup choices** (`cli.py:54-58`):
- **hyprland:** an exec-once or `hl.on` entry, with the uwsm prefix when
  UWSM is active.
- **systemd:** writes `aerolith.service`, but **does not enable it**
  (`cli.py:657`), so the first boot after install can come up without the
  shell.
- **manual.**

**No AEROLITH `.desktop` file or XDG autostart entry**, and no mention of
portals, polkit or keyring.

**Help bay** (`modules/help/HelpBay.qml`, F1):
- the command list is built from the live Registry;
- the key groups are hard-coded and show shortcut names, not your real key
  combinations (your binds are in the Hyprland fragment, which the shell
  cannot see);
- it leaves out session, scratch, park and brightness.

**Not installed, or nowhere to be found:**
- The docs are not installed: only README.md is copied (`cli.py:597-600`),
  yet `RoutineConsole.qml:75,233` points to `docs/COMMANDS.md`.
- The installed README is mostly developer material.
- Code refers to files that don't exist: `docs/INSTALLATION.md`
  (`cli.py:428`), `docs/INTEGRATIONS.md` (cli.py, providers.py,
  AiModule.qml) and `packaging/arch` (`cli.py:291`).

**Stale docs:**
- `ALPHA.md:64` says there is no network or Bluetooth yet.
- `ALPHA.md:12` and `checks.py:158` say AEROLITH supports one display.

**No Welcome, About or system-info surface:**
- The shell doesn't know its own version: nothing in `shell/` reads the
  manifest.
- The ipc `status` has no version fields.

**Pieces a Welcome screen can reuse:**
- **`ipc status`** (`ControlSurface.qml:72-136`): outputs, Hyprland and
  dialect, network, Bluetooth, PipeWire, config errors, AI, theme, CPU and
  memory, tour.
- **`Config.errors`**, and **`Telemetry.gpuVendor`, `gpuDevice` and
  `gpuStatus`**.
- **The installer's data:** `checks.run_checks()`, the `cmd_status` info,
  `quickshell_version()` and `hyprland_version()`.
- **`core/Exec.qml`:** runs a program from argv with no shell, with a
  timeout; usable for `aerolith status --json` and `xdg-open`.
- **The optional-module pattern** in `AiLoader.qml`.
- **Layer-shell PanelWindows:** every surface uses one, with a namespace
  `aerolith-*`. There is no xdg-toplevel `FloatingWindow` yet.
- **Entry points:** Registry commands, IPC targets, `AeroShortcut` plus
  `DEFAULT_BINDS` in `hypr.py:38`.
- **The `Store` pattern** for first-run state.
- **The schema-driven Settings bay:** a new `welcome.*` key appears there
  with no extra UI code.

**Risk: layer rules.** The no_anim layer rule list (`hypr.py:31-34`) is
missing `aerolith-tour`, `aerolith-network` and `aerolith-bluetooth`.

## Guided tour (verified by Opus, in code and in the headless harness)

**How it starts and is controlled:**
- **Code:** `services/Tour.qml`, `lib/tour.mjs`, `modules/tour/TourHost.qml`
  and `TourCard.qml`.
- **Mounting:** a LazyLoader in `shell.qml`.
- **Saved state:** completion is stored in `state.json`, versioned.
- **Steps:** hatch, ring, search, apps, strip.
- **Auto-start:** once, when `tour.enabled` is on and the tour isn't done,
  on the primary output, held while locked or fullscreen.
- **Keys:** Enter or Right goes on, Left goes back, Esc skips, and the last
  step finishes. Skipping also marks it done.
- **Replay:** Command Core (Super+Space), "Show the tour again"
  (`tour.start`, keywords tour, welcome and first run), or
  `qs -p <shell> ipc call tour start`.

**Gaps:**
- **Not linked anywhere else:** not from Help, Settings, the README or
  ALPHA.md.
- **Replay is blocked when `tour.enabled` is false.**
- **Progress isn't saved:** a restart mid-tour starts it over.
- **No contextual tooltips.**
- **Fragile geometry:** each step's highlight position reproduces the layout
  maths of Hatch, WorkspaceOrbit and Instrumentation inside `TourHost.qml`,
  so it breaks if those layouts change.
- **Settings is only reached by "open Search and type Settings"** in the
  last step's text.

**Tests:** `tests/scenarios/tour.sh` runs in CI with TOUR=1 and passes.

## Design system and components

See the section below, added when that audit completes.
