# B05 fullscreen coverage — blocked on focus restoration

Tested product commit: `697b3da66b182c38e0d32a7378f5561460993328`
(`git rev-parse HEAD`), branch `codex/coding-722bc396`, 2026-10-26 UTC.
Tests and mock changes were uncommitted worktree changes on that SHA. No
`shell/` product file or visual design was changed. Docker image:
`sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`.

**B05 is not passed.** PIYTI/Saturated completed the twenty stress cycles,
then reproduced a lifecycle defect when a floating non-fullscreen window
took focus on the same workspace. Work stopped for Opus's review as requested;
no lifecycle correction was attempted. Smoke and Deck passed. The complete
four-cell runtime matrix and hardware verification remain outstanding.

## Reproduction and single review finding

**High severity — shell stays suspended after focus leaves the fullscreen game.**
`shell/lib/shellstate.mjs:56-61`, function `outputFullscreen()`, returns true
for any mapped fullscreen client on the selected output's active workspace,
even when a different, non-fullscreen floating window has focus.
`shell/services/ShellState.qml:38-65`, function `snapshot()`, supplies no
active-client identity. The existing `activewindowv2` refresh trigger at
`:118` cannot repair this selection rule.

Exact headless reproduction (the new case is at
`tests/scenarios/fullscreen.sh:182-190`): open a normal game and a floating
dialog on workspace 1; focus the game; set its fullscreen mode to 2; wait for
`surfacesReleased=True`; focus the dialog without changing the game's mode.
The scenario waits three seconds for `phase=desktop` and fails:

```text
timeout: status.phase is suspended, wanted desktop
FAIL: focus on a non-fullscreen floating window: not restored
```

The recorded mock state and shell status agree that focus moved:

| Field | Game | Focus target |
|---|---|---|
| address | `0x5a0000000820` | `0x5a00000009c0` |
| workspace | 1 | 1 |
| fullscreen | 2 | 0 |
| floating | false | true |
| focusHistoryID | 1 | 0 |

Shell status still has `activeWindow="B05 focus target"`,
`fullscreenOwner="steam_app_1"`, `phase="suspended"`,
`surfacesReleased=true`, `ambient=false`, `telemetryIntervalMs=0`.
See [mock state](piyti-saturated/focus-other-mock.json),
[shell status](piyti-saturated/focus-other-status.json),
[IPC events](focus-events.jsonl), and [scenario output](piyti-saturated/scenario.log).
The refocus-to-game assertion is present but was not reached because the
restore assertion failed first.

Minimal proposed correction, **for Opus to approve and implement**: pass the
active client identity from `Compositor.activeToplevel` (which already has a
`focusHistoryID` startup fallback in `shell/services/Compositor.qml:35-46`)
into `snapshot()`. Make `outputFullscreen()` yield no fullscreen owner when
another non-fullscreen client on that workspace has focus, and select the
game again on refocus. Normalize address representation, retain the selected
output/special-workspace rules, and preserve the Deck-only wake policy.
Add pure-logic focus regression cases alongside the existing shellstate tests.
This is the one review of Opus's lifecycle work; no revision was applied here.

## Mock conformance

The only mock additions are `open(..., floating=true)` and control operation
`focus_window`, reusing `Mock.focus_window()` rather than inventing a new
fullscreen transition. The focus case deliberately uses a floating client:
Hyprland v0.56.2's `onFullscreenWorkspaceFocusWindow()` permits floating
focus over fullscreen without clearing the game's fullscreen mode, whereas
tiled focus depends on `misc:on_focus_under_fullscreen`.
[Upstream focus handling, lines 27-60](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/desktop/state/FocusState.cpp#L27-L60).

The mock emits `activewindow>>CLASS,TITLE`, then
`activewindowv2>>ADDRESS` (without `0x`) and maintains `focusHistoryID=0` for
the active client. It retains `fullscreen=2` on the game and `fullscreen=0`
on the floating target; focus emits no synthetic `fullscreen` event.
The events are documented by the [Hyprland IPC interface](https://wiki.hypr.land/IPC/)
and emitted by [FocusState.cpp:188-189](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/desktop/state/FocusState.cpp#L188-L189).
JSON fields `workspace.id`, `mapped`, `floating`, `fullscreen`,
`fullscreenClient` and `focusHistoryID` come from
[HyprCtl.cpp:354-403](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/debug/HyprCtl.cpp#L354-L403);
`fullscreen` is the internal mode, distinct from the client's requested mode.
The two new Python tests verify valid/invalid focus, both focus directions,
event payloads, history, and preservation of fullscreen mode.

## Exact commands and results

Commands ran from `/root/.codex-mcp-bridge/worktrees/722bc396`.
Long output was redirected into ignored `build/B05/`; compact raw evidence
is retained here. An initial Docker image inspection could not connect to
the daemon; a later inspection and the scenario containers succeeded without
any host/system change.

| Command | Result |
|---|---|
| `bash -n tests/scenarios/fullscreen.sh tests/scenarios/fullscreen-matrix.sh` | exit 0, including final scripts |
| `python3 -m pytest -q tests/py/test_mock_hyprland.py >build/B05/mock-tests.log 2>&1` | exit 0; 2 passed; final repeat also 2 passed |
| `node tests/js/run-node.mjs >build/B05/node-tests.log 2>&1` | exit 0; 129 passed / 0 failed |
| `tests/scenarios/fullscreen-matrix.sh build/B05/matrix >build/B05/matrix.log 2>&1` | exit 1; first cell reaches focus defect after all 20 cycles; matrix incomplete |
| `CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/smoke.sh build/B05/smoke >build/B05/smoke.log 2>&1` | exit 0; `smoke: ok` |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/B05/deck >build/B05/deck.log 2>&1` | exit 0; `deck: ok` |
| `git diff --check` | exit 0 |
| `git diff --numstat -- shell/` | no output; product tree unchanged |

For each cell, the runner generates CONFIG from
`tests/fixtures/notify-config.json`, preserving `notifications.server=true`
and `popupTimeoutMs=5000`, adding `theme.intensity` and
`navigator.thumbnails=true`. Its exact inner command is:

```bash
CONFIG="$config" SHELL_PATH="$shell_path" AUDIO=1 HYPR_MOCK=1 \
  MEDIA=0 AI=0 INSTALL= PKGS= \
  tools/headless/run.sh tests/scenarios/fullscreen.sh "$out/$cell" \
  >"$out/$cell.log" 2>&1
```

PIYTI uses `SHELL_PATH=shell`. THEARS uses a disposable
`build/b05-shell.XXXXXX/thears` copy, with only Theme's default
`property string applicationDirection: "piyti"` replaced by `"thears"`.
No direction config key was added. The initial runner's temporary directory
had mode 700, so both THEARS attempts reported `no shell.qml` before Quickshell
started. The final runner corrects this to 755 for the container's pilot user
and stops on the first failed cell. These runner fixes were syntax checked;
they were not followed by another live matrix after the lifecycle stop.

The old runner had already advanced into PIYTI/Insane by the time the first
failure was read. That cell was stopped with:

```bash
for container in $(docker ps --filter volume="$PWD/build/B05/matrix/piyti-insane" --format '{{.ID}}'); do
  docker stop -t 5 "$container"
done
```

It exited 143 after six recorded cycles. The initial runner then attempted
both THEARS cells, which failed at the directory access check described above.
[results.tsv](results.tsv) and [matrix.log](matrix.log) retain those original
outcomes. Neither THEARS result is a lifecycle result.

## RSS and observed coverage

RSS is read from `/proc/$QS_PID/status` (VmRSS), using the actual background
shell PID from `tools/headless/session.sh:147`, after restoration, closed Deck,
zero audio detail demand, and 5000 ms telemetry. Values are KiB.

| Direction | Intensity | Cycle 1 | Cycle 10 | Cycle 20 | Outcome |
|---|---|---:|---:|---:|---|
| PIYTI | Saturated | 146508 | 162988 | 163164 | 20 cycles completed; focus restore fails afterward |
| PIYTI | Insane | 166972 | unavailable | unavailable | interrupted after cycle 6 |
| THEARS | Saturated | unavailable | unavailable | unavailable | shell never started |
| THEARS | Insane | unavailable | unavailable | unavailable | shell never started |

[All 20 RSS samples](piyti-saturated/rss.tsv) vary between 146508 and 178352
KiB. Growth is 16480 KiB from cycle 1 to 10, then only 176 KiB from 10 to 20;
this is not steady growth across the two intervals. The automated regression
screen flags more than 8192 KiB growth in *both* intervals; its result is
[steady_growth=false](piyti-saturated/rss-summary.json). This threshold is a
documented coarse screen for allocator/cache retention, not proof of no leak
or a hardware memory budget. The four-cell RSS conclusion is unavailable.

The completed cell verified maximized versus fullscreen, workspace selection,
Deck-only summons during fullscreen, and twenty opens/teardowns alternating
Systems, Signal and Navigator. Each entry asserted `deckMapped=False`,
`audioDetail=0`, `telemetryIntervalMs=0`; each restore asserted closed Deck,
zero audio demand and 5000 ms telemetry. Two active popups spanned each pair
of cycles, retained their count below the three-popup cap, and expired after
restoration. The separate seven-second fullscreen hold preserved its popup
and gave it the remaining visible time after restore.

The final scenario also dismisses a known notification id after each pair
and requires exactly one popup to remain, to detect duplicate identity
masking a lost popup. That assertion was added while the first cell's loop
was already parsed; it was syntax checked but not exercised in the completed
cell. It must be validated on the post-fix rerun.

All four available `qs.log` files (completed cell, interrupted cell, smoke,
Deck) were separately scanned after exit for QML parse/type/reference/
assignment/binding errors: zero matches. Each has exactly one
`AEROLITH started` line; see [qml-audit.json](qml-audit.json). The scenario's
final QML assertion was not reached after the focus failure. Expected external
diagnostics include missing Hyprland mapping/global-shortcut protocols,
RTKit/system-bus availability, smoke's disabled PipeWire, and Deck's deliberate
config-save failure. They are retained in the logs.

**Startup assembly limit:** a single shell-start message proves one root
startup, not one animation. Static inspection of `Theme.ignite()` at
`shell/core/Theme.qml:40-45` confirms the process-lifetime `bootPlayed` guard;
`Ground.qml:10` calls it after recreation. No runtime counter or animation
trace exists in status. The actual assembly count was not directly measured
and is not claimed as passed.

**Thumbnail limit:** Navigator was opened with `navigator.thumbnails=true`
before fullscreen and its Deck closed without QML errors. Sway reports no
`hyprland-toplevel-mapping-v1`; the mock creates IPC clients, not corresponding
Wayland surfaces. Thus the non-null `toplevel.wayland` guard at
`shell/modules/navigator/Sector.qml:58` cannot provide real capture targets.
This checks the opt-in fallback/Deck teardown path and statically confirms
the ScreencopyView is a descendant of the destroyed Deck. It cannot prove
live ScreencopyView creation/destruction, buffer release, or
hyprland-toplevel-export behavior. Those need real Hyprland capture targets.

**Hardware limit:** headless sway/pixman and Qt software rendering cannot
prove GPU memory release, driver buffer retirement, direct scanout, GPU
frame pacing, or game frametime impact. GPU memory release is B06 on real
hardware, using `tools/perf/fullscreen-profile.sh` and actual game workloads.

## Coordination and remaining work

Sync commands used the shared hub and the explicitly requested Sol identity:

```bash
python tools/agent-sync/agent_sync.py --repo /home/user/aerolith lock --agent Sol \
  --files tests/scenarios/fullscreen.sh tests/scenarios/fullscreen-matrix.sh \
  tools/mock-hyprland/mock_hyprland.py docs/verification/B05/README.md \
  --task-id B05 --ttl 14400
python tools/agent-sync/agent_sync.py --repo /home/user/aerolith lock --agent Sol \
  --files tests/py/test_mock_hyprland.py --task-id B05 --ttl 14400
python tools/agent-sync/agent_sync.py --repo /home/user/aerolith lock --agent Sol \
  --files docs/verification/B05 --task-id B05 --ttl 14400
python tools/agent-sync/agent_sync.py --repo /home/user/aerolith publish --agent Sol \
  --type blocked --files tests/scenarios/fullscreen.sh tests/scenarios/fullscreen-matrix.sh \
  tests/py/test_mock_hyprland.py tools/mock-hyprland/mock_hyprland.py docs/verification/B05 \
  --summary "B05 test work ended: fullscreen focus restoration defect requires Opus; matrix incomplete" \
  --notes "697b3da: PIYTI/Saturated 20 cycles; RSS KiB 146508/162988/163164; focus to floating non-fullscreen client leaves phase suspended (shellstate.mjs:56-61). Smoke and Deck pass; Node 129/129; mock pytest 2/2; no QML errors in four logs. No shell changes. Reproduction and incomplete-cell limits in docs/verification/B05/README.md." \
  --task-id B05
python tools/agent-sync/agent_sync.py --repo /home/user/aerolith unlock --agent Sol --task-id B05
```

All locks succeeded before editing. The shared workflow still says
Claude/UI-016, with no pre-existing active locks; an initial Sol/B05 note
records the explicit user/roadmap assignment override. Completion evidence
and the lifecycle blocker are published under B05, and locks are released.
No commit was made. Opus must review/approve the focus correction, then rerun
the matrix and complete the unproved assembly/thumbnail and hardware checks.
