# ALPHA2-SOL-B runtime fixes

Worktree base: `40be1ef`, branch `codex/coding-5352c160`. The owner's report was
read before code changes. Work used the explicitly delegated Claude locks as
`Sol`; no lock/unlock commands, commits, visual changes or installer edits.
The global hub workflow still named UI-016/Claude, so the owner override was
recorded in a sync note.

| Finding | Result and evidence |
|---|---|
| 4, Claude context and model | Fixed in `Claude.build()` in `ai-bridge/aerolith_ai/providers.py`: empty `--setting-sources`, `--safe-mode`, and `--model haiku` unless explicitly configured. Installed Claude Code 2.1.310 `--help` documents both flags; safe mode separately disables CLAUDE.md discovery, hooks and installed plugins while retaining authentication. `data_flow` describes isolation and model choice. Fake-provider tests assert the actual argv and explicit model override. No fallback to `--settings` was needed for this installed CLI. |
| 4, Codex audit | Found another leak: an offline Codex 0.163.0 invocation with a throwaway HOME, synthetic global AGENTS.md and fake credentials still sent that marker to a loopback endpoint with `--ignore-user-config`, `--ignore-rules` and `project_doc_max_bytes=0`. Empty instruction overrides did not suppress it. The adapter now refuses before spawning when global instruction files or nonempty skill directories exist. It reads metadata, not their contents or credentials. Hooks and memories are disabled; project documentation and execpolicy rules are disabled. Four regression cases failed before this guard and pass afterwards. Repeated installed-CLI probe after the guard: **0 requests**, marker not sent. |
| 2b, external session lock | Fixed in `Power.lockExternal()`: check this user's hyprlock/swaylock/hypridle/swayidle/xss-lock/light-locker processes before loginctl. Otherwise call the standard ScreenSaver Lock interface directly; an absent or failed owner gives a clear Registry failure with setup guidance. Built-in lock confirmation remains unchanged. Node tests cover absent/present listeners, ScreenSaver, loginctl failure and built-in lock refusal. Headless runtime verifies the no-locker failure. |
| 10, notifications | Fixed in `Notifications.qml`'s `onNotification`: dismiss objects evicted from the 100-item list. Existing close handlers remove popups and expiry entries. Node tests cover three successive evictions; the D-Bus scenario verifies NotificationClosed reason 2 reaches an evicted sender. |
| Low, next/previous | Fixed in `Compositor.adjacentWorkspace()`: numbered stepping preserves its old bounds; a nonpositive ID enters the existing numbered range at its lowest ID for Next and highest ID for Previous. Empty range falls back to 1. Tested for -98 and -1337 in Node and the headless Hyprland mock. This explicitly defines entry direction because named/special IDs have no numbered position. |
| Low, negative Navigator focus | **Finding does not apply to this checkout.** `Compositor.workspaces` already skips IDs <= 0 and `SpatialNavigator.sectors` skips windows on such workspaces. Added a regression exercising both production binding bodies with negative IDs; no production change. Named/special workspaces remain skipped. |
| Low, IPC run result | **Not fixed.** `ControlSurface.qml:40` still returns `started` after queuing Registry work. Quickshell's IpcHandler accepts scalar return types, and IpcFunction::invoke invokes the QML method synchronously. Returning a Promise from `run(): string` cannot deliver its eventual result, and blocking the QML thread would prevent Registry completion/timers. A direct five-second wait needs upstream asynchronous replies or a separate request/result client protocol. No speculative API or blocking workaround added. |
| Low, desktop-entry expansion | Fixed in `buildLaunchArgv()` in `shell/lib/launch.mjs`: remove embedded field codes and expand %% once. Tests cover --url=%u, embedded %F, %%u, literal percents and empty arguments. |
| Low, Exec lifecycle/output | Fixed in `Exec.qml`: FailedToStart's runningChanged(false) settles immediately; SplitParser with an empty marker drains arbitrary chunks while retaining at most 65536 UTF-16 code units per stream (or a smaller maxOutput). Process flushes both parsers before exited. Node tests exercise failed-start handling and in-flight retention; the windowless headless probe verifies prompt missing-program failure, 2 MiB on each stream, final unterminated stderr and exit status 7. |
| 8, LibreOffice archive | Fixed the documented zipfile command to pass META-INF as a directory; added zipfile -l and the expected full path. Pytest executes that documented command and lists its archive, asserting META-INF/manifest.xml and the other required entries. It failed with root-level manifest.xml before the change. |
| qmllint crash | **Not reproduced; unchanged.** Container qmllint 6.12.0 exits 0 on original ControlSurface.qml, both directly and with generated qs module metadata. Warnings remain, including unresolved base/inline shortcut types and the existing comma expression. No crash-causing construct was established, so no speculative rewrite was made. |
| Ruff | Bound x0/w/y0/h in the plotting lambdas' defaults. The AST regression retains each panel's functions and fails before the fix; no generated plot or visual design changed. All four B023 findings are gone. Installer B007 remains at themes.py:309 as explicitly requested. |

## Checks

Final results after production changes:

```text
python3 -m pytest -q tests/py
267 passed, 1 skipped

node tests/js/run-node.mjs
153 passed, 0 failed

node tools/gen-config-doc.mjs --check
docs/CONFIGURATION.md is up to date

docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
145 passed, 0 failed (the additional QML-source mock suite is Node-only)

bash tools/headless/run.sh tests/scenarios/runtime.sh build/alpha-runtime/headless-runtime
exit 0, runtime: ok

CONFIG=tests/fixtures/notify-config.json bash tools/headless/run.sh tests/scenarios/notify.sh build/alpha-runtime/headless-notify
exit 0, notify: ok

bash tools/headless/run.sh tests/scenarios/smoke.sh build/alpha-runtime/headless-smoke
exit 0, smoke: ok

AI=1 AUDIO=1 AI_PROVIDER=claude bash tools/headless/run.sh tests/scenarios/ai.sh build/alpha-runtime/headless-ai-claude-audio
exit 0, ai: ok

AI=1 AUDIO=1 AI_PROVIDER=codex bash tools/headless/run.sh tests/scenarios/ai.sh build/alpha-runtime/headless-ai-codex
exit 0, ai: ok

docker run --rm -v "$PWD:/src:ro" aerolith-dev /usr/lib/qt6/bin/qmllint /src/shell/modules/ControlSurface.qml
exit 0 with warnings; no crash

docker run --rm -v "$PWD:/src:ro" aerolith-dev /usr/lib/qt6/bin/qmllint \
  -I /src/build/alpha-runtime/lint-imports /src/shell/modules/ControlSurface.qml
exit 0 with warnings; no crash (generated qmldir metadata in a disposable shell copy)

ruff check docs/design/smooth/summarise-positions.py --select B023
exit 0, All checks passed!

ruff check installer/aerolith_install/themes.py --select B007
exit 1, the one known B007 at line 309; untouched

bash -n tests/scenarios/ai.sh tests/scenarios/runtime.sh tests/scenarios/notify.sh
exit 0

git diff --check
exit 0
```

Before fixes, the Python provider/archive/closure checks failed in four cases;
the Node suite failed on expansion, absent-locker handling, ScreenSaver handling,
workspace stepping, notification eviction and missing Exec failure handling.
The later four global-Codex-context cases also failed before their guard.

Docker was initially unavailable and later became available without host changes
by this job. All headless runs were sequential. Runtime, notification and smoke
logs have no ReferenceError, TypeError, binding-loop or assignment errors;
the container's missing real audio/power/global-shortcut services give expected
environment warnings. Captures, logs and the installed-CLI offline probe are in
`build/alpha-runtime/` (ignored artifacts).
An initial extra Claude AI scenario invocation omitted its documented AUDIO=1
prerequisite and failed at proposal approval; the corrected command above passed.

## Changed paths

- `ai-bridge/aerolith_ai/providers.py`
- `shell/core/Exec.qml`
- `shell/lib/launch.mjs`
- `shell/services/Compositor.qml`
- `shell/services/Notifications.qml`
- `shell/services/Power.qml`
- `docs/design/smooth/summarise-positions.py`
- `docs/design/thears-piyti/APP-FORMATS.md`
- `docs/verification/ALPHA2-SOL-B.md`
- `tests/js/launch.test.mjs`
- `tests/js/run-node.mjs`
- `tests/js/runtime-qml.test.mjs`
- `tests/py/conftest.py`
- `tests/py/test_ai_bridge.py`
- `tests/py/test_runtime_docs.py`
- `tests/scenarios/notify.sh`
- `tests/scenarios/runtime.sh`
- `tests/scenarios/ai.sh`

## Limits and review

- Codex refuses homes with global instruction files or any global skill entries,
  including bundled skill directories if present. This is deliberately
  conservative; the bridge does not move/read authentication files or alter the
  user's global context. A dedicated environment must isolate both CODEX_HOME
  and HOME/.agents/skills; changing only CODEX_HOME does not hide the latter.
- Provider tests establish argv and refusal behavior; they do not make paid model
  calls. Older Claude versions must support the verified flags or fail normally.
- An idle-listener process can exist with an incomplete locker configuration.
  External success still means **Lock requested**, never compositor-confirmed
  **Locked**. Real Hyprland/logind locking was not invoked; headless workspace
  tests use the repository IPC mock.
- The output cap counts JavaScript string units. Arbitrary chunk boundaries may
  split UTF-8 input in Quickshell's SplitParser decoding; byte-perfect Unicode
  streaming remains a limitation of this approach.
- IPC completion replies remain outstanding. qmllint warnings remain and its
  reported crash could not be reproduced with the available version.
- Reviewed merged ALPHA2-ASTRA once, read-only. Published a Medium finding:
  `Theme.qml:167-172` consumes lastIpcObject geometry, while
  `ShellState.qml:118` omits changefloatingmode and has no resize-only refresh.
  Minimal proposed revision: add that event and verify uncovered resize refresh;
  if Hyprland has no resize event, record the limitation or agree a bounded
  refresh policy. One revision invited through the hub; no change to that task.

Sources checked for API constraints: [Quickshell IPC return types](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/),
[Process signal ordering](https://raw.githubusercontent.com/quickshell-mirror/quickshell/master/src/io/process.cpp),
[SplitParser chunk behavior](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/SplitParser/),
and [OpenAI configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).
