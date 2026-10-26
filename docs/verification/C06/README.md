# C06 — Refresh opted-in application themes

Verified 26 October 2026 in `codex/coding-dee7670d`, worktree
`/root/.codex-mcp-bridge/worktrees/dee7670d`.
Base SHA: `fbca8db0665b0fb41968544b132223f9cd358146`.
These checks exercise uncommitted changes on that base. No implementation
commit was created; the bridge assigns its SHA after handoff.
Container: `aerolith-dev`, image
`sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`.
Logs are in ignored `build/C06/`.

## Scope and entry points

Read ROADMAP.md's Phase 2 gate and the C05 verification contract. Generated
assets, design tokens, SchemePicker, Config, Exec and the fullscreen lifecycle
are unchanged. `shell/shell.qml` changes only its systems-service registration.

- `installer/aerolith_install/cli.py:1067`, `cmd_themes`: adds refresh, JSON,
  dry-run and explicit scheme selection. Global refusal is JSON-compatible;
  errors/busy exit 2, interruption exits 130.
- `installer/aerolith_install/themes.py`, `refresh_plans`, `refresh_lock`,
  `refresh`, `activate`: C05 consent records select apps; the existing
  `prepare_app`/`execute` render/write payloads. No plan with an include edit,
  missing payload or changed payload-path set can execute. Refresh uses stored
  per-app direction and the new scheme, preserving config and marker bytes.
- `installer/aerolith_install/manifest.py:95`, `Manifest.load`: rejects malformed
  record containers/types, duplicate paths and invalid payload hashes. Older
  manifests without `themes` still load.
- `shell/services/AppThemes.qml`, `observe`/`refresh`: only saved schemes that
  agree with Config's applied state are eligible; startup establishes a baseline.
  One 1500 ms debounce and one in-flight process chain coalesce changes.
  `Config.reloaded` covers watched edits; `diskText` changes cover successful
  asynchronous saves. PATH discovery has a 1-second timeout, refresh 12 seconds.
  `ShellState.surfacesReleased` defers pending work until restore. Empty consent
  and a missing CLI produce no app-theme notice. Each nonempty result produces
  at most one summary through the existing notice API.
- `shell/services/ShellCommands.qml:100`: registers `settings.scheme` through
  the existing Config.setValue/IPC route, without editing the picker.

Global bad config/manifest, missing/invalid catalog and unknown schemes refuse
before even creating the lock file. Refresh re-reads ownership under a
nonblocking state-dir flock; contention reports busy. The empty lock inode
remains after unlock. Dry-run makes no lock, backup, write or activation.

Each changed app's old payloads are backed up persistently in
`$XDG_STATE_HOME/aerolith/backups/themes/`. Same-directory rollback copies of
payloads and manifest are staged before writing. `execute(persist=False)`
rechecks payload hashes and writes atomically; ownership commits once per app.
Caught failures restore that app's written files and previous manifest, even
when failure follows manifest replacement. SIGTERM (including Exec timeout)
and Ctrl-C use rollback before exit 130. Other apps may succeed when one fails.
Detected user edits are retained, never adopted as new owned hashes. Recovery
copies remain if rollback I/O itself fails, with their paths in the error.

JSON app statuses: `refreshed`, `unchanged`, `would-refresh`, `error`, with
`activation` or `error` per row. Unchanged payloads/scheme do not activate.
Runtime activation failure leaves the successfully committed payload in place
and reports next-start behavior in the app's activation text.

## Changed paths

```text
installer/aerolith_install/themes.py
installer/aerolith_install/cli.py
installer/aerolith_install/manifest.py
shell/services/AppThemes.qml
shell/services/ShellCommands.qml
shell/shell.qml
tests/py/test_installer.py
tests/scenarios/themes.sh
tests/scenarios/app-themes.sh
tools/headless/run.sh
tools/headless/session.sh
themes/README.md
ARCHITECTURE.md
docs/verification/C06/README.md
```

## Per-app activation

| App | Successful changed payload behavior | Compatibility / limit |
| --- | --- | --- |
| kitty | `pkill -USR1 -u UID -x kitty`, scoped to the caller; no matching processes means next start | [Current upstream docs](https://sw.kovidgoyal.net/kitty/conf/) confirm SIGUSR1 config reload; real rendering/reload untested here |
| Hyprland | `hyprctl reload`, only with a recorded Hyprland opt-in | Existing C05 Lua/hyprlang dialect and installed direction; no new global config; no running real compositor in the test |
| Alacritty | Own live reload when `general.live_config_reload` is enabled; otherwise next start | Existing explicit `[general].import`; C05 legacy/ambiguous forms still refuse |
| foot | Next start | C05's foot 1.26+ include requirement; native check passes |
| btop | Next start with aerolith selected | No btop.conf or selection edits |
| GTK 3/4 | Next start | Existing user overrides and sandbox/accessibility limits remain |
| qt5ct/qt6ct | Next start with palette/QSS and corresponding platform plugin selected | No preference or environment edits |

Runtime commands use argv, a 2-second timeout, and captured diagnostics. No app
is restarted or terminated. No third-party mod system is installed.

## Exact commands and results

Run from the worktree root. Headless scenarios run sequentially.

```bash
mkdir -p build/C06
python3 -m pytest -q > build/C06/pytest-full-final.log 2>&1
node tests/js/run-node.mjs > build/C06/node-final.log 2>&1
bash -n tests/scenarios/themes.sh tests/scenarios/app-themes.sh \
  tools/headless/run.sh tools/headless/session.sh
git diff --check
mkdir -p build/C06/themes
docker run --rm -v "$PWD:/src:ro" -v "$PWD/build/C06/themes:/out" \
  aerolith-dev bash /src/tests/scenarios/themes.sh /out \
  > build/C06/themes-final.log 2>&1
APP_THEMES=1 tools/headless/run.sh tests/scenarios/app-themes.sh \
  build/C06/app-themes-final > build/C06/app-themes-final.log 2>&1
APP_THEMES=0 tools/headless/run.sh tests/scenarios/app-themes.sh \
  build/C06/no-cli-final > build/C06/no-cli-final.log 2>&1
```

| Check | Result |
| --- | --- |
| Full pytest, including agent-sync | 236 passed, 1 skipped, exit 0 (36.52 s). Host lacks `luac`; native Lua parsing runs in the container. |
| Node | 135 passed, 0 failed, exit 0 |
| Bash syntax / diff whitespace | Exit 0 |
| Focused native container roundtrip | Exit 0: `themes: ok (PIYTI and THEARS; byte-exact uninstall)` |
| Fake-CLI headless shell | Exit 0: `app-themes: ok (debounce, empty consent, unrelated setting, fullscreen restore, config watch)` |
| Missing-CLI headless shell | Exit 0: `app-themes: ok (missing CLI is silent)` |
| QML log audit | No TypeError, ReferenceError, assignment/binding-loop, parse/load errors in either final headless log |

The Python refresh matrix covers all nine supported apps, two successive
schemes, unchanged include/config bytes, persistent backups, byte-exact full
uninstall, untouched/unactivated unconsented apps, user-modified payloads,
missing payload/include refusal, second-payload write failure with rollback,
manifest failure both before and after replacement, another app succeeding,
lock contention and later lock acquisition, dry-run and same-scheme idempotence,
unknown scheme, missing catalog, malformed config/manifest, a concurrent user
edit between planning and execution, activation argv/timeouts, Ctrl-C and SIGTERM.

The native scenario installs Iris with kitty/foot/Hyprland opt-ins in each
direction, refreshes to Corona, checks all refreshed payloads against the
installed catalog, compares all three user configs/markers byte for byte,
runs `foot --check-config`, `luac -p`, and `Hyprland --verify-config`, then
reapplies/removes and compares originals (including absent final newlines).
Both Hyprland logs say `config ok`. Runtime hyprctl reload reports unavailable
without a real session; payload refresh still succeeds. The kitty test has no
running kitty processes. These are parser/filesystem checks, not appearance
or live-reload claims.

The headless fake CLI checks exact argv and logs the saved scheme. The final
log contains exactly `bathyal`, `corona`, `iris`: one call for three rapid IPC
changes, one after two changes while fullscreen, one for a direct watched
config edit. Startup and an unrelated motion setting generate no call. No
refresh happens during release; waiting after each operation detects duplicates.
An empty app result generates no app-theme notice. The separate missing-CLI
run waits for the settings command's ordinary notice to expire before checking
silence. Both shell runs remain alive, with no QML engine errors.

Audit command (exit 0; also saved to `build/C06/qml-audit.json`):

```bash
python3 - <<'PY'
import json, re
from pathlib import Path
pattern = re.compile(r'TypeError|ReferenceError|Unable to assign|binding loop|Error:|failed to load', re.I)
counts = {}
for name in ('app-themes-final', 'no-cli-final'):
    path = Path('build/C06') / name / 'qs.log'
    matches = [line for line in path.read_text().splitlines() if pattern.search(line)]
    counts[str(path)] = len(matches)
    assert not matches, matches
Path('build/C06/qml-audit.json').write_text(json.dumps(counts, indent=2) + '\n')
print(json.dumps(counts))
PY
```

## Review, risks and limits

Reviewed the existing C05 renderer/include/removal contract and the other
engineer's Config.setValue/FileView-save and Exec.run timeout paths once.
No additional actionable finding outside C06's assigned scope. C06 accounts
for Config applying before asynchronous save and for Exec's SIGTERM timeout;
no changes to those shared files were needed. Opus's requested owner review
is pending; no external agent dispatcher was started or claimed.

The flock serializes refreshes only. C05 apply/remove, uninstall, app writers
and editors do not share it. Rechecks catch detected edits but cannot make an
uncooperating editor participate in an atomic compare-and-swap. Do not run
those writers concurrently. Atomic replacement prevents partial individual
files; SIGKILL, power loss, storage failure or failed rollback are not covered
by a multi-file crash transaction. Persistent backups remain available.
A refresh already started may finish if fullscreen begins; new work is deferred.
Unsupported C05 apps stay unsupported. Nonstandard include locations, app-local
overrides, toolkit plugins, accessibility and sandbox coverage retain C05's
limits. Runtime reload and visual appearance on real apps/Hyprland/GPU remain
unverified. Headless compositor behavior is mocked and software-rendered.
No visual assets, tokens, layout, typography, colours, animations, lifecycle,
host settings or global packages were changed. No commit was made.
