# F01 — GitHub Actions CI

Base: `d16e2230475bd9c62cc0f5eeb6a2965e4240fbcc`, branch `codex/coding-4c0d5695`, 2026-10-26 UTC. Worktree: `/root/.codex-mcp-bridge/worktrees/4c0d5695`. Owner: Sol; Opus review pending. No reviewer was dispatched. No product code, assertions or visual design changed; no commit made.

## Result

The workflow is implemented and passes actionlint and YAML validation. **It is not a green baseline:** both documentation generators require files absent from this checkout. The checks deliberately fail; nothing is skipped or weakened to hide this. See the review findings below.

## Job graph and choices

`fast (10 min)` and `dev-image (30 min)` run independently. Both must succeed before `headless (45 min)`. `fullscreen-matrix (30 min)` follows headless only on the Monday 04:23 UTC schedule or a manual dispatch with `fullscreen_matrix=true`. Ordinary push/PR runs include the single fullscreen scenario, not the long matrix. Push and pull_request have no branch filters. Concurrency cancels superseded runs of this workflow on the same ref.

The dev-image job builds `tools/devcontainer/Containerfile` with `tools/devcontainer` as context, loads tag `aerolith-dev`, and checks Qt V4 and shaders. Downstream jobs rebuild through the same `type=gha,scope=aerolith-dev` cache, with `mode=max` on export. This avoids transferring the local image's 4,448,313,549 uncompressed bytes as an artifact. The setup-buildx action supplies a current BuildKit with the GHA backend. This follows [Docker's cache guidance](https://docs.docker.com/build/ci/github-actions/cache/). Cache hits and cache permissions require a real GitHub run. No registry login is required.

All 17 headless steps execute sequentially, including the internal cells of notices-layout-matrix. Independent steps continue after a scenario failure, but cannot start without a successful image build. Each failed step uploads its own output directory with compression level 9 and a three-day retention; successful scenarios upload nothing. Step timeouts are 3 minutes normally, 8 for fullscreen, 15 for notices, and 25 for the optional fullscreen matrix. Job cancellation/timeout can prevent a final artifact upload.

Schema and configuration docs run in fast. Command docs must run in headless: `tools/gen-commands-doc.py:4–9` requires the live AI-enabled IPC catalogue, collected by `tests/scenarios/catalogue.sh:4–6`. There is no container-free command-catalogue exporter in this checkout. A checked-in snapshot would not detect changes to the live registration. Both generators are followed by scoped `git diff --exit-code` gates.

## Local environment and method

Node v22.22.0, Python 3.13.16, npm 10.9.4; pytest 8.4.2 installed in a repository-local venv. GitHub requests Node 22 and Python 3.12; the Python minor version differs locally. The host ran as root; hosted Ubuntu normally runs unprivileged, so skip counts can differ.

As explicitly permitted, **reused the existing `aerolith-dev:latest` image** with immutable ID `sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`. No fresh Containerfile build or local GHA cache export was claimed. Inside it: Qt 6.12.0, Quickshell 0.3.2; `/usr/lib/qt6/bin/qsb` belongs to qt6-shadertools 6.12.0-1, a dependency of qt6-5compat. `/dev/shm` was 64 MiB. No image or host configuration changed.

Local setup:

```bash
python3 -m venv build/F01/venv
build/F01/venv/bin/python3 -m pip install pytest==8.4.2
```

The proof runner loaded each job's `run` blocks directly from `.github/workflows/ci.yml`, in file order, and invoked `bash -e -o pipefail -c` in its specified working directory with `AEROLITH_DEV_IMAGE=aerolith-dev` and the venv prepended to PATH. No scenarios ran concurrently. It continued after failed blocks to exercise the remaining commands, including the optional matrix. GitHub will instead skip dependent jobs when fast fails. Action-only checkout/setup/build/cache/upload behavior cannot be reproduced by this shell proof. Raw logs and screenshots stay in ignored `build/F01/` and `build/ci/`, outside this handoff.

## Commands and results

Each table row is one workflow run block, in execution order. `<br>` denotes a literal newline. Exit status is for the entire block; `bash -e` stops a block at its first error.

| Job / step | Exact command | Exit | Wall seconds |
|---|---|---:|---:|
| fast/Node unit tests | <code>node tests/js/run-node.mjs</code> | 0 | 0.166 |
| fast/Python and installer unit tests | <code>python3 -m pytest -q tests/py</code> | 0 | 51.357 |
| fast/Generated schemes | <code>node tools/gen-scheme-themes.mjs --check</code> | 0 | 0.216 |
| fast/Generated config schema and docs | <code>node tools/gen-schema.mjs<br>node tools/gen-config-doc.mjs<br>git diff --exit-code -- shell/schema/config.schema.json docs/CONFIGURATION.md</code> | 1 | 0.117 |
| fast/Shell syntax | <code>while IFS= read -r -d '' script; do<br>  bash -n "$script"<br>done &lt; &lt;(find tests tools -type f -name '*.sh' -print0)</code> | 0 | 0.116 |
| fast/Whitespace | <code>git diff --check</code> | 0 | 0.066 |
| fast/Build Codex MCP bridge | <code>npm ci<br>npm run build</code> | 0 | 7.780 |
| dev-image/Qt V4 unit tests | <code>docker run --rm -v "$PWD:/src:ro" "$AEROLITH_DEV_IMAGE" bash -c \<br>  'cd /src &amp;&amp; QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'</code> | 0 | 0.769 |
| dev-image/Compiled shaders are current | <code>docker run --rm -v "$PWD:/src:ro" "$AEROLITH_DEV_IMAGE" bash tools/build-shaders.sh --check</code> | 0 | 1.321 |
| headless/smoke | <code>tools/headless/run.sh tests/scenarios/smoke.sh build/ci/smoke</code> | 0 | 5.595 |
| headless/full | <code>AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh tests/scenarios/full.sh build/ci/full</code> | 0 | 38.961 |
| headless/deck | <code>AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/ci/deck</code> | 0 | 25.739 |
| headless/notify | <code>CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh build/ci/notify</code> | 0 | 33.587 |
| headless/ai-claude | <code>AI=1 AUDIO=1 AI_PROVIDER=claude tools/headless/run.sh tests/scenarios/ai.sh build/ci/ai-claude</code> | 0 | 12.923 |
| headless/ai-codex | <code>AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh build/ci/ai-codex</code> | 0 | 12.367 |
| headless/osd | <code>AUDIO=1 tools/headless/run.sh tests/scenarios/osd.sh build/ci/osd</code> | 0 | 17.809 |
| headless/brightness | <code>BACKLIGHT=1 tools/headless/run.sh tests/scenarios/brightness.sh build/ci/brightness</code> | 0 | 6.996 |
| headless/brightness-unavailable | <code>BACKLIGHT=0 tools/headless/run.sh tests/scenarios/brightness.sh build/ci/brightness-unavailable</code> | 0 | 4.485 |
| headless/direction | <code>tools/headless/run.sh tests/scenarios/direction.sh build/ci/direction</code> | 0 | 9.970 |
| headless/installed | <code>AUDIO=1 INSTALL="--ai claude --startup hyprland" tools/headless/run.sh tests/scenarios/installed.sh build/ci/installed</code> | 0 | 15.686 |
| headless/installed-thears | <code>AUDIO=1 INSTALL="--ai claude --startup hyprland --direction thears --themes kitty,foot,hyprland" tools/headless/run.sh tests/scenarios/installed.sh build/ci/installed-thears</code> | 0 | 15.532 |
| headless/fullscreen | <code>AUDIO=1 CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/fullscreen.sh build/ci/fullscreen</code> | 0 | 141.919 |
| headless/app-themes | <code>APP_THEMES=1 tools/headless/run.sh tests/scenarios/app-themes.sh build/ci/app-themes</code> | 0 | 21.669 |
| headless/themes | <code>mkdir -p build/ci/themes<br>docker run --rm -v "$PWD:/src:ro" -v "$PWD/build/ci/themes:/out" "$AEROLITH_DEV_IMAGE" bash tests/scenarios/themes.sh /out</code> | 0 | 3.986 |
| headless/notices-layout-matrix | <code>tests/scenarios/notices-layout-matrix.sh build/ci/notices-layout-matrix</code> | 0 | 361.464 |
| headless/catalogue | <code>AI=1 tools/headless/run.sh tests/scenarios/catalogue.sh build/ci/catalogue<br>python3 tools/gen-commands-doc.py build/ci/catalogue/commands.json<br>git diff --exit-code -- docs/COMMANDS.md</code> | 1 | 4.382 |
| fullscreen-matrix/fullscreen-matrix | <code>tests/scenarios/fullscreen-matrix.sh build/ci/fullscreen-matrix</code> | 0 | 558.233 |

`npm ci` and `npm run build` run in `codex-mcp-bridge/`; all other blocks run at the repository root. The generators' subsequent diff gates are not reached when their input document is missing. Supplementary standalone scoped diffs are recorded below; a zero diff with a missing, untracked document is not evidence of doc freshness.

Unit counts: Node 135/135, Qt V4 135/135, pytest 219 passed / 1 skipped. Scheme freshness verified 446 generated files and 780 contrast pairs. Shader freshness checked all four material shaders. Shell syntax checked 23 scripts. OSD passed its available-device checks but skipped the microphone case because the headless session has no default input.

## Static validation

Built actionlint locally with all Go downloads/build caches under ignored `build/F01/` (no global installation):

```bash
GOPATH="$PWD/build/F01/go" GOBIN="$PWD/build/F01/go-bin" GOCACHE="$PWD/build/F01/go-cache" GOMODCACHE="$PWD/build/F01/go-mod" go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
build/F01/go-bin/actionlint .github/workflows/ci.yml
```

Result: actionlint v1.7.12, exit 0, no diagnostics. The first install attempt without a local GOPATH failed when Go tried to use an unavailable `/root/go/pkg/sumdb` path; setting GOPATH as above succeeded. Go selected and downloaded its required toolchain locally. ShellCheck was not installed on the host; separately validated every embedded `run` block with `bash -n` as well as the 23 repository scripts in the fast command.

YAML parse (host PyYAML 6.0.3; BaseLoader preserves the `on` key):

```bash
python3 - <<'YAML'
from pathlib import Path
import yaml
w = yaml.load(Path('.github/workflows/ci.yml').read_text(), Loader=yaml.BaseLoader)
assert set(w['on']) == {'push', 'pull_request', 'workflow_dispatch', 'schedule'}
steps = w['jobs']['headless']['steps']
runs = [s for s in steps if 'run' in s]
uploads = [s for s in steps if s.get('uses', '').startswith('actions/upload-artifact')]
assert len(runs) == len(uploads) == 17
assert all('failure()' in s['if'] for s in uploads)
print('YAML parsed; all four triggers; 17 sequential scenarios with 17 failure-only artifacts')
YAML
```

Result: exit 0. Action references are pinned by major version; token permissions are contents:read and checkout does not persist credentials.

## Review findings and proposed correction

This is the single review of the existing generator/harness work used by F01. Product code and assertions remain unchanged.

- **High — missing configuration reference.** `tools/gen-config-doc.mjs:47` unconditionally reads `docs/CONFIGURATION.md`, and line 50 requires its generated markers. The file is absent from both the working tree and tracked base. The fast block fails with `ENOENT`, after schema generation succeeds. Minimal proposed correction: restore/add the configuration reference with the BEGIN/END markers named at generator lines 9–10, run `node tools/gen-config-doc.mjs`, and commit the result in a documentation repair. Do not suppress the gate.
- **High — missing command reference.** `tools/gen-commands-doc.py:main`, line 84, unconditionally reads `docs/COMMANDS.md`; line 85 requires its generated markers. The file is absent from the tracked base. Minimal proposed correction: restore/add that reference with markers from generator lines 20–21, collect the live AI-enabled catalogue, run the generator and commit the result. This belongs with the same documentation repair. No revision was made to these out-of-scope inputs.

The fast failure means real CI will not reach headless until the docs are repaired. Local proof intentionally runs those scenarios anyway. Opus still needs to review the workflow; no approval or review dispatch is implied.

## First real GitHub run

Confirm Docker daemon access and Buildx GHA cache restore/export, cold Arch package downloads, disk capacity, current package/compiler compatibility, and read-only pull-request token behavior. Rebuild-from-cache does not pin the mutable `archlinux:latest` base or rolling packages; cache invalidation may change the environment and shader binaries. A future reproducibility task can pin the base or transfer an immutable image if exact identity across jobs becomes required.

Confirm the existing harness works on the hosted runner with Docker's default `/dev/shm`, SYS_NICE capability, headless sway/pixman, container UID 1000, PipeWire, and keyboard-injection timing. Local sequential passes cannot certify hosted timing or resource limits. Artifact upload, cancellation, scheduled execution (default branch only) and manual input gating also need GitHub itself. There is no capability probe that silently skips integration tests: runner incompatibility fails visibly.

The harness uses mocked Hyprland IPC and fake AI providers, with software rendering. It does not certify real hardware, real provider authentication, GPU pacing, VRAM use or a host installation. PipeWire RTKit/system-bus and unsupported Hyprland-protocol diagnostics are expected in these disposable containers. Pytest's local skip is the unavailable host `luac` check (`tests/py/test_installer.py:405`); installed/themes scenarios exercise native Lua/Hyprland parsers inside the image.

## Coordination and final checks

Read ROADMAP first. Shared hub reported `Claude_Integration_Phase`, owner `Sol`, no active locks; its task ID remained the older UI-016. The explicit F01 user assignment supplies task scope. All locks/publish/unlock commands target `/home/user/aerolith` with `--agent Sol --task-id F01`. Locked `.github/workflows/ci.yml` and `docs/verification/F01` before editing; additionally locked the three generated target paths before invoking generators. Only the workflow and this verification document are intended changes.


Final local proof: **25 of 27 workflow run blocks exit 0; two documentation blocks exit 1** for the missing references above. All 17 underlying scenario scripts passed, including the 61-command catalogue collection; its workflow block fails afterward in doc generation. Notices-layout-matrix: 15/15 cells, 20 geometry snapshots per cell. Optional fullscreen-matrix: 4/4 cells, 20 cycles each (80 total). The ordinary fullscreen scenario separately passed its 20 cycles. The matrix command took 558.233 seconds. Scanning 43 `qs*.log` files under `build/ci` found zero matches for the type/reference/syntax/assignment/binding-error patterns listed below. The only failed scenario-step artifact directory, catalogue, contains 22,893 bytes; successful scenario screenshots are never uploaded.

QML audit patterns: `ReferenceError`, `TypeError`, `SyntaxError`, `Binding loop`, `Unable to assign`, `Cannot assign`, `Error loading QML`.

Supplementary scoped diffs, after the failed generator blocks (both exit 0; neither proves a missing document is current):

```bash
git diff --exit-code -- shell/schema/config.schema.json docs/CONFIGURATION.md
git diff --exit-code -- docs/COMMANDS.md
```

Final whitespace checks: `git diff --check` exits 0. Each `--no-index --check` exits 1 because the file is newly added, with no whitespace diagnostics; these checks include both untracked files before bridge staging:

```bash
git diff --check
git diff --no-index --check /dev/null .github/workflows/ci.yml
git diff --no-index --check /dev/null docs/verification/F01/README.md
```

Completion is published as an implementation event with the two known failing checks, not as `tests_passed`; F01 locks are released afterward. Opus review and the first actual GitHub run remain outstanding.
