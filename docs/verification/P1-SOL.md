# November review — P1-SOL systems evidence

Sol, 5 November 2026. Worktree `607e9e1e`; owner-approved REVIEW §2 items
1, 2, 3 and 7. No commits or host configuration changes. Docker was already
running (`docker info --format '{{.ServerVersion}}'`: 29.9.1).

## Changes

- `LockHost.qml`: each `WlSessionLockSurface` owns a DisplayProfile using its
  own `screen.name`, including backing-only secondary surfaces. Its persistent
  idle policy is consumed by ornament only. `LockView.qml` receives that profile
  and passes it to Bezel/ScrollMark; every colour uses the profile. Engraving
  hides on OLED idle; the password, prompt, errors and authentication plane stay
  visible and opaque. PAM, submission, buffer clearing, cooldown, lock ownership
  and reload protection are unchanged. Geometry/type/motion remain on Theme.
- `SessionView.qml`, `OsdView.qml`, `NoticeStack.qml`: remaining foreground and
  accent colours now use the destination profile. Standard DisplayProfile
  colours alias the original Theme values; no tokens or layout changed.
- `Config.qml`: serialized request queue; each request starts an asynchronous
  fresh disk read, rebases only the requested setting and waits for save
  completion before processing the next request. The fresh reader first loads
  on demand, preventing a startup read from being treated as the requested
  read. FileView writes start after leaving its load-completion handler.
  No-op saves do not wait for a nonexistent saved signal. External edits are
  adopted; same-path conflicts and malformed/non-object/read/write failures
  report through the existing saveFailed → Ui notification. Settings apply on
  successful commit. `config.mjs:mergeChange()` handles validation, preservation
  of unknown keys and semantic same-path comparison. `ShellCommands.setting()`
  says “change requested” rather than claiming a queued write was saved.
- `tour.mjs`: enabled gates auto-start only; readiness/output/lock/fullscreen
  still gate presentation, including manual replay. Registry availability in
  `Tour.qml` follows that policy. No new timers or production IPC.
- `cli.py:install_docs()` stages only README.md, docs/ALPHA.md,
  docs/CONFIGURATION.md and docs/COMMANDS.md. `install_core()` installs this
  manifest-owned bundle and prunes the former standalone README. The nested
  structure preserves relative links: `<root>/docs/README.md` and
  `<root>/docs/docs/{ALPHA,CONFIGURATION,COMMANDS}.md`. `Layout.docs` and
  `Paths.docsDir` agree for user data and packaged `/usr/share/aerolith` roots.
- New `tests/scenarios/config.sh` drives the real Config.setValue through a
  throwaway-shell probe, with the watcher deliberately disabled to reproduce
  missed replacement events. It uses the real installer atomic_write/os.replace.
  It covers unrelated CLI edits, unknown keys, queued/no-op/same-path saves,
  conflicts, malformed/non-object files, read/write failures and recovery.
- OLED scenario inspects actual visible text, selected fills, accents and
  borders on session/OSD/notice surfaces on both outputs. With LOCK=1 it also
  verifies both lock backings, exchanges output profiles to exercise the prompt
  on OLED, checks real PAM failure, keeps prompt/error colours at OLED idle,
  hides engraving, and authenticates normally. The config and OLED-lock
  regressions are wired into CI.

## Validation

Commands run from the worktree root. Headless scenarios were sequential; the
commands below use the same flags and output paths as CI.

| Command | Result |
| --- | --- |
| `node tests/js/run-node.mjs` | exit 0; 241 passed, 0 failed |
| `pytest -q tests/py` | exit 0; 314 passed, 1 skipped (72.29 s; luac is absent on the host) |
| `node tools/gen-config-doc.mjs --check` | exit 0; docs/CONFIGURATION.md up to date |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | exit 0; 227 passed, 0 failed |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/ci/smoke` | exit 0; smoke: ok |
| `LOCK=1 CONFIG=tests/fixtures/lock-config.json tools/headless/run.sh tests/scenarios/lock.sh build/ci/lock` | exit 0; lock: ok |
| `LOCK=1 LOCK_PAM=double CONFIG=tests/fixtures/lock-config.json tools/headless/run.sh tests/scenarios/lock-multistep.sh build/ci/lock-multistep` | exit 0; lock-multistep: ok |
| `tools/headless/run.sh tests/scenarios/session.sh build/ci/session` | exit 0; session: ok |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/osd.sh build/ci/osd` | exit 0; osd: ok |
| `CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh build/ci/notify` | exit 0; notify: ok |
| `AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/ci/oled` | exit 0; oled: ok |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/ci/tour` | exit 0; tour: ok |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/ci/multimonitor` | exit 0; multimonitor: ok |
| `tools/headless/run.sh tests/scenarios/config.sh build/ci/config` | exit 0; config: ok, including read/write failure recovery |
| `LOCK=1 AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/ci/oled-lock` | exit 0; oled: ok, including real PAM on OLED and standard profiles |
| `bash -n tests/scenarios/config.sh tests/scenarios/oled.sh tests/scenarios/tour.sh` | exit 0 |
| `git diff --check` | exit 0 |

All eleven final scenario logs have zero QML error-pattern matches (tour uses
its live-lifetime log); OLED-lock credentials are absent from qs.log. Audit:
`build/ci/p1-sol/qml-audit.txt`.

Local logs and probes are under `build/ci/` (not versioned); batch summaries
are in `build/ci/p1-sol/`. OLED captures include the standard-primary lock,
secondary OLED backing, OLED prompt/error at idle, and secondary standard
backing in `build/ci/oled-lock/lock-*.png`. The existing OLED run compares full
PPM pixels for the unaffected standard output and exact restoration, and
measures zero swaps over a three-second idle window. Overlay probes inspect
actual QQuickItem colours, omitting the unused Qt default black border pen;
Canvas drawing sources were inspected for profile-only colour inputs.

During development, regression failures exposed FileView preload/no-op and
load/write sequencing issues; these were corrected. An overlay probe initially
counted the unused default border pen; its correction was followed by a passing
run. Sway did not reliably route virtual keyboard input after moving a lock
prompt to the secondary output, so the final test exchanges output profiles
while keeping the prompt on the existing primary. An isolated probe established
successful PAM unlock after clearing the virtual-input buffer following the
simulated idle/resume sequence. No test hook exposes password text or bypasses
PAM. Only disposable shell copies contain probes.

## Package integration and remaining limits

The checkout has no PKGBUILD, package staging script or `tools/package` tree.
The packaged docs path and shared manifest-owned staging operation are provided
and tested at a temporary `/usr/share/aerolith` layout, including staging
update/prune/removal and preservation across per-user install/update/uninstall.
**Wiring the external package builder to `install_docs(source, package_root /
"docs", staging_manifest)` remains an integration requirement.** The per-user
installer deliberately retains its existing contract of never writing or
claiming ownership inside a package-owned `/usr/share` tree. No real package
was built or installed. A missing package-build entrypoint was raised with the
owner during work and recorded in the hub.

There is still a read/replace race with an independent writer between the fresh
read and the atomic write; the shell queue does not claim a shared-lock
concurrency guarantee. Real Hyprland, physical OLED and hardware/GPU behavior
were not tested; the harness uses Sway/software rendering and mock Hyprland.

## One peer review and one revision

Reviewed Astra's Phase 1 commit `9b6d480` once. Medium/P2 finding:
`RoutineConsole.qml:75,233` sends users to “Commands in the AEROLITH
documentation (Help)” for routines.json format/examples, but `HelpBay.qml`
contains the live command/key catalogue and tour action, with no offline docs
link or routine file format. Minimal correction: point the wording at
`Paths.docsDir + "/docs/COMMANDS.md"`, or add a Help action to open that file
through Exec argv. Published for Opus/Astra; those files were not edited here.
The alternatives are recorded for the single allowed revision/integration.
No further actionable findings in the inspected tour/diagnostics wiring.

Astra's review of this work found that ShellCommands.setting claimed “saved”
when a write had only been queued. Addressed in the one systems revision by
reporting “change requested.” Existing asynchronous failure notifications remain.

All work uses delegated Claude/P1-SOL reservations plus Sol locks for CI,
ShellCommands and this report. Opus retains ownership of delegated reservations;
Sol releases only Sol-owned locks. No cloud agent was dispatched.
