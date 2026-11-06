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

- [x] P3-SOL-1 (Sol): Welcome service, SystemInfo, first-run arbitration with the tour (including resume), `aerolith startup`, `aerolith welcome`, `welcome.sh` in CI.
- [x] P3-ASTRA-1 (Astra): Personalize mode in Settings: live preview, Apply/Cancel/Keep editing, contrast-guarded palette, View desktop, `personalize.sh`.
- [x] P3-SOL-2 (Sol): Presets (built-in, user, import/export, backups), the Deck leave-confirmation protocol (`mayRetire`), and a cold-start fix (`Config.refreshData`: no more "Unable to assign [undefined]"; `smoke.sh` now checks for it). Tour resume landed in P3-SOL-1.
- [x] P3-TERRA-1 (Terra): `theme.textSize`, per-output `blackBackground`, strip item toggles, Ground widget toggles and workspace names, with their consumers. Defaults stay byte-identical. `schema-keys.sh` in CI. Per-output text and density overrides are skipped (ASTRA.md marks them "could").
- [x] P3-ASTRA-2 (Astra): the Welcome surface (`shell/modules/welcome/`, one component per section), the presets section of Personalize, controls for Terra's keys (text size, black background per output, strip items, Ground widgets, workspace names), and SettingsBay on Deck's leave protocol. `welcome-ui.sh` in CI. Evidence: `docs/design/phase3b/`.
- [x] Integration (Opus):
  - **Exec bits:** `welcome-ui.sh` and `schema-keys.sh` are now executable in git.
  - **`personalize.sh`:** added to CI.
  - **`welcome-ui.sh` startup audit:** now taken before the production shell stops, as `smoke.sh` and `welcome.sh` already do. Qt's engine teardown is kept in `startup-teardown-qs.log`; it was the source of the ten "Unable to assign [undefined]" lines in Astra's 4K run.
  - **`welcome-ui.sh` typing:** `ui_type` now waits for focus, sends each edit through one virtual keyboard, and checks the field text. At 4K ×1.5 the first key of a new `wtype` device was dropped.
- [x] Welcome on OLED captured (`docs/design/phase3b/welcome-oled.jpg`). Presets unit test: Qt's V4 refuses `1e999` in `JSON.parse`, so the test asserts the refusal in both engines.
- [ ] PR #16 (Opus): full local CI set green on `4104ab9` (34 headless scenarios, Node 296, Qt V4 274, pytest 389 + 1 skipped); waiting on GitHub CI and the owner

### Follow-ups (not in this phase)

- **Strip names:** a workspace name in the strip's round cell is truncated ("Wri…"). It needs a fit decision, from Astra or Terra.
- **Presets field:** the "Preset name" field runs into the scrollbar.
- **Two outputs at 4K:** two outputs at 3840x2160 ×1.5 crash headless sway with a bus error, probably Docker's default 64 MiB `/dev/shm`. `run.sh` could pass `--shm-size`. CI does not run this case.
- **Teardown warnings:** the ten teardown-only binding warnings at shell exit are harmless but noisy, a hygiene item for Sol.
- **Earlier follow-ups:** the portrait ring clipping, and the owner's real-hardware checks (Hyprland, GPU, OLED).
