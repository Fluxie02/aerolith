# F02 — provider-aware AI scenario

Verified 2026-10-26 UTC by Sol in `codex/coding-7194fbb8`.
Base commit (`git rev-parse HEAD`): `57f6e7c6b483622e8513b4c2fb6d837be6927b77`.
Results cover that commit plus the uncommitted D05/F02 diff. No commit was
created; the bridge will assign the resulting commit SHA. D05 was completed,
published and unlocked before F02 was started and locked.

## Change and review

- `tests/fixtures/fake-providers/codex:19` now returns volume 25 followed by
  workspace 2, matching Claude's two accepted proposals. Both use Codex's
  strict `argsJson` schema. Claude's fixture and its intentionally rejected
  `shell.exec` proposal are unchanged.
- `tests/scenarios/ai.sh:14` branches on `AI_PROVIDER`. Read and reviewed the
  actual launch contracts in `ai-bridge/aerolith_ai/providers.py`:
  `Claude.build():220`, `Codex.build():292`, and `CODEX_DISABLED_FEATURES:39`.
  Claude still requires empty `--tools`, and now also checks JSON print mode,
  strict MCP configuration, no session persistence and disabled slash commands.
  There is no separate Claude sandbox argument in this adapter; none is invented.
  Codex checks `exec`, stdin `-`, read-only sandbox, ephemeral mode, ignored
  user configuration, skipped Git check, output schema, private working
  directory, no sandbox bypass and all six disabled tool features. Prompt
  privacy/context checks remain shared. Each provider's private working
  directory must have been removed after the request.
- `tests/scenarios/ai.sh:44` still requires volume **0.25** after approval,
  unchanged workspace for the unapproved proposal, and working volume **0.40**
  after AI removal. No Claude assertion was weakened.
- `tests/scenarios/installed.sh:64` checks status and independent provider CLI
  retention using the explicit `INSTALL --ai` selection. It previously
  hard-coded Claude at all three points. D05 parsing/removal checks remain.

This was one review of the relevant systems/provider code and fixtures;
no additional adapter correction was needed. `ai-bridge/`, `cli.py`, shell
code and visual design were read where relevant and left unchanged.
The separate Python unit-test fakes in `tests/py/conftest.py` retain their
existing media proposal case; the changed fixture is the headless CLI.

## Exact commands and results

Commands ran from the worktree root. All exited 0 except the preserved
initial Codex/Insane attempt described below.

| Exact command | Result |
| --- | --- |
| `python3 -m pytest -q` | **208 passed, 1 skipped**, 41.00 s; includes agent-sync tests. |
| `node tests/js/run-node.mjs` | **135 passed, 0 failed**. |
| `CONFIG=docs/verification/A03/saturated.json AI=1 AUDIO=1 AI_PROVIDER=claude tools/headless/run.sh tests/scenarios/ai.sh build/F02/ai-claude-saturated` | `ai: ok`. |
| `CONFIG=docs/verification/A03/saturated.json AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh build/F02/ai-codex-saturated` | `ai: ok`. |
| `CONFIG=docs/verification/A03/insane.json AI=1 AUDIO=1 AI_PROVIDER=claude tools/headless/run.sh tests/scenarios/ai.sh build/F02/ai-claude-insane` | `ai: ok`. |
| `CONFIG=docs/verification/A03/insane.json AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh build/F02/ai-codex-insane` | Exit 1, no request sent; see below. |
| `CONFIG=docs/verification/A03/insane.json AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh build/F02/ai-codex-insane-retry` | Isolated rerun: `ai: ok`. |
| `CONFIG=docs/verification/A03/saturated.json AUDIO=1 INSTALL='--ai codex --startup hyprland' tools/headless/run.sh tests/scenarios/installed.sh build/F02/installed-codex-saturated` | `installed: ok`. |
| `CONFIG=docs/verification/A03/insane.json AUDIO=1 INSTALL='--ai codex --startup hyprland' tools/headless/run.sh tests/scenarios/installed.sh build/F02/installed-codex-insane` | `installed: ok`. |
| `CONFIG=docs/verification/A03/saturated.json AUDIO=1 INSTALL='--ai claude --startup hyprland' tools/headless/run.sh tests/scenarios/installed.sh build/F02/installed-claude-saturated` | `installed: ok`. |
| `bash -n tests/scenarios/ai.sh tests/scenarios/installed.sh` | Passed. |
| `git diff --check` | Passed. |

Installed scenarios also passed real `luac -p` and `Hyprland --verify-config`
for both generated dialects, with the same dev image as D05 (Hyprland
0.56.2, Lua 5.5.1, image SHA in [D05](../D05/README.md)). The host's one
pytest skip is the absent host `luac`; the container covers that check.

Final AI coverage is four passing provider/intensity combinations. One
additional failed attempt is retained in `build/F02/ai-codex-insane/`:
`qs.log` contains neither a request-sent nor answer message, and no
`fake-provider.jsonl` exists. The same unchanged code passed when rerun
alone. A lost input/focus event under three concurrent software-rendered
containers is a possible explanation, not an established cause. This is
distinct from A03's one-proposal answer; no timing assertion was relaxed.

All eight qs.log files were scanned in full for QML type/reference/syntax,
assignment and binding errors: none found. `build/F02/*/log-audit.json`
retains every diagnostic line and answer count. Expected diagnostics are
missing Hyprland protocols/system bus/RTKit, unavailable backlight, and Qt
Wayland keyboard/text-input warnings. All seven successful runs logged one
answer with two proposals. Artifacts are in ignored `build/F02/`.

## Lockdown assertion negative checks

This exact additional command exercised the actual Python assertion block
in `ai.sh` against the recorded calls, without invoking any provider.
Result: **13 checks passed (2 valid, 11 rejected mutations)**.

```bash
python3 - <<'PY'
from pathlib import Path
import copy, json, os, subprocess, sys
source = Path('tests/scenarios/ai.sh').read_text()
check = source.split('<<\'PY\' || fail "provider invocation not locked down"\n', 1)[1].split('\nPY\n', 1)[0]
log = Path('build/F02/lockdown-check.jsonl')
checks = 0
for provider in ('claude', 'codex'):
    original = json.loads(Path(f'build/F02/ai-{provider}-saturated/fake-provider.jsonl').read_text().splitlines()[-1])
    variants = [('valid', original, True)]
    if provider == 'claude':
        bad = copy.deepcopy(original)
        bad['argv'][bad['argv'].index('--tools') + 1] = 'Bash'
        variants.append(('enabled-tools', bad, False))
        for flag in ('--strict-mcp-config', '--no-session-persistence', '--disable-slash-commands'):
            bad = copy.deepcopy(original)
            bad['argv'].remove(flag)
            variants.append((f'missing-{flag}', bad, False))
    else:
        bad = copy.deepcopy(original)
        bad['argv'][bad['argv'].index('--sandbox') + 1] = 'workspace-write'
        variants.append(('writable-sandbox', bad, False))
        for feature in ('shell_tool', 'apps', 'plugins', 'browser_use', 'computer_use', 'in_app_browser'):
            bad = copy.deepcopy(original)
            i = bad['argv'].index(feature)
            del bad['argv'][i-1:i+1]
            variants.append((f'enabled-{feature}', bad, False))
    for name, call, expected in variants:
        log.write_text(json.dumps(call) + '\n')
        result = subprocess.run([sys.executable, '-c', check, str(log)], env={**os.environ, 'AI_PROVIDER': provider}, capture_output=True)
        assert (result.returncode == 0) == expected, (provider, name, result.stderr.decode())
        checks += 1
log.unlink()
print(f'{checks} lockdown checks passed (2 valid, {checks-2} rejected mutations)')
PY
```

## Coordination and limits

Published F02 start/completion as `--agent Sol --task-id F02`, with locks on
the three changed fixture/scenario files and this evidence directory,
through `python tools/agent-sync/agent_sync.py --repo /home/user/aerolith`.
Locks were released after completion. No commit or remote review was dispatched.

Fake providers establish emitted arguments, parsing, review/approval and
removal behavior, not real provider authentication or sandbox enforcement.
No real provider was contacted, no credentials accessed, no packages
installed and no host configuration changed. Sway software rendering is
not evidence of real Hyprland animation, GPU pacing or hardware behavior.
