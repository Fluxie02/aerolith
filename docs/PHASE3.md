# Phase 3: Welcome, Personalize, presets and tour resume

The contract between the Phase 3 jobs, and their record. The design comes
from `docs/design/review-2026-11/ASTRA.md` (sections 2–4) and the
integration rules from `SOL.md` (sections 2, 3, 5 and 6). The owner
decisions are in `REVIEW.md` section 7:
- Welcome opens on the first start of a fresh install, and on every start
  while "Show Welcome on startup" is on.
- It has no default shortcut.
- No blur or translucency.

## Rules (Opus)

- **Surfaces:** in-shell layer-shell surfaces, created only while open, with
  colours from the output's `DisplayProfile`, matching TourHost and the
  pickers. No new Deck bay.
- **Cost:**
  - no network calls when a surface opens;
  - no polling, and no background work or animation while closed;
  - diagnostics run only on request, through `Exec` (argv, with a timeout).
- **Config:** a user's config is never changed without an explicit action.
  Appearance changes go through the Phase 2 transaction (`Config.beginPreview`
  … `applyPreview`), and a batch through `setValues`.
- **Reporting:** "Unavailable" is shown, never a false "OK".

## Contract

### `services/Welcome.qml` and `lib/welcome.mjs` (Sol, round 1)

| Member | Meaning |
|---|---|
| `active`, `output` | shown, and on which output: the primary on first run, the focused output when opened by hand, falling back to the primary |
| `firstRunPending` | a fresh install that hasn't been onboarded. Upgrades (existing state, or a finished tour) don't count |
| `showOnStartup` | config `welcome.showOnStartup`, bool, default false |
| `open(reason)`, `close()` | open or close; it waits while locked or fullscreen, like the tour |
| `takeTour()` | close Welcome and start or resume the tour. Finishing the tour returns to the checklist; skipping goes to the desktop |
| `startUsing()` | dismiss onboarding without the tour |
| `checklist` | `[{ id, label, state: "passed"\|"attention"\|"unknown", detail, action }]`. The ids are `config` (no errors and the file parses), `output` (the resolved primary exists), `startup` (the method is detected and actually enabled) and `tour` (finished). Only real checks; opening a card never earns a tick |
| `info` | `{ version: {aerolith, quickshell, hyprland}, dialect, gpu, outputs: [{name, mode, scale, profile}], configErrors, configWarnings }`. Unknown values are null |
| `docs` | `[{ id, title, path, available }]` from `Paths.docsDir`, plus `openDoc(id)` through `xdg-open` |
| `runDiagnostics()` | runs `aerolith doctor --json` once, on demand. `diagnostics` holds `{ running, ok, checks: [...], error }` |
| `report()` | plain-text report (version, outputs, config errors, diagnostics) for preview and copy |
| `startup` | `{ method, enabled, state, error }` from `aerolith status --json`, plus `setLaunchOnStartup(enabled)` through a new CLI `aerolith startup {status,enable,disable} [--method hyprland\|systemd]` that reuses `startup.py`'s transaction |

Integration:
- First-run arbitration: the tour's auto-start waits for Welcome. Welcome
  opens first and hands over to the tour.
- Opening it: a Registry command `welcome.open` ("Welcome"), an IPC target
  `welcome`, and a CLI `aerolith welcome`.
- Hyprland: the layer namespace `aerolith-welcome` is added to `hypr.py`.
- State in `Store` (versioned): seen, handed off, the tour step for resume.
  Never in config.

### `services/Presets.qml` and `lib/presets.mjs` (Sol, round 2)

- **Built-in presets:** Default and Readable.
- **User presets:** stored in `presets.json` beside `config.json`
  (`Paths.presetsFile`).
- **Actions:** `list`, `preview(id)` (which uses the Config transaction),
  `saveCurrent(name)`, `remove(id)`, `importFile(path)` and
  `exportFile(path)`.
- **Validation:** bounded and strict on import. Unknown keys are reported.
  Only appearance keys are allowed: never AI, routines, binds, direction or
  startup.
- **Backups:** a backup is taken before an import is applied.

### UI (Astra)

- **Round 1, Personalize:** a mode of Settings (Personalize / All settings),
  following ASTRA.md decision 2:
  - live preview across the shell;
  - Apply / Cancel / Keep editing;
  - contrast-guarded palette editing;
  - text size, black background, strip and ground toggles where the schema
    has them;
  - the presets section once Presets exists.
- **Round 2:** the Welcome surface (ASTRA.md decision 3) on the Welcome
  service, and the presets section of Personalize.

## Status

- [ ] P3-SOL-1: Welcome systems
- [ ] P3-ASTRA-1: Personalize UI
- [ ] P3-SOL-2: Presets and tour resume
- [ ] P3-ASTRA-2: Welcome UI and the presets section
- [ ] Integration, harness and PR (Opus)
