# D03 verification

The source baseline is `4f9944bad72557ba0a2b57c2fcea57555688fd7d`.
Final file hashes are in [source-hashes.json](source-hashes.json).
No commit was made by Astra; the bridge owns Git.

## Required checks

All commands ran from the worktree root. All final commands below exited 0.

| Command | Result | Evidence |
| --- | --- | --- |
| `node tests/js/run-node.mjs` | 130 passed, 0 failed | [Output](node.txt) |
| `CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh build/headless/D03-final-notify` | `notify: ok` | [Output](scenarios/notify/result.txt), [qs.log](scenarios/notify/qs.txt) |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/headless/D03-verified-deck` | `deck: ok`; exit ended early at 133 ms | [Output](scenarios/deck/result.txt), [qs.log](scenarios/deck/qs.txt) |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/headless/D03-final-smoke` | `smoke: ok` | [Output](scenarios/smoke/result.txt), [qs.log](scenarios/smoke/qs.txt) |
| `AUDIO=1 CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/fullscreen.sh build/headless/D03-verified-fullscreen` | `fullscreen: ok`; 20 cycles, popup hold/expiry, focus/restoration | [Output](scenarios/fullscreen/result.txt), [qs.log](scenarios/fullscreen/qs.txt), [RSS](scenarios/fullscreen/rss-summary.json) |
| `bash -n tests/scenarios/notices-layout.sh tests/scenarios/notices-layout-matrix.sh` | Pass | No diagnostics |
| `git diff --check` | Pass | No diagnostics |

Fullscreen RSS at cycles 1/10/20: 155212 / 158604 / 152768 KiB;
the scenario's sustained-growth assertion passed. This is a regression
screen, not a GPU or leak measurement.

## Geometry regression

These final invocations passed all 15 cells, 300 snapshots, eight bay IDs and
eight simultaneous cards per cell. AI is absent in this core matrix, so its
bay shows the normal not-installed fallback.

```sh
tests/scenarios/notices-layout-matrix.sh build/headless/D03-verified-piyti \
  piyti-saturated-1080-full-top piyti-saturated-720-full-top \
  piyti-saturated-720large-full-top piyti-insane-1080-full-top \
  piyti-insane-720-full-top piyti-insane-720large-full-top \
  piyti-insane-720large-reduced-bottom piyti-saturated-720-off-top

tests/scenarios/notices-layout-matrix.sh build/headless/D03-verified-thears \
  thears-saturated-1080-full-top thears-saturated-720-full-top \
  thears-saturated-720large-full-top thears-insane-1080-full-top \
  thears-insane-720-full-top thears-insane-720large-full-top \
  thears-insane-720large-lowEffects-bottom
```

The full core matrix is also the runner's default, without cell arguments.
`1080` means 1920×1080/uiScale 1.0; `720` means 1280×720/1.25;
`720large` means 1280×720/1.5. Wayland output scale remains 1.
Direction changes use the existing installation seam in disposable copies.

Two more compact cells passed with the installed AI console and its eighth
rail tab (both logs confirm `AI module loaded`; no provider query was sent):

```sh
D03_AI=1 tests/scenarios/notices-layout-matrix.sh build/headless/D03-verified-ai \
  piyti-insane-720large-full-top thears-insane-720large-full-top
```

[Installed-AI results](matrix-ai-results.json) and `matrix-ai/` retain these
40 snapshots, configs and logs. Total: **17 cells, 340 snapshots**.

[Matrix results](matrix-results.json) name every cell. Each directory under
`matrix/` contains its exact config, geometry and standalone-column snapshots,
complete `qs.log` as `qs.txt`, and result output. The test asserts:

* Nonempty, readable notice width and bounded on-screen placement.
* No intersection with the rail or either retained bay, including sampled
  entry/reopen states.
* Separate card rectangles, eight records at the combined service caps,
  and access to the last card when the compact lane overflows.
* No standalone column while the Deck is mapped, and bounded restoration
  after close. The existing lifecycle logic was observed, not changed.

The test-only IPC probes are injected into disposable shell copies. Production
hosts, IPC, services, schema and config resolution do not gain test state.

## Old-layout failure

Reproduce against the unchanged base QML:

```sh
mkdir -p build/D03-baseline
cp -a shell build/D03-baseline/shell
for path in modules/deck/DeckView.qml modules/notices/NoticeStack.qml modules/notices/NoticeColumn.qml; do
  git show 4f9944bad72557ba0a2b57c2fcea57555688fd7d:shell/$path > build/D03-baseline/shell/$path
done
D03_SHELL_SOURCE=build/D03-baseline/shell tests/scenarios/notices-layout-matrix.sh \
  build/headless/D03-baseline piyti-insane-720large-full-top
```

Actual result: exit 1, first Help snapshot: `notices overlap rail`.
[Failure output](before/result.txt), [geometry](before/geometry.jsonl),
[log](before/qs.txt). The separate baseline `notify` and `deck` scenarios
passed; neither previously asserted notice placement.

## Log review

Complete final logs are retained and read. See [log-audit.json](log-audit.json)
for line counts, hashes, diagnostics and warning groups.
No QML parse, type, reference, assignment, binding-loop or anchoring errors
occurred across all **21 final logs**. Remaining diagnostics are headless constraints: missing Hyprland
protocols, UPower/system bus/RTKit, optional PipeWire when AUDIO is off, and
one PipeWire connection-close warning at teardown. Deck's read-only-config
failure is intentional test coverage. Wayland focus/text-input warnings
remain visible in Deck evidence and require real-Hyprland confirmation.

## Systems review

One read-only review covered `Deck.qml`, `Ui.qml`, `Notifications.qml` and
the fullscreen scenario. No D03-blocking lifecycle or service change is
required. No cloud agent was dispatched.

**P3 — timing-sensitive fullscreen test count (Sol).**
`tests/scenarios/fullscreen.sh:136` requires one survivor after dismissing a
popup across two cycles, while `Notifications.qml:57–58` correctly gives
popups a fixed lifetime. A concurrent headless run reached cycle 18 with
zero survivors; [failure](review/fullscreen-concurrent-failure.txt),
[complete log](review/fullscreen-concurrent-qs.txt). Both isolated reruns
passed. Inference: accumulated desktop time under load can exhaust the
five-second fixture before the identity assertion. Minimal correction:
separate the cycle-identity fixture from the explicit expiry fixture, or
account for remaining lifetime before requiring a survivor. Preserve the
service's fixed expiry contract. This is a follow-up for Sol, with one
revision/review cycle; no test or systems fix was made in D03.

Two intermediate parent-wrapper layouts also failed Deck's reopen/input
check. The final implementation keeps the original parents and passed the
unchanged scenario twice. The failed intermediate layouts were discarded;
no focus/lifecycle workaround was added.
