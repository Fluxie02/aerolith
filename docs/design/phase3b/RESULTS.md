# P3-ASTRA-2 — Welcome and Personalize

Astra · 6 November 2026 · worktree `codex/design-db35c89e`.
This implements the UI contract in [PHASE3](../../PHASE3.md) and
[Astra decisions 2–3](../review-2026-11/ASTRA.md). No commit made.

**Stopped at the requested systems-owner boundary.** The implementation is
present, but P3-ASTRA-2 is not fully accepted: the 4K capture's original startup
has ten typed undefined-assignment warnings in protected core/services files.
The clean instrumented restart does not prove a fix. OLED Welcome capture,
large-text capture and the last targeted UI assertion remain pending.

## Changed files and rationale

- `shell/modules/welcome/`: a bounded, lazy `WelcomeHost` and separate overview,
  start, checklist, outputs, startup, documentation, diagnostics/report and
  system-info sections, with small shared section/text/action components.
  `shell/shell.qml` only imports the module and mounts it while `Welcome.active`.
- `shell/modules/settings/SettingsBay.qml` implements Sol's owner adapter
  exactly: host `deck:` destinations resolve through the bay signal; internal
  routes remain internal. `SettingsEntry.qml` is visual entry routing so
  Welcome selects Personalize (including an already-open Settings bay).
- `PersonalizePane.qml`, `PresetsSection.qml`, `PersonalizeInput.qml` and
  `WorkspaceNames.qml` expose service-backed presets and Terra's schema keys.
  `personalize.mjs` supplies schema-derived labels/grouping, `PersonalizeField`
  labels the preview/save boundary, `PersonalizeAction` grows with text, and
  `SettingControl` retains numeric enum values for text-size choices.
- `tests/scenarios/welcome-ui.sh` adds real input and disposable observational
  probes; `.github/workflows/ci.yml` adds only that scenario and its failed-run
  artifacts.

Welcome retains the existing Bezel housing and output-local DisplayProfile.
Opaque backgrounds, near-black OLED planes and semantic status text preserve
hierarchy without blur or translucency. The header identifies WELCOME and its
output, with a persistent Close action. AEROLITH and a short overview lead to
Take tour/Personalize. Checklist rows display the service's actual
passed/attention/unknown values and corrective actions; visiting a section
never earns a tick. Output summaries and system facts come from `Welcome.info`;
null facts say Unavailable. Missing docs are explicitly unavailable.

The housing caps at 1120 × 820 logical units, or 880 units wide in compact mode. Compact/large-text layouts become
one scrolling column; the header and startup-preference/Start using footer
stay outside the scroll. Tab follows section order, focused controls reveal
themselves, Enter/Space activate, and Escape closes. No shortcut is assigned.
The loader destroys the surface when closed or held by the service; no new
polling, animation loop, network request, telemetry demand or closed-surface
work is introduced.

Launch on startup calls only `Welcome.setLaunchOnStartup` after an explicit
click and shows detected state/pending/errors. Show Welcome on startup writes
only `welcome.showOnStartup` via one `Config.setValues` batch. They are separate
controls. Diagnostics run only on request, disable overlap, render
running/result/error and never turn an unavailable response into Passed. A
plain-text report is previewed before Copy. Tour entry is disabled while an
existing appearance draft needs resolution; Personalize returns to that editor.

Presets list immutable Default/Readable plus user entries. Preview participates
in the existing Apply/Cancel transaction and scale/visibility recovery.
Save captures the current appearance without applying; user removal requires
confirmation. Import/export take absolute paths, show service validation and
unknown-key messages verbatim, expose a draft change list, preserve exact
connector names when output overrides are explicitly included, and explain
that a backup precedes imported Apply. Palette contrast checks remain in force
for presets. Pending imports cannot be used to navigate away; a forced editor
retirement invalidates its callback and cancels any late imported draft.

Text-size steps 100/112/125/150, per-output Black background, strip item
visibility, Ground widgets and workspace names use the schema's preview
permission. Per-output Strip/Ground permissions are outside that allowlist:
they say Saves immediately, require Apply/Cancel of an existing dirty preview,
and use `Config.setValues` after cancelling a clean baseline. No allowlist is
expanded in the UI.

## Integration and peer review

Sol's Welcome/SystemInfo/Presets services, preset/welcome libraries, Config
transaction and Deck leave protocol were read once against their verification
contracts. Two owner findings are recorded below. The owner
adapter is now implemented and covered with the actual Settings bay, including
Apply, Discard, Keep editing, bay switching and Deck closing. No service, core,
config library, Deck, installer or host configuration file was changed.

This supersedes the old Phase 3 results' schema-key requests for independent
text size, black background, item/widget visibility and workspace names: all
are now implemented. Remaining unimplemented proposals are strip **ordering**
and per-output text/density overrides; these are outside this job's available
schema. Per-output Strip/Ground permissions deliberately save rather than preview.

The shared hub retained stale UI-016/Claude audit ownership and Claude-held
P3-ASTRA-2 reservations. The explicit job brief delegates those reservations
to Astra; the start note records that authorization. No Claude lock or hub JSON
was edited directly. At 10:26 UTC, after the delegated reservation expired,
Astra acquired its own 7200-second lock for all assigned paths.

**High — cold startup still emits undefined assignments at 4K.**
The original shell lifetime in the 3840×2160, scale 1.5 capture emitted ten
`Unable to assign [undefined]` warnings, at:

- `services/Telemetry.qml:28` (int);
- `core/Theme.qml:144,200,201` (double/bools);
- `services/Idle.qml:14` (double), `core/Ui.qml:24` (QString);
- `services/Tour.qml:34,35`, `services/Notifications.qml:70` and
  `services/Compositor.qml:62` (bools).

Evidence: [original startup log](welcome-4k-startup-qs.log), lines 44–53;
[clean instrumented restart](welcome-4k-instrumented-qs.log);
[all-log audit](qml-audit.json). Geometry passed and the screenshot rendered,
but the capture command exited 1 on its strict QML audit. These are not treated
as harmless environment messages. The cause and attribution remain unproven;
UI import/activation order may contribute, so this is not labelled pre-existing.

Minimal owner handoff: investigate the Config/Theme/Welcome/Ui singleton
initialization order and restore valid typed inputs before consumers evaluate.
Compare with the Welcome mount disabled in a disposable copy to isolate the UI
contribution. Do not mask the warnings with a clean retry. No protected file
was edited. Per the task's explicit stop rule, implementation and further
capture work stopped when this failure was observed. One owner revision is
available; no cloud agent was dispatched.

**Medium — inherited scenario is not executable in Git.**
`tests/scenarios/schema-keys.sh` is mode `100644` in `git ls-files -s` and `644`
on disk. The runtime scenario passes, but the unchanged Python installer test
requires all shell scripts to be `100755`. Evidence: the full Python run below,
`test_installer.py:1941`. Minimal owner correction: `chmod +x tests/scenarios/schema-keys.sh` and
`git update-index --chmod=+x tests/scenarios/schema-keys.sh`. That file is outside Astra's assigned edit
list and was left unchanged. The finding was published as an owner handoff;
one owner revision remains available.

## Verification

All scenarios run sequentially using the existing Docker daemon, software
rendering and the harness's click/type/key helpers. Startup actions use a fake
`aerolith` on the container PATH and never enable real startup. Base64 encodes
list arguments to the observational IPC probe. Existing scenario assertions
are unchanged.

The first Personalize regression exposed an overbroad guard: preset-store
loading prevented its initial preview from beginning. The UI now guards only
a pending import; the original scenario passed unchanged after that correction.
Initial Welcome UI development also corrected a QML declaration separator and
a missing container `rg` executable in the new log audit (the scenario uses
`grep -En`, matching existing scenarios). The requested headless scenarios'
QML audits passed. The later 4K capture exposed the separate startup failure
above: 21 of 22 audited logs have zero strict matches; the remaining original
4K startup has ten. The intentional caught malformed-state JSON warning in
`welcome.sh` is the sole excluded application warning.

| Exact command | Final result |
|---|---|
| `WELCOME=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/welcome-ui.sh build/ci/welcome-ui` | Exit 0; real-input assertions passed, both QML logs clean |
| `WELCOME=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/welcome.sh build/ci/welcome` | Exit 0; first-run/upgrade/restart/tour/output/lock/fullscreen/startup/diagnostic assertions passed |
| `tools/headless/run.sh tests/scenarios/personalize.sh build/ci/personalize` | Exit 0; original assertions unchanged |
| `tools/headless/run.sh tests/scenarios/presets.sh build/ci/presets` | Exit 0; presets: ok |
| `tools/headless/run.sh tests/scenarios/schema-keys.sh build/ci/schema-keys` | Exit 0; schema-keys: ok |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/ci/deck` | Exit 0; deck and generic leave protocol: ok |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/ci/tour` | Exit 0; persistence, navigation, focus restoration and fullscreen lifetime passed |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/ci/smoke` | Exit 0; smoke: ok |
| `AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/ci/oled` | Exit 0; OLED/LCD idle, zero swaps over 3 seconds, resume bindings and profile checks passed |
| `node tests/js/run-node.mjs` | Exit 0; 296 passed, 0 failed |
| `pytest -q tests/py` | Exit 1; 388 passed, 1 skipped, 1 failed in 130.76 s; inherited `schema-keys.sh` Git mode, as detailed above |
| `WELCOME=1 RES=1280x720 tools/headless/run.sh tests/scenarios/welcome-ui.sh build/ci/welcome-ui-compact` | Exit 0; full real-input scenario passed at the 880-unit compact cap, both QML logs clean |
| `WELCOME=1 OUTPUTS=2 RES=3840x2160 SCALE=1.5 tools/headless/run.sh build/phase3b/capture.sh build/ci/welcome-4k` | Exit 1 before QML; headless sway bus error; cause not established |
| `WELCOME=1 RES=3840x2160 SCALE=1.5 HYPR_MOCK_ARGS="--mode 3840x2160 --scale 1.5" tools/headless/run.sh build/phase3b/capture.sh build/ci/welcome-4k` with per-container `--shm-size=512m` | Exit 1; render and geometry passed, original-startup QML audit failed with ten warnings |

The capture-only script is derived from `welcome-ui.sh`'s disposable-copy/probe
prefix, then captures Welcome and the diagnostics section, checks header/footer
bounds and runs the same strict log audit. The larger shared-memory limit was
supplied by a temporary exported shell function that adds `--shm-size=512m` to
`docker run`; no harness file or daemon setting changed. The successful render
used one output and the explicit matching mock mode/scale. Docker info remained
reachable (29.9.1). The original two-output compositor failure is not attributed
to a proven cause.

The final small change making Review startup reveal its explanation even when
the launch control is disabled, and its corresponding viewport assertion in
`welcome-ui.sh`, were not rerun after the stop condition. All other UI assertions,
including unknown startup and low-contrast-import rollback, passed in the last
1080p run. Final `bash -n tests/scenarios/welcome-ui.sh`, `git diff --check`,
whitespace scanning of changed/new text files, and a protected-path diff guard
passed. [Source hashes](source-hashes.json) identify the delivered source.

## Screenshots

All are real headless captures converted to JPEG at quality 90. Every file is
below 4 MiB (largest: 435,101 bytes); dimensions are preserved.

| Evidence | Capture |
|---|---|
| Welcome, 1920×1080 | [JPEG](welcome-1920x1080.jpg) |
| Welcome, compact 1280×720 | [JPEG](welcome-1280x720.jpg) |
| Welcome, 3840×2160 scale 1.5 | [JPEG](welcome-3840x2160-scale-1.5.jpg); geometry passed, startup audit failed as above |
| Personalize presets | [JPEG](personalize-presets.jpg) |
| New strip items | [JPEG](personalize-strip-items.jpg) |
| New Ground widgets / workspace names entry | [JPEG](personalize-ground-widgets.jpg) |
| Dirty leave from an actual Deck bay switch | [JPEG](deck-dirty-leave.jpg) |
| Welcome on OLED | [JPEG](welcome-oled.jpg); captured by Opus at integration from `WELCOME=1 CONFIG=docs/design/phase3/oled-personalize-config.json tools/headless/run.sh tests/scenarios/welcome-ui.sh` (exit 0) |

The existing OLED runtime regression passed, but that is not represented as
a Welcome-on-OLED screenshot or acceptance test.

## Risks and follow-up

Headless sway/pixman and mocked Hyprland IPC establish layout and UI behavior,
not real GPU/OLED hardware, Hyprland focus/namespace policy or real startup
mutation. Those remain integration/hardware acceptance work. Installed-version
and GPU facts may truthfully be unavailable in the harness; no update method
is guessed. Existing independent external config-writer limitations remain
owned by Config.

`chmod +x tests/scenarios/welcome-ui.sh` succeeded. The requested
`git update-index --add --chmod=+x tests/scenarios/welcome-ui.sh` was attempted
but failed: Git's object/index metadata is read-only in this worktree sandbox
(`unable to create temporary file: Read-only file system`). The bridge must
stage the executable filesystem mode as 100755 when committing. No commit,
Docker daemon start/stop/prune operation, global installation, host
configuration change or power action was performed.

Owner follow-up: resolve the startup warning and executable-mode findings;
then rerun the latest Welcome UI scenario, complete Welcome OLED and enlarged
text captures, and perform final integration acceptance. Astra's implementation
and evidence are handed off with these limits; no full-completion claim is made.
