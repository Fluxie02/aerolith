# A03 integrated-branch baseline

Tested commit: `c6ea2a89e10b94205e8816694ceb6a0e43b2a7e0` (from `git rev-parse HEAD`). Branch: `codex/coding-7bba1f29`. Date: 2026-10-26 UTC. No product or visual code changed.

The baseline passed: Node 118/118, Qt V4 118/118, pytest 71 passed / 1 skipped, and 12/12 baseline scenario runs. Two additional Codex runs reproduce known F02. No integration incompatibility was observed in these checks.

## Commands and results

Commands below ran sequentially in this order from the worktree root. Wall durations include Docker startup and cleanup. Each command had stdout and stderr redirected to `<name>.log`; `results.json` records the exact command, exit code and measured monotonic duration. Scenario counts refer to whole scenario runs, because these scripts do not report assertion totals.

| Run | Exact command | Exit | Passed / failed / skipped | Duration (s) |
|---|---|---:|---|---:|
| [node](node.log) | `node tests/js/run-node.mjs` | 0 | 118 / 0 / 0 | 0.093 |
| [qt](qt.log) | `docker run --rm -v "$PWD:/src:ro" aerolith-dev:latest bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 0 | 118 / 0 / 0 | 17.870 |
| [pytest](pytest.log) | `python3 -m pytest -q tests/py` | 0 | 71 / 0 / 1 | 19.338 |
| [smoke-saturated](smoke-saturated.log) | `CONFIG=docs/verification/A03/saturated.json tools/headless/run.sh tests/scenarios/smoke.sh build/A03/smoke-saturated` | 0 | 1 / 0 / 0 | 19.202 |
| [smoke-insane](smoke-insane.log) | `CONFIG=docs/verification/A03/insane.json tools/headless/run.sh tests/scenarios/smoke.sh build/A03/smoke-insane` | 0 | 1 / 0 / 0 | 5.548 |
| [full-saturated](full-saturated.log) | `CONFIG=docs/verification/A03/saturated.json AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/A03/full-saturated` | 0 | 1 / 0 / 0 | 38.725 |
| [full-insane](full-insane.log) | `CONFIG=docs/verification/A03/insane.json AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/A03/full-insane` | 0 | 1 / 0 / 0 | 37.639 |
| [deck-saturated](deck-saturated.log) | `CONFIG=docs/verification/A03/saturated.json AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" tools/headless/run.sh tests/scenarios/deck.sh build/A03/deck-saturated` | 0 | 1 / 0 / 0 | 24.767 |
| [deck-insane](deck-insane.log) | `CONFIG=docs/verification/A03/insane.json AUDIO=1 HYPR_MOCK_ARGS="--mode 2560x1440 --scale 1.5 --transform 1" tools/headless/run.sh tests/scenarios/deck.sh build/A03/deck-insane` | 0 | 1 / 0 / 0 | 24.886 |
| [notify-saturated](notify-saturated.log) | `CONFIG=docs/verification/A03/saturated.json tools/headless/run.sh tests/scenarios/notify.sh build/A03/notify-saturated` | 0 | 1 / 0 / 0 | 33.803 |
| [notify-insane](notify-insane.log) | `CONFIG=docs/verification/A03/insane.json tools/headless/run.sh tests/scenarios/notify.sh build/A03/notify-insane` | 0 | 1 / 0 / 0 | 32.808 |
| [ai-saturated](ai-saturated.log) | `CONFIG=docs/verification/A03/saturated.json AI=1 AUDIO=1 AI_PROVIDER=claude tools/headless/run.sh tests/scenarios/ai.sh build/A03/ai-saturated` | 0 | 1 / 0 / 0 | 20.158 |
| [ai-insane](ai-insane.log) | `CONFIG=docs/verification/A03/insane.json AI=1 AUDIO=1 AI_PROVIDER=claude tools/headless/run.sh tests/scenarios/ai.sh build/A03/ai-insane` | 0 | 1 / 0 / 0 | 20.439 |
| [installed-saturated](installed-saturated.log) | `CONFIG=docs/verification/A03/saturated.json AUDIO=1 INSTALL="--ai claude --startup hyprland" tools/headless/run.sh tests/scenarios/installed.sh build/A03/installed-saturated` | 0 | 1 / 0 / 0 | 16.869 |
| [installed-insane](installed-insane.log) | `CONFIG=docs/verification/A03/insane.json AUDIO=1 INSTALL="--ai claude --startup hyprland" tools/headless/run.sh tests/scenarios/installed.sh build/A03/installed-insane` | 0 | 1 / 0 / 0 | 16.304 |
| [ai-codex-saturated](ai-codex-saturated.log) | `CONFIG=docs/verification/A03/saturated.json AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh build/A03/ai-codex-saturated` | 1 | 0 / 1 / 0 | 12.067 |
| [ai-codex-insane](ai-codex-insane.log) | `CONFIG=docs/verification/A03/insane.json AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh build/A03/ai-codex-insane` | 1 | 0 / 1 / 0 | 12.076 |

## Configuration and evidence

Both configuration seeds are included: `saturated.json` and `insane.json`. They set `theme.intensity` and preserve the notify fixture’s server=true / popupTimeoutMs=5000 requirements. `tools/headless/run.sh:21,38` mounts and copies CONFIG into the disposable home. All six scenarios therefore ran at both intensities, including installed: `installer/aerolith_install/cli.py:469` (`install_config`) preserves an existing seed. Deck also used the documented rotated/scaled mock. No scenario assertion explicitly reports effective intensity; this coverage follows the inspected seed/config loading path (`shell/core/Theme.qml:23`).

Each run directory contains its complete `qs.log` and small raw harness artifacts; top-level logs contain command stdout/stderr. All 14 qs.log files were read in full by the audit, with every warning/error retained in `qml-audit.json`. No QML parse/type/reference/assignment/binding errors were found. Screenshots remain in ignored `build/A03/`; none are added here. Environment versions and immutable Docker image ID are in `environment.json`.

## Failure analysis and review findings

**F02 — (b) pre-existing failure, medium severity.** Both `AI_PROVIDER=codex` runs exit 1 at `tests/scenarios/ai.sh:13`: “no answer with 2 proposals”. Their qs.log files show “answer received (1 proposals)”; the bridge answered successfully. `tests/fixtures/fake-providers/codex:19` returns one media.play-pause proposal, whereas the Claude fixture supplies the two accepted proposals expected by the scenario. `ai.sh:18` additionally requires Claude-specific `--tools`, and `ai.sh:26` expects volume 0.25. All these lines originate in Claude’s systems commit `969107aa` (AI Bridge), already an ancestor of the pre-visual-merge first parent `57db8aa^1`. Neither merge `57db8aa` nor `44e687d` changes these files. Minimal proposed F02 fix: use matching volume/workspace proposal semantics for the Codex fixture and branch the lockdown assertion by provider, checking Codex’s read-only sandbox and tool-disable arguments. Left unchanged as requested; Codex approval/removal assertions after line 13 were not reached.

**Agent coordination — (c) harness problem, medium severity.** `tools/agent-sync/agent_sync.py:41` defines only Astra/Claude, and parser lines 408,419,425 restrict publish/lock/unlock to those names. The exact requested Sol commands all exit 2 before accessing/mutating hub state; see `coordination.json`. The two-agent definition originates in `a7e02e9a`, moved into tools by `9cf8c60`, and predates both integrations. The shared hub was read: system_state=Claude_Performance_Audit, current_owner=Claude, current_task_id=UI-016, no active locks. This does not match A03/Sol. Proceeded with the explicit user assignment in the isolated worktree; did not impersonate Astra or manually modify the hub. Minimal proposed fix under A04: add Sol consistently to sync roles, parser, workflow/review handling and tests, then assign A03 explicitly. Lock acquisition, remote completion publication and unlock could not run successfully; the completion evidence is local here.

**Container messages — (c) environment limitations, low severity.** Sway lacks hyprland-toplevel-mapping-v1 and hyprland_global_shortcuts_v1; the container has no system bus for UPower/RTKit and no realtime privileges. Smoke and notify intentionally omit AUDIO=1 and log a PipeWire-context connection error. Qt also logs keyboard-leave/text-input focus warnings on sway during otherwise passing interactions. These diagnostics originate in container dependencies, not repository QML source lines; their setup is `tools/headless/session.sh:28` (software/headless), `:58` (sway), `:89` (optional audio), and `tools/headless/run.sh:29` (container isolation). The harness dates to `e652f117` and `a49003a` before the visual merge. Minimal response: classify these known headless limitations explicitly; use AUDIO=1 if a scenario requires audio, and separately validate real Hyprland protocols/focus on a target session. No host changes proposed or made. Exact external Qt/compositor causation cannot be established from this run alone.

**Expected negative-test diagnostics (not failures).** Full logs warn about unknown action rm.rf because `tests/fixtures/routines.json:17` deliberately contains it (commit `a49003a`). Deck logs a config-save error because `tests/scenarios/deck.sh:113` makes CONFIG read-only and lines 115–119 assert recovery (commit `99985003`). Do not suppress or “fix” these product diagnostics.

**Pytest skip — (c) environment coverage gap.** `tests/py/test_installer.py:366` skips `test_lua_fragment_compiles` when host `luac` is absent; absence was verified with `shutil.which`. The installed scenarios independently exercise `luac -p` inside the dev image at `tests/scenarios/installed.sh:31`, and both pass. No packages were installed.

This is the single evidence-based review of the systems harness involved in A03. No revision was attempted because this task forbids product fixes; the actionable minimal corrections above are deferred to their owners. No (a) integration incompatibility was found.

## Limits and final checks

All requested test commands and both intensities completed. No real GPU/Hyprland session, hardware pacing/VRAM test, real provider authentication, Arch package installation, or host installation was attempted. The installed scenario tests checkout installation/removal inside the disposable container, not PKGS mode. A passing software-rendered baseline does not certify real hardware or visual appearance.

Only docs/verification/A03 evidence files were added; no commit was made. `git diff --check` passed (exit 0). Logs are small and no screenshots are included.

## Coordination command attempts

| Exact command | Exit | Duration (s) |
|---|---:|---:|
| `python /root/.codex-mcp-bridge/worktrees/7bba1f29/tools/agent-sync/agent_sync.py --repo /home/user/aerolith lock --agent Sol --files docs/verification/A03 --task-id A03` | 2 | 0.108 |
| `python /root/.codex-mcp-bridge/worktrees/7bba1f29/tools/agent-sync/agent_sync.py --repo /home/user/aerolith publish --agent Sol --type note --files docs/verification/A03 --summary "A03 verification complete: Node 118/118, Qt 118/118, Python 71 passed 1 skipped, twelve baseline scenarios passed; Codex F02 reproduced twice" --notes "Evidence docs/verification/A03/README.md; no product changes; Sol unsupported by this sync version" --task-id A03` | 2 | 0.154 |
| `python /root/.codex-mcp-bridge/worktrees/7bba1f29/tools/agent-sync/agent_sync.py --repo /home/user/aerolith unlock --agent Sol --task-id A03` | 2 | 0.135 |
