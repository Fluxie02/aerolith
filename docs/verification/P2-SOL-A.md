# P2-SOL-A — config transaction foundation

5 November 2026. Source implementation complete; real-QML acceptance blocked by
an unavailable Docker daemon. No commit made.

## Scope and API

- `shell/core/Config.qml`: committed `raw` / `committedData` remain separate
  from the appearance draft. `data` resolves the validated overlay for all
  existing consumers. `projectedData` includes queued immediate saves so two
  Settings presses in one event advance twice. `beginPreview()`,
  `setPreviewValues([{path, value}])`, `applyPreview()`, `cancelPreview()`,
  `previewActive`, `previewDirty`, `previewError`, `previewConflicts` and
  `previewApplying` form the transaction API. Mutations return an immediate
  error string (empty on acceptance); asynchronous save errors use
  `saveFailed` and preserve a retryable draft.
- `shell/lib/config.mjs`: explicit `PREVIEW_PATHS` appearance boundary, pure
  batch/overlay/transaction helpers, strict validation through existing
  `setPath`/`walk`, starting-value conflicts, immutable inputs, and structured
  map paths. Use `['display', 'outputs', 'DP.1', 'profile']` for a connector
  containing a literal dot; existing dotted paths remain supported.
- `setValues` validates the entire batch before queueing one request. Apply
  uses the existing fresh-read/rebase/atomic-write queue once for all draft
  leaves. Watcher reloads update committed raw and reapply the draft;
  same-path external changes remain exposed as conflicts. Cancel restores
  current committed data, including unrelated external edits.
- Immediate writes are refused while a preview is active. Beginning a preview
  waits for load and pending saves. Invalid edits retain the previous draft;
  restoring an effective starting value removes that leaf from the draft.
  Overlapping parent/child or duplicate paths within a batch are rejected.
- `SettingsBay.qml` uses projected values and the batch API. `ShellCommands.qml`
  does the same for settings commands and cancels drafts on lock/output loss.
  `Power.qml` cancels before external lock/session actions. An uncommitted draft
  is never persisted or propagated across process death/reload.
- `AppThemes.qml` observes the dedicated committed-change signal and committed
  scheme. `Telemetry.qml`, `Idle.qml`, and `Notifications.qml` use committed
  settings for external effects, including indirect strip/profile demand.
- No visual tokens, layout, typography, colour definitions or animation choices
  changed. No Personalize UI. SchemePicker remains unchanged. No Terra files
  changed. No new production timers or polling; the existing save-queue
  callLater boundaries and existing app-theme debounce remain.

## Checks

| Exact command | Result |
|---|---|
| `node tests/js/run-node.mjs` | 255 passed, 0 failed (final run) |
| `pytest -q tests/py` | 314 passed, 1 skipped, 78.48 s |
| `node tools/gen-config-doc.mjs --check` | exit 0; docs/CONFIGURATION.md up to date |
| `bash -n tests/scenarios/config.sh` | exit 0 |
| Python `ast.parse` over all 5 inline Python blocks in config.sh | passed |
| `git diff --check` | exit 0 |

Node coverage includes pure merge/overlay/allowlist/batch/conflict/cancel cases,
real Config JavaScript callbacks with controlled fresh-read/save completions,
failed Apply/retry, cancel before a read or deferred write, queued stepping,
committed-only app-theme observation, telemetry/idle/server isolation, and
session-action cancellation. These execute QML JavaScript with fakes; they do
not establish QML type/signal correctness or mapped-output behavior.

`tests/scenarios/config.sh` retains the Phase 1 atomic replacement/queue/I/O
regressions and adds real QML preview/Theme/mapped-output checks, no-draft disk
comparisons, rejected batches, rapid actual Settings row changes, Cancel,
one-write Apply, unseen CLI rebasing, conflicts, watched external changes,
failed Apply, fake app-theme CLI isolation, lock/output loss, and process-death
rollback. The optional stronger run uses `APP_THEMES=1 OUTPUTS=2`.

All following commands exited **1 before container startup**, and each was
retried once with the same result:

```sh
tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p2-sol/smoke
tools/headless/run.sh tests/scenarios/config.sh build/ci/p2-sol/config
APP_THEMES=1 tools/headless/run.sh tests/scenarios/app-themes.sh build/ci/p2-sol/app-themes
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/ci/p2-sol/deck
AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/ci/p2-sol/oled
tools/headless/run.sh tests/scenarios/direction.sh build/ci/p2-sol/direction
AI=1 tools/headless/run.sh tests/scenarios/catalogue.sh build/ci/p2-sol/catalogue
APP_THEMES=1 OUTPUTS=2 tools/headless/run.sh tests/scenarios/config.sh build/ci/p2-sol/config-preview
```

Failure: `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`.
`docker info` independently failed. No headless scenario actually ran.
Logs and machine-readable commands/results: `build/ci/p2-sol/` (untracked build
artifacts). No host daemon was started and no `/var/run` files were changed;
those actions are outside the repository-only writable scope.

## Review and remaining limits

Single integration review of the existing visual consumer seam:
`Theme.qml` derives its scheme/palette/geometry from Config.theme;
`DisplayProfile.qml` derives each surface's profile from Displays and Theme;
SchemePicker's selection continues through SettingsBay.apply. No additional
findings in that seam. Terra's parallel branch was not available in this
worktree for review, and its reserved files were not edited.

The independent-writer read/write race documented in SOL section 1 remains:
a CLI replacement *after* the fresh read and before the atomic write can still
be lost without a lock shared by CLI and shell. This implementation preserves
Phase 1's queue/atomic-write model, not cross-process mutual exclusion.
Cancel invalidates a queued/deferred Apply; once FileView.setText has submitted
an authorized atomic commit, cancellation cannot retract that write. A draft
without Apply never reaches disk. Lock/output tests cover shell-observed
lifecycle events; independent external-locker behavior and physical
Hyprland/OLED/GPU behavior remain unverified.

The new real-QML scenario, two-output preview propagation, QML bindings/signals,
app-theme subprocess behavior and actual atomic-write counts all still require
execution with Docker available before acceptance.

Coordination: published as Sol under P2-SOL-A. Opus's Claude reservation was
used as explicitly delegated. Additional Sol-owned service/test/evidence locks
are released on handoff; Opus's delegated reservations are left for Opus.
