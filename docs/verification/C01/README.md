# C01/C02 — Installation-only application direction

Verified on 26 October 2026 in `codex/coding-38c5b136`.
Base commit: `4f9944bad72557ba0a2b57c2fcea57555688fd7d`.
The checks below include the uncommitted C01/C02 changes on that base. No
implementation commit was created: the bridge assigns its SHA after handoff.
Container image: `aerolith-dev`, image ID
`sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`.

## Store decision

Use `$XDG_CONFIG_HOME/aerolith/installation.json`, with `direction` equal to
`piyti` or `thears`. The default path is
`~/.config/aerolith/installation.json`. This is per-user installation metadata,
outside `config.json` and its Settings schema, and outside the copied/packaged
shell tree that upgrades replace. It also avoids coupling the shell to the
installer's private ownership manifest.

`cmd_install()` reads and validates the existing JSON object before running
any install actions. An existing direction wins unless `--direction` is
explicit. A fresh interactive install asks, with PIYTI first and marked default;
Enter and non-interactive installs choose PIYTI. `Ui.choose()` only permits a
default when the caller supplies one; AI/startup choices retain their existing
requirements. Dry-run prints the direction without saving it.

The nested `install_direction()` preserves unrelated metadata keys, writes
atomically and records the file with manifest component/kind `config/config`.
It never writes the user's live `config.json`. Invalid JSON, empty files and
non-object JSON are refused, including with an explicit flag. An invalid
direction in otherwise valid metadata requires an explicit flag to repair it.
CLI status reads the store; an invalid direction value reports the PIYTI
fallback, while malformed JSON produces the usual actionable CLI error.

Uninstall follows existing configuration rules: keep for later reinstall by
default; `--remove-config` removes unchanged owned metadata, and `--force` is
needed for files modified since installation. No manifest format change is
needed. Packaged-shell setup writes only user metadata and preserves it on
reinstall without modifying the packaged tree.

`Config.qml` reads this file through an unwatched, blocking `FileView`.
`Theme.qml:29` is the only changed Theme line. Missing file/key selects PIYTI;
invalid values/JSON warn and select PIYTI. `Config.reload()` still reloads only
the live settings file. `ControlSurface.status()` exposes the actual running
Theme direction, independently of CLI status. Changing installation metadata
requires a shell restart to take effect.

`SettingsBay.buildRows()` enumerates `ConfigLib.SCHEMA`; that schema, the
generated JSON schema, Settings UI and `theme.intensity` code are unchanged.
C03 and application-theme deployment are outside this change.

## Checks and exact commands

All commands ran from the worktree root. Full local logs and headless outputs
are under the ignored `build/C01/` directory.

```bash
node tests/js/run-node.mjs
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
python3 -m pytest -q tests/py
tools/headless/run.sh tests/scenarios/smoke.sh build/C01/smoke-final
INSTALL='--ai claude --startup hyprland --direction thears' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C01/installed-thears-final
INSTALL='--ai claude --startup hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C01/installed-default-final
tools/headless/run.sh tests/scenarios/direction.sh build/C01/direction
AUDIO=1 tools/headless/run.sh tests/scenarios/fullscreen.sh build/C01/fullscreen-final
tests/scenarios/fullscreen-matrix.sh build/C01/fullscreen-matrix
bash -n tests/scenarios/direction.sh tests/scenarios/installed.sh tests/scenarios/fullscreen-matrix.sh
git diff --check
```

| Check | Result |
|---|---|
| Node | 130 passed, 0 failed; exit 0 |
| Qt V4 | 130 passed, 0 failed; exit 0 |
| pytest | 94 passed, 1 skipped; exit 0 (16.88 s). Skip: host has no `luac`; installed scenarios validate Lua in the container. |
| Smoke | `smoke: ok`; exit 0 |
| Installed THEARS | `installed: ok`; exit 0. Saved CLI and shell IPC status both report `thears`. AI request/removal and full uninstall pass. |
| Installed default | `installed: ok`; exit 0. Both statuses report `piyti`. AI request/removal and full uninstall pass. |
| Startup direction | `direction: ok`; exit 0. PIYTI default, THEARS after restart, no live switch in either direction after file edits plus `ipc reload`; invalid enum, null, array, broken JSON, empty and whitespace files warn/fall back; missing file is quiet. |
| Fullscreen | `fullscreen: ok`; exit 0. Twenty cycles, floating focus policy and the existing RSS check pass. RSS KiB at cycles 1/10/20: 162092 / 175072 / 157308. |
| Fullscreen matrix | Exit 1: PIYTI/Saturated passed; PIYTI/Insane failed at cycle 14, popup identity/count assertion. The matrix correctly stopped before either THEARS cell. See below. |
| Bash syntax / whitespace | Both exit 0 |

The pytest additions cover interactive Enter/explicit choice, flags and flag
rejection, default and explicit dry-run, reinstall and intentional change,
unrelated config/metadata preservation, corrupt JSON refusal before copying
files, invalid-value repair, text/JSON status, default/complete uninstall,
modified-file protection, and packaged mode/reinstall without package writes.
The installed scenario now checks `direction` from the actual running Theme
and verifies metadata removal. The matrix uses real installation in each cell;
the disposable patched THEARS source copy has been removed.

## Matrix notification failure

`build/C01/fullscreen-matrix/piyti-saturated.log` reports `fullscreen: ok`.
Its RSS KiB samples at cycles 1/10/20 are 156664 / 172532 / 156496; all 20
saved shell statuses report `direction: piyti`.

`build/C01/fullscreen-matrix/piyti-insane.log` ends with
`timeout: status.popups is 0, wanted 1` and
`FAIL: cycle 14: dismissing one id did not leave exactly one popup`.
Its saved cycle-14 status has `direction: piyti`, `phase: desktop`,
`surfacesReleased: false`, and `popups: 2` before the dismissal. The shell
log records the dismissal as successful. No source reload or QML error occurs
in this run. Expiry racing the assertion under software rendering is a
possibility, not a verified cause; notification/fullscreen runtime code and
test timing have not been changed.

The one isolated retry uses the same generated config and installer flags:

```bash
CONFIG=build/C01/fullscreen-matrix/piyti-insane.json SHELL_PATH=shell \
  AUDIO=1 HYPR_MOCK=1 MEDIA=0 AI=0 \
  INSTALL='--ai none --startup manual --direction piyti' PKGS= \
  tools/headless/run.sh tests/scenarios/fullscreen.sh build/C01/piyti-insane-retry
```

The isolated retry passed (`fullscreen: ok`, exit 0), including all 20 cycles
and the popup/focus checks. RSS KiB at cycles 1/10/20: 149920 / 158232 / 163376;
the existing sustained-growth test reports false. All 20 saved statuses report
`direction: piyti`. This confirms different outcomes for the same inputs,
without identifying the cause. The matrix's skipped THEARS cells must not be
described as passing; the separate installed-THEARS scenario did verify the
persisted choice reaches the running shell.

Review finding for Opus, **P2**, `tests/scenarios/fullscreen.sh:138`: the
popup identity/count assertion failed in one run and passed on one isolated
retry, with unchanged source/configuration. Evidence is the cycle-14 status
and dismissal log above. Minimal next correction: instrument popup deadlines
and assertion timestamps, then make the identity assertion independent of the
expiry deadline while retaining a separate expiry check. This is a proposed
test correction, not a verified notification-runtime defect. It remains
outside C01/C02; no timing or lifecycle patch was applied here.

## Earlier attempts and limits

The first installer-only pytest run had one expected-manifest assertion failure:
the retained configuration list needed the new `installation.json` entry. It
was updated, and the complete final suite passed. Two initial parallel command
launches raced creation of `build/C01`; their log redirections failed before
tests started. They were rerun after the directory existed.

The first fullscreen attempt used
`tools/headless/run.sh tests/scenarios/fullscreen.sh build/C01/fullscreen`.
Editing `Config.qml` while that source-based shell was running triggered
Quickshell's automatic source reload mid-scenario, causing empty IPC responses
and a cycle-2 Signal demand failure. Its log records `Reloading configuration`.
The final source was then kept fixed, and the clean `AUDIO=1` run above passed.

These are software-rendered sway tests with the Hyprland IPC mock and fake AI
provider. They verify installation and shell contracts, not actual Hyprland,
GPU/VRAM behavior, real provider authentication, or Arch upgrade execution.
Packaged mode is covered by pytest; no real package was installed for this task.
Expected harness warnings remain: unsupported Hyprland global shortcuts under
sway, missing RTKit/system bus, and PipeWire connection failures in runs without
`AUDIO=1`. These are distinct from QML engine errors.
Seventeen final/matrix/retry shell logs were audited using the QML-error
patterns from `fullscreen.sh`; zero matches. The local file list and results
are in `build/C01/qml-audit.json`.

One review of the existing other-agent contracts found no actionable defect in
the touched integration: `Manifest.record_file()` replaces existing ownership
entries, `remove_files()` protects modified files, `Config.setValue()/reload()`
stay on live config, and Settings rows come only from the schema. No service or
fullscreen lifecycle implementation changed. Independent Opus review remains
pending; no reviewer or cloud agent was dispatched.

Shared coordination used `--agent Sol --task-id C01` against
`/home/user/aerolith`. The owner's explicit C01/C02 assignment was recorded as a
note because the global hub workflow was already assigned to Astra's D03.
Unrelated D03 locks/workflow were preserved. Changed files were locked before
editing; the completion event and unlock are recorded in the shared hub.

## Changed paths

- `installer/aerolith_install/cli.py`, `paths.py`, `ui.py`
- `shell/core/Config.qml`, `Paths.qml`, `Theme.qml` (one seam line)
- `shell/modules/ControlSurface.qml` (status field only)
- `tests/py/test_installer.py`
- `tests/scenarios/direction.sh`, `installed.sh`, `fullscreen-matrix.sh`
- `README.md`, `ARCHITECTURE.md`, `docs/verification/C01/README.md`
