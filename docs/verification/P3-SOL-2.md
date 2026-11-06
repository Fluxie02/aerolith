# P3-SOL-2 — presets, deferred bay leave and cold-start config

5 November 2026. Worktree `codex/coding-8e9dfef0`; no commit made.
No tokens, layout, typography, colours, effects or animation definitions changed.

## Implementation and service contract

- `shell/lib/presets.mjs:56` (`validate`) accepts partial nested appearance
  values or `{formatVersion:1,name,values}`. It uses Config's `schemaAt`,
  `previewAllowed`, `validateConfig` (including its schema walk), and
  `prepareBatch`; validation errors and unknown keys are refusals, never
  substituted defaults. Unknown palette roles are refused too. Imports are
  bounded to 65,536 UTF-8 bytes, depth 12 and 1,024 entries; unsafe property
  names, nonfinite numbers, unsupported versions and nonappearance domains
  are refused. User stores also have a maximum of 64 presets and the same
  byte/depth/entry bounds. Full appearance snapshots can hit the byte/entry
  limit before 64 entries; the error reports the actual bound.
- `appearance()` / `encode()` export only schema-recognized, preview-allowed
  leaves. AI, routines, binds, installation direction, startup, commands and
  unknown settings are excluded. Portable save/export omits output overrides;
  `saveCurrent(name, true)` / `exportFile(path, true)` explicitly include them.
  Output paths are arrays, so `DP.1` is one exact name. Wildcards are refused.
  Supplied leaves override; omitted leaves survive; arrays/empty maps replace.
  Disconnected output overrides remain attached to their original name.
- `shell/services/Presets.qml:74` exposes `list()` returning
  `{id,name,builtin}` records, `preview(id)`, `saveCurrent(name)`, `remove(id)`,
  `importFile(path)` and `exportFile(path)`. Default and Readable are immutable.
  Readable chooses schema defaults with comfortable density, reduced motion
  and low effects. Saving captures effective `Config.data`, including a draft,
  and writes only `Paths.presetsFile` (`shell/core/Paths.qml:28`). It does not
  Apply the draft. Import previews without adding an entry to the user store;
  Save current is the explicit way to retain it. File operations accept
  absolute filesystem paths and return `Promise<string>`; empty means success.
  Preview returns that error string synchronously. `ready`, `busy`, `error`
  and `completed(action,ok,detail)` are available to the Settings owner.
  The service loads lazily, has no polling or timer, and refuses to overwrite a
  corrupt user store. Writes use a same-directory temporary and atomic replace.
- `Presets.stage()` installs a pre-write guard on imported drafts.
  `shell/core/Config.qml:197` captures it with Apply;
  `writeSave():251` awaits it after the fresh read/rebase, before `setText`.
  `Presets.backup():154` writes the exact fresh-read config snapshot to
  `Paths.stateDir/backups/<UTC stamp plus random suffix>/config.json`, matching
  `installer/aerolith_install/paths.py:64` and `cli.py:1226`'s location and
  filename scheme. A private collision-safe directory, file flush/fsync and
  successful completion precede the config write. Backup failure preserves a
  retryable draft and submits no write. Cancel invalidates a pending guard.
  Preview and cancelled imports create no backup. A no-op Apply creates no
  config write or backup. The installer itself is unchanged.
- `shell/core/Config.qml:22` publishes complete schema defaults as initial
  committed/effective/projected objects. `refreshData():25` replaces snapshots
  on raw, draft and queue changes and completion. Consumers are unchanged.
  Snapshot initialization removes dependencies on not-yet-initialized singleton
  properties. `projectedRaw()` tolerates an uninitialized queue during creation.
- `shell/modules/deck/Deck.qml:202` documents the optional bay protocol.
  `mayRetire():234` consults `requestLeave(destination)`; true permits retirement,
  false/undefined retains the current loader, demand, mapping and input.
  `leaveResolved(destination)` continues the matching pending request, and a
  newer request supersedes the old destination. Host tokens are `deck:<bay>`
  and `deck:close`. Restoring Ui is deferred out of `wanted`'s binding change
  handler to avoid reentrant binding evaluation. Host Escape, compositor close,
  lock, fullscreen suspension and output loss bypass the guard; forced
  retirement/destruction retains the existing draft-discard behavior.

## Settings owner handoff and one-pass peer review

**High — the existing SettingsBay still needs its adapter.** Evidence:
`SettingsBay.qml:14` routes only its own leave actions and
`:44` consumes Personalize's signal; it exposes no host method/signal.
`PersonalizePane.qml:91` already carries an opaque destination through its
three-choice dialog, including Apply completion. No Settings file was edited.
Minimal correction for Opus/Astra (no PersonalizePane change needed):

```qml
signal leaveResolved(string destination)
function requestLeave(destination) {
    if (!personalizing) return true;
    personal.requestLeave(destination);
    return false;
}
```

At the start of existing `completeLeave(destination)`, add:

```qml
if (destination.indexOf("deck:") === 0) {
    bay.leaveResolved(destination);
    return;
}
```

Retain existing internal `all` / `close` / bay routing after that check.
Do not pass a host token to `Ui.open()`. Keep editing emits nothing; later
host requests supersede the pending token. This adapter is required before
claiming that real Settings rail/backdrop/IPC navigation displays the dialog.
The generic host protocol is separately exercised with a deferring test bay.
One owner revision remains available; no repeated review cycle was performed.

Terra's parallel schema code was read once, without edits. Its
`previewAllowed()` honors per-leaf/map `preview: true`; the preset codec uses
that API, including future appearance maps instead of a fixed root list.
The new `workspaces.names` map therefore remains exportable after integration.
Combined runtime tests against Terra's unmerged files have not been claimed.

## Verification

The supplied `/home/user/aerolith/build/p3b/personalize-2/startup-qs.log` was
read: all ten reported undefined assignments occur at lines 44–53. The proposed
cyclic initialization mechanism is inferred from the derived bindings and
singleton dependencies, not a captured QML evaluation trace. What is verified
is the complete-default initialization change and repeated warning-free starts.
`tests/scenarios/smoke.sh:15` now preserves the original startup log and audits
it with Personalize's exact error regex:

```text
ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML
```

The presets headless probe exists only in a disposable shell copy and uses
base64 list arguments as `config.sh` does. It checks both built-ins and Cancel;
Save current then one-write Apply; persisted user presets; built-in immutability;
invalid/forbidden/unknown/bounded imports with errors and unchanged files;
portable and explicit-output exports; protected export path aliases; import
Cancel; exact backup bytes and pre-write existence/order; failed backup/retry
and distinct backup directories; Cancel during an awaited guard; user removal;
and refusal to overwrite a corrupt store. Eight pure unit test cases also
exercise structured connector paths, immutable inputs and all codec bounds.

The Deck scenario retains all existing AUDIO lifecycle tests, then adds a
throwaway deferring bay. It verifies demand/mapping retention, superseding
requests, rejection of a stale resolution, continuation, a real backdrop click,
host Escape, forced compositor-close path, lock and actual mock fullscreen
suspension. It checks both cold and instrumented logs with the strict regex.
An initial development run exposed a `wanted` binding loop caused by restoring
Ui inside its change handler; that failure was corrected and is not counted
as a passing run. Final acceptance results follow below.

Headless tests use sway/pixman and a Hyprland IPC mock. Physical GPUs, real
Hyprland compositor-close/output-removal focus behavior, and concurrent external
writers are not proven. Config's existing independent-writer read/write race
remains: a different writer replacing config after the fresh read and before
commit can still be lost without a shared lock. Once an authorized FileView
write is submitted, Cancel cannot retract it. Python file operations are
bounded and use argv, with the repository's existing `Exec` timeout mechanism.

Coordination used the shared hub. The explicit Sol systems assignment and
Opus's delegated P3-SOL-2 reservation supersede the stale UI-016/Astra role
metadata. Additional test/evidence/CI locks were acquired as Sol. Terra's CI
lock was respected; after Terra released it, presets CI was added after config,
away from Terra's schema-keys insertion before smoke. Opus's reservations are
left for Opus; only Sol-owned reservations are released. No cloud agent was
launched, no global package installed, and Docker was neither started nor
stopped/cleaned. Docker preflight returned `29.9.1`.

## Final acceptance commands and results

All headless scenarios ran one at a time, in the requested order. Default
output count is 1 unless shown. The `Killed` messages in disposable-copy
scenarios and Config's process-death test are intentional.

| Exact command | Result |
|---|---|
| `tools/headless/run.sh tests/scenarios/presets.sh build/ci/p3-sol-2/presets` | exit 0; presets: ok |
| `OUTPUTS=1 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-1-1` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=1 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-1-2` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=1 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-1-3` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=1 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-1-4` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=1 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-1-5` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-2-1` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-2-2` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-2-3` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-2-4` | exit 0; 0 cold-start regex matches |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-sol-2/smoke-2-5` | exit 0; 0 cold-start regex matches |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/ci/p3-sol-2/deck` | exit 0; deck: ok; deck leave: ok |
| `tools/headless/run.sh tests/scenarios/personalize.sh build/ci/p3-sol-2/personalize` | exit 0; personalize: ok |
| `tools/headless/run.sh tests/scenarios/config.sh build/ci/p3-sol-2/config` | exit 0; config: ok |
| `WELCOME=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/welcome.sh build/ci/p3-sol-2/welcome` | exit 0; welcome: ok |
| `node tests/js/run-node.mjs` | exit 0; 290 passed, 0 failed |
| `pytest -q tests/py` (first run) | exit 1; 388 passed, 1 skipped, 1 executable-mode failure |
| `pytest -q tests/py/test_installer.py::test_alpha_shell_scripts_are_executable_in_git` | exit 0; 1 passed after the mode correction |
| `pytest -q tests/py` (final rerun) | exit 0; 389 passed, 1 skipped in 173.28 s |

The first pytest run found tracked `tests/scenarios/personalize.sh` and
`tests/scenarios/welcome.sh` at mode 100644. Locks were acquired and only their
executable bits changed to 100755; their contents are unchanged. The new
`presets.sh` is also executable. The full suite was rerun after this correction;
its final result is recorded above. The initial failure remains available in
`build/ci/p3-sol-2/pytest-initial.log`.

Static checks each exit 0: `git diff --check`,
`bash -n tests/scenarios/presets.sh tests/scenarios/deck.sh tests/scenarios/smoke.sh`,
`node --check shell/lib/presets.mjs` and
`node --check tests/js/presets.test.mjs`. New-file whitespace was checked too.

Across 31 final QML logs there are zero unexpected matches to the strict
regex. One expected application warning is retained: Welcome deliberately
writes `{invalid` at `tests/scenarios/welcome.sh:182` and the state reader logs
`[aerolith:state] ignoring unreadable state file: SyntaxError: JSON.parse: Parse error`.
Welcome's own audit excludes exactly that fixture message. No undefined typed
assignment warning appears in any of the final logs. Headless unsupported
protocol/RTKit messages are not represented as zero total platform warnings.
The ten original smoke cold-start logs each have zero unfiltered matches.
Machine-readable audits are `build/ci/p3-sol-2/startup-audit.json` and
`qml-log-audit.json`; full scenario output and Node/pytest logs are in that same
ignored artifact directory.

## Files changed

- `shell/services/Presets.qml`: lazy service, bounded file operations and backup.
- `shell/lib/presets.mjs`: pure validation, portable export, built-ins and store codec.
- `shell/core/Paths.qml`: `presetsFile`.
- `shell/core/Config.qml`: complete initial snapshots and awaited import guard.
- `shell/modules/deck/Deck.qml`: documented optional leave protocol and forced bypasses.
- `tests/js/presets.test.mjs`, `tests/js/index.mjs`: eight cases registered for Node/Qt.
- `tests/scenarios/presets.sh`: disposable real-QML service/transaction acceptance.
- `tests/scenarios/deck.sh`: retained lifecycle suite plus generic leave acceptance.
- `tests/scenarios/smoke.sh`: original cold-start log audit.
- `.github/workflows/ci.yml`: presets and failure artifacts.
- `tests/scenarios/personalize.sh`, `tests/scenarios/welcome.sh`: executable bits only.
- `docs/verification/P3-SOL-2.md`: implementation, exact results, peer handoff and limits.
