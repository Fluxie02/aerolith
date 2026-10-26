# UI-007 visual previews

`lock/`, `osd/`, and `session/` are complete snapshots of `shell/` with a
fixture-only `shell.qml`. Each root renders one standalone production view
with sample data. The PanelWindow in a preview is an ordinary overlay;
**the lock preview does not secure a session**. No host, service, config
library, schema, or AI code has been changed in the production tree.

From the repository root:

```bash
SHELL_PATH=prototypes/views/lock tools/headless/run.sh prototypes/views/capture.sh build/views-lock
SHELL_PATH=prototypes/views/osd tools/headless/run.sh prototypes/views/capture.sh build/views-osd
SHELL_PATH=prototypes/views/session tools/headless/run.sh prototypes/views/capture.sh build/views-session
# Repeat at a smaller logical resolution:
RES=1280x720 SHELL_PATH=prototypes/views/lock tools/headless/run.sh prototypes/views/capture.sh build/views-lock-small
```

For interactive use, `qs -p prototypes/views/lock` (or osd/session) and:

```bash
qs -p prototypes/views/lock ipc call preview setCase failed
qs -p prototypes/views/lock ipc call preview theme insane full false 1
qs -p prototypes/views/lock ipc call preview status
```

`theme` takes intensity, motion, lowEffects as `true`/`false`, and uiScale.
Scale 1.25 also exercises Noto Sans/Noto Sans Mono fallback. `status` reports
only event names and password length, never a credential. Preview activation
records an event without doing any session/audio/backlight work.

`capture.sh` is the reproducible state matrix and interaction verification.
Its case names are also accepted by `preview setCase`. Captures use full
motion, plus separate reduced, off/lowEffects and scaled literal-text cases.
Snapshots should be refreshed when production dependencies change; preserve
the fixture `shell.qml` when copying dependencies from `shell/`.
