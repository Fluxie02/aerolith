# P3-SOL-1: Welcome systems

Scope: `docs/PHASE3.md`, Welcome round-one service contract. No production
visual components or `shell/modules/settings/*` edits. The two-pixel Welcome
probe exists only in the scenario's disposable shell copy. No commit made.

Implementation:

- `Welcome.qml` owns requested/held presentation, primary first-run placement,
  focused manual placement, explicit tour handoff and desktop dismissal.
- `welcome.mjs` contains versioned state validation, first-run policy,
  truthful checklist states, diagnostic parsing and plain-text reporting.
- Store snapshots whether state existed before startup (including malformed or
  unreadable state), and persists seen/handoff/resume/finished state separately
  from configuration. Tour holds automatic startup behind Welcome, resumes the
  saved handoff step, returns to Welcome on finish, and dismisses on skip.
  Legacy completed tours are unknown on the checklist because that record
  cannot distinguish finishing from skipping; neither restarts onboarding.
- `SystemInfo.qml` contains the former ControlSurface version code.
  `aerolith` IPC target's `status()` fields and version-label semantics are unchanged.
- Docs resolve within the installed `Paths.docsDir` bundle and are opened with
  `Exec` argv. Missing docs are unavailable. GPU/mode/version values stay null
  when their existing local sources cannot supply them.
- Welcome only requests read-only startup status when opened. Doctor runs once
  per accepted explicit request, never at startup; it has a 35-second timeout
  above the doctor's existing 30-second budget. Overlapping requests are ignored.
  CLI resolution checks PATH, the per-user launcher, then `/usr/bin/aerolith`.
- CLI startup status reads actual user-service enablement or generated
  Hyprland startup plus its include. Enable/disable reuse `startup.Transaction`,
  retain ownership checks and rollback, preserve config and existing binds,
  and do not stop the running shell. User and packaged layouts are covered.
- `welcome.open`, target `welcome`, CLI `aerolith welcome`, and exact namespace
  `aerolith-welcome` are integrated. No shortcut is added.
- `welcome.showOnStartup` defaults false; generated schema and config docs
  include it. WELCOME=1 leaves fresh harness state; TOUR=1 supplies an explicit
  handoff. Other scenarios mark Welcome seen and the tour completed.

## Validation

Docker was already running; `docker info --format '{{.ServerVersion}}'`
returned `29.9.1`. The Docker daemon was not started, stopped or cleaned.
The requested scenarios run sequentially with the CI arguments and paths.
Final results are recorded below.

Welcome scenario additionally checks: fresh primary/no simultaneous tour,
restart during handoff, finish versus skip checklist, immediate dismissal
persistence, existing/malformed-state upgrade, repeated showOnStartup,
manual secondary focus, lock/fullscreen holds and queued open, real doc argv,
zero doctor/startup mutations on opens, overlap rejection, exactly two doctor
calls for two accepted requests, and explicit startup actions. Its per-lifetime
QML audit excludes only the caught state-JSON warning deliberately induced by
the malformed-state case; engine parse/type/reference/binding errors are fatal.
An initial scenario run stopped because that expected warning matched the
unqualified audit; the audit was corrected before final verification.

## Final results (sequential CI invocations)

| Command | Result |
|---|---|
| `WELCOME=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/welcome.sh build/ci/welcome` | Exit 0; all service, persistence, migration, routing, docs and explicit-operation assertions passed |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/ci/tour` | Exit 0; state, navigation, measured targets, focus restoration and fullscreen lifetime passed |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/ci/smoke` | Exit 0; `smoke: ok` |
| `AI=1 tools/headless/run.sh tests/scenarios/catalogue.sh build/ci/catalogue` | Exit 0; 68 commands, including `welcome.open` |
| `python3 tools/gen-commands-doc.py build/ci/catalogue/commands.json` | Exit 0; regenerated `docs/COMMANDS.md` from the live catalogue |
| `AUDIO=1 INSTALL="--ai claude --startup hyprland" tools/headless/run.sh tests/scenarios/installed.sh build/ci/installed` | Exit 0; `installed: ok` |
| `tools/headless/run.sh tests/scenarios/runtime.sh build/ci/runtime` | Exit 0; `runtime: ok` |
| `node tests/js/run-node.mjs` | Exit 0; 282 passed, 0 failed |
| `python3 -m pytest -q tests/py` | Exit 0; 389 passed, 1 skipped in 109.10 seconds |

Additional required/static checks, all exit 0:

- `node tools/gen-schema.mjs`
- `node tools/gen-config-doc.mjs`
- `node tools/gen-config-doc.mjs --check`
- `bash -n tests/scenarios/welcome.sh tests/scenarios/tour.sh tools/headless/run.sh tools/headless/session.sh`
- `git diff --check`

The schema freshness test also passed in pytest. Final headless artifacts are
under `build/ci/{welcome,tour,smoke,catalogue,installed,runtime}`. The final
source/test/CI hashes for all 22 changed non-documentation files are pinned in
`build/ci/p3-source-hashes.json` and were unchanged through verification.
`build/ci/p3-qml-audit.json` records zero QML errors in the six final logs;
Welcome/Tour supply per-lifetime segments, and the other logs stop at explicit
IPC shutdown. The intentionally caught malformed-state warning is excluded.
Missing container system-bus/audio/hardware warnings are not QML engine errors.

Checklist action ids for configuration/output and tour resolve to real
Registry commands. The `startup` action descriptor denotes the UI's explicit
startup control, which calls `setLaunchOnStartup(bool)`; it is not a command
that runs when Welcome opens.

## Parallel review

Reviewed the Personalize draft in worktree `49c9b525` once. Medium finding:
`PersonalizePane.qml:83` skips `Config.cancelPreview()` while Apply is pending;
SettingsBay retirement (`SettingsBay.qml:21`) can therefore retain and commit
a draft still waiting for its fresh read. Minimal correction:
call cancelPreview whenever previewActive; Config already invalidates queued
requests, while a submitted atomic write may finish. ShellCommands already
cancels previews on lock and screen removal, so the remaining finding concerns
host retirement through external close/switch while the fresh read is pending.
The lock portion of the initial finding was corrected in a follow-up hub
note. Published to the shared hub as Sol, task P3-SOL-1, requesting one revision. No settings files edited.

## Limits

Headless checks use sway/pixman, a Hyprland IPC mock, and a fake systemctl/CLI.
Native Hyprland, a real systemd user manager and physical GPU/output behavior
are not verified. The production Welcome surface belongs to Astra's round two.

## Files changed

- `.github/workflows/ci.yml`
- `docs/COMMANDS.md`
- `docs/CONFIGURATION.md`
- `docs/verification/P3-SOL-1.md`
- `installer/aerolith_install/cli.py`
- `installer/aerolith_install/hypr.py`
- `installer/aerolith_install/startup.py`
- `shell/core/Paths.qml`
- `shell/core/Store.qml`
- `shell/lib/config.mjs`
- `shell/lib/tour.mjs`
- `shell/lib/welcome.mjs`
- `shell/modules/ControlSurface.qml`
- `shell/schema/config.schema.json`
- `shell/services/SystemInfo.qml`
- `shell/services/Tour.qml`
- `shell/services/Welcome.qml`
- `shell/shell.qml`
- `tests/js/index.mjs`
- `tests/js/welcome.test.mjs`
- `tests/py/test_installer.py`
- `tests/scenarios/tour.sh`
- `tests/scenarios/welcome.sh`
- `tools/headless/run.sh`
- `tools/headless/session.sh`

The single Personalize review correction is still pending at completion; no
revision or runtime verification of that separate draft was received. The
minimal cancellation change above is recommended over retaining a draft on
external retirement; Astra/Opus owns that follow-up. It does not block this
Welcome systems implementation.
