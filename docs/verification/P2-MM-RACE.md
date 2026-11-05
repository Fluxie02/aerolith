# P2-MM-RACE

Worktree base: `1abe64c` (`codex/coding-16b1d013`). No commits made.
No visual files, tokens, layout, typography, colours or animation changed.

## Cause and evidence

The secondary is **missing from Quickshell's monitor model**, rather than
actually displaying workspace 1 or retaining an old lifecycle. The existing
single-monitor name fallback in `outputFullscreen()` then attributes the
primary's fullscreen workspace to both Qt outputs.

The controlled reproduction on **main `f4ed25e`** captured:

```text
mock monitors:       HEADLESS-1 -> workspace 1, HEADLESS-3 -> workspace 5
ShellState.detection.monitors: [HEADLESS-1 -> workspace 1]
ShellState.outputStates:
  HEADLESS-1: fullscreen=true, ownerClass=mm1-primary-game, released=true
  HEADLESS-3: fullscreen=true, ownerClass=mm1-primary-game, released=true
```

Evidence: ignored `build/p2-mm-race/forced-main-1/mock-failure.json`,
`surfaces.json`, `status.json`, `qs.log` and `hypr-requests.jsonl`.
The original unmodified HEAD reproduction (`head-2`) also failed the exact
inverse-fullscreen assertion. Its log places a `j/monitors` response **2.1 ms
before** `monitoradded>>HEADLESS-3`.

The source mechanism is:

1. The Qt screen announcement requests monitors while the mock still has
   just HEADLESS-1. The request and event sockets are independent.
2. `monitoraddedv2` inserts HEADLESS-3 in Quickshell's model. A pending monitor
   request causes another request to be dropped.
3. The older response removes names absent from that response, including the
   just-announced monitor. The public `refreshMonitors()` uses `canCreate=false`,
   so subsequent monitor refreshes cannot recreate it.
4. The mock's `add_monitor` omitted `createworkspace[v2]` for workspace 5.
   Workspace refreshes also use `canCreate=false`; an unannounced workspace
   cannot supply the missing monitor link.
5. `createOutputLifecycles()` sees two Qt outputs, but `outputFullscreen()`
   treats the single remaining IPC monitor as both outputs. Its 400 ms entry
   delay expires and both surfaces release.

Steps 2–4 are verified against Quickshell v0.3.2 source:
[event handling and snapshot reconciliation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/hyprland/ipc/connection.cpp),
[public refresh methods](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/hyprland/ipc/qml.cpp),
and [workspace-to-monitor reconstruction](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/hyprland/ipc/workspace.cpp).
The natural failure's exact callback order is inferred from that source and
the timestamped requests. Holding one old reply until after the monitor event
reproduces that order directly, including the missing-monitor snapshot above.

The mock also differs from real Hyprland. In v0.56.2,
[`CMonitor::onConnect()`](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/output/Monitor.cpp#L321)
calls `setupDefaultWS()` before `monitoradded` and `monitoraddedv2` at lines
387–388. For a new default workspace, `setupDefaultWS()` calls
`CWorkspace::create()`; [`CWorkspace::init()`](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/desktop/Workspace.cpp#L72)
posts `createworkspace`, then `createworkspacev2`. Thus the correct new-output
order is **createworkspace, createworkspacev2, monitoradded, monitoraddedv2**.
Across two client sockets, an earlier response can still be processed after a
newer event; correcting event order alone does not justify the shell's fallback.

## Repeated candidate checks

Every candidate used at least five sequential scenario runs. Scratch trees
were created with `git archive <revision> shell tools tests ai-bridge installer
themes install.sh README.md`; production files outside the authorized worktree
were untouched. Docker was already running; `docker info` was checked before
each scenario. No daemon lifecycle command was used.

| Candidate | Result | Evidence under `build/p2-mm-race/` |
| --- | --- | --- |
| HEAD `1abe64c`, original scenario | 3/5 pass; 1 target failure, 1 earlier notice/deck failure | `head-{1..5}` |
| HEAD, expanded read-only diagnostic probe | 5/5 pass | `diagnostic-{1..5}` |
| Earlier phase2 `ee57532`, before layout fit/version plumbing | 5/5 pass | `ee57532-{1..5}` |
| Main `f4ed25e`, original scenario | 5/5 pass | `main-{1..5}` |
| Main, controlled late monitor reply | 0/5 pass; 4 target failures, 1 earlier notice/deck failure | `forced-main-{1..5}` |
| Fixed HEAD, same controlled late reply | 4/5 pass; 1 earlier notice/deck failure before hotplug | `forced-fixed-{1..5}` |
| Fixed worktree, complete multimonitor scenario | 10 consecutive passes, runs 2–11; run 1 stopped at the earlier notice/deck assertion | `fixed-{1..11}` |

The `ee57532` scratch ShellState logs missing-monitor detections without
changing policy. The diagnostic probe reads IPC models in addition to the
usual surface probe. Both can change scheduling, so their passes are not proof
that an earlier commit lacks the race. Main and HEAD have identical lifecycle
logic; replaying the same incomplete snapshot against each releases both
outputs, while the fixed implementation releases only the primary.
The evidence identifies a **latent race exposed by timing**, not a uniquely
identified phase2 commit that introduced incorrect workspace ownership.

For the controlled runs, scratch-only mock operations arm, observe and release
one pending `j/monitors` reply. The scenario arms it before `swaymsg create_output`,
waits until the old one-monitor response is held, adds workspace 5 / HEADLESS-3,
allows 100 ms for event handling, then releases that old reply. All original
scenario assertions remain intact. The barrier is absent from the delivered
mock and scenario. Its wait is bounded to three seconds. In all four fixed
runs that reached hotplug, `post-barrier.json` records both correct monitor
workspace IDs 200 ms after releasing the old reply, before opening the primary
game. This checks event-driven recovery without a subsequent user event.

Example normal batch (executed from the worktree):

```bash
for i in $(seq 2 11); do
  docker info --format '{{.ServerVersion}}' >/dev/null || exit 90
  OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh \
    "build/p2-mm-race/fixed-$i" >"build/p2-mm-race/fixed-$i.log" 2>&1 || exit
done
```

The driver reset the streak after the recorded run-1 notice/deck failure and
would have stopped for investigation on any different failure. No failure was
suppressed inside a scenario. `build/p2-mm-race/results.json` records every
candidate run, including failures.

## Delivered change

- `shell/lib/shellstate.mjs`: the one-monitor fallback is allowed only when
  there is also exactly one Qt output. A missing monitor on a multi-output
  desktop is unknown, never the primary's workspace. Single-output name
  compatibility remains tested.
- `shell/services/ShellState.qml`: include workspace creation, destruction and
  moves in the coalesced event triggers; refresh workspace links with clients
  and monitors. Monitor-model membership changes also schedule reconciliation
  after a late reply; individual property/snapshot changes do not. Existing
  30 ms one-shot timer, no polling.
- `tools/mock-hyprland/mock_hyprland.py`: announce the new default workspace
  before announcing the monitor, matching the cited Hyprland order.
- `tests/js/displays-lifecycle.test.mjs`: deterministic missing-monitor
  fullscreen regression plus retained single-output compatibility.
- `tests/py/test_mock_hyprland.py`: event order and independent workspace test.
- `tests/scenarios/multimonitor.sh`: retain the original release assertion;
  add detection/lifecycle failure evidence, save actual mock state on failure,
  and verify workspace-5 monitor metadata after the original assertion passes.

## Final checks

All checks below completed successfully against the fixed worktree. No source
change followed the ten-run sequence.

| Command | Result |
| --- | --- |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/p2-mm-race/fixed-N` | Ten consecutive passes, N=2–11; original inverse-fullscreen assertion unchanged; added workspace-5 metadata assertion passes |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/p2-mm-race/smoke` | Exit 0, `smoke: ok` |
| `AUDIO=1 CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/fullscreen.sh build/p2-mm-race/fullscreen` | Exit 0, `fullscreen: ok` |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/p2-mm-race/tour` | Exit 0, `tour: ok` |
| `node tests/js/run-node.mjs` | 275 passed, 0 failed |
| `pytest -q tests/py` | 377 passed, 1 skipped in 138.25 s |
| `python -m pytest -q tests/py/test_mock_hyprland.py tests/py/test_multimonitor.py` | Earlier focused check: 7 passed in 12.96 s |
| `bash -n tests/scenarios/multimonitor.sh` | Exit 0 |
| `git diff --check` | Exit 0 |

The 20 multimonitor startup/runtime QML logs and three other requested scenario
logs contain **zero QML parse/type/reference/assignment/binding errors**;
`build/p2-mm-race/qml-audit.json` records the audit. Expected headless protocol
and PipeWire RTKit/no-system-bus warnings remain. During the existing final idle
probe, all ten successful multimonitor runs had **6.47–6.61 seconds without a
monitor query**. The new membership-triggered reconciliation settles rather
than polling. Per-run stdout, screenshots, snapshots, request traces and unit
test output are retained under ignored `build/p2-mm-race/`.

## Review and limits

Single peer review: the phase2 `Compositor.workspaceCells` binding is a pure
derived view, and ControlSurface's version probe is bounded and one-shot;
neither changes workspace ownership. The actionable high-severity finding in
the shared mock is the missing default-workspace creation event described
above; the minimal correction is included. The existing open-window workspace
creation order in `ee57532` is consistent with creation before use and is kept.

Real Hyprland/hardware was not run. Headless checks use sway, real Quickshell,
and the IPC mock. Cross-socket ordering is exercised through the controlled
transport delay; no claim is made that a real compositor failed at the measured
mock frequency. Event-triggered workspace refresh adds work during event bursts
and remains idle between them. The earlier notice/deck baseline failure is
recorded separately from this hotplug race.

## P2-DECK-FOCUS follow-up

Worktree base: `b4c584f` (`codex/coding-0e2101a9`). This fixes the earlier
notice/Deck failure recorded above, independently of the monitor-model race.
All source edits are in this worktree. Opus holds the shared systems-file
locks for this task; Sol publishes the result. No visual design changed.

The original host reproduces the failure in
`build/p2-deck-focus/trace-2/qs.log`. A diagnostic-only copy logs this order:

```text
closed:   screen=HEADLESS-1 desired=HEADLESS-1 mappedOutput=HEADLESS-2 bay=command
visible:  true on HEADLESS-1, bay=command
deferred: screen=HEADLESS-1 desired=HEADLESS-1 mappedOutput=HEADLESS-1 bay=command
visible:  false on HEADLESS-1, bay=""
```

Both outputs remain connected. `Deck.qml`'s old `onClosed` callback only
recovered when `mappedOutput` had disappeared, so it called `Ui.close()` after
Quickshell had already remapped the same bay on the new output. The first trace
even passed the original move assertion before that callback dismissed the bay;
the second trace waits 400 ms and observes the closed Deck. This
verifies the proposed callback mechanism and explains the timing-dependent
assertion. It does not establish the frequency on real Hyprland.

`Deck.qml:onClosed` now captures whether the requested output differs from the
old mapped output **when the signal arrives**. Its existing deferred recovery
also handles that move, preserving the requested bay, slots and input. Capturing
the move before deferring avoids losing it if focus moves again. Recovery still
requires a live destination, an open bay and an unlocked session. Removal keeps
the existing surviving-output recovery; an ordinary close on the current output
still calls `Ui.close()`. `recordMappedOutput()` records screen changes at the
end of the event turn, including changes without a visibility toggle, so a later
ordinary close is attributed to the current output. No timer or polling added.

The existing `Ui.qml:overlayScreen` alias and `Displays.qml` selection already
choose the newly focused Qt output. Neither needs a change. The existing
fullscreen loader and lock request's synchronous `Ui.close()` remain in place.
Single review of those placement/lifecycle paths found the high-severity defect
in the old Deck close handler described above; the minimal correction is here.

`multimonitor.sh` now checks both move directions, the same bay object, preserved
query text, actual typed input after settling, notice takeover/release, and Esc
(first clears the query, then closes). All original hot-unplug/fullscreen checks
remain. `oled.sh` removes the AI reopen workaround and checks that every actual
bay stays mapped with the same object on both destination outputs. The 200/400 ms
settling waits are scenario-only; the shell recovery is event driven.

### Follow-up verification

All commands below ran from this worktree on 2026-11-05. Docker was already
running; `docker info --format '{{.ServerVersion}}'` succeeded before every
scenario. No daemon start, stop or cleanup command was used. The final batch
stopped on any failure and checked source hashes before each run. All 19 runs
passed without retries, with no subsequent shell or scenario source changes.

| Command | Result |
| --- | --- |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/multimonitor.sh build/p2-deck-focus/mm-NN` | Ten consecutive passes, NN=01–10 |
| `AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/p2-deck-focus/oled-N` | Three consecutive passes, N=1–3; no reopen workaround |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/p2-deck-focus/deck` | Exit 0, `deck: ok` |
| `AUDIO=1 CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/fullscreen.sh build/p2-deck-focus/fullscreen` | Exit 0, `fullscreen: ok` |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/p2-deck-focus/smoke` | Exit 0, `smoke: ok` |
| `NET=1 tools/headless/run.sh tests/scenarios/network.sh build/p2-deck-focus/network` | Exit 0, `network NET=1: ok` |
| `TOUR=1 tools/headless/run.sh tests/scenarios/tour.sh build/p2-deck-focus/tour` | Exit 0, `tour: ok` |
| `node tests/js/run-node.mjs` | Exit 0, 275 passed, 0 failed |
| `OUTPUTS=2 LOCK=1 CONFIG=tests/fixtures/lock-config.json tools/headless/run.sh build/p2-deck-focus/close-lock.sh build/p2-deck-focus/close-lock` | Exit 0, `close-lock: ok` |
| `bash -n tests/scenarios/multimonitor.sh tests/scenarios/oled.sh build/p2-deck-focus/close-lock.sh` | Exit 0 |
| `git diff --check` | Exit 0 |

The additional disposable close/lock scenario emits the Deck's `closed` signal
on its current output after transfers and verifies that the bay closes and
telemetry returns to 5000 ms. It also closes during a focus move, then exercises
real session-lock acquisition during another move, focus changes while locked,
and PAM unlock. No queued recovery reopens the Deck. The ordinary-close check
injects the signal; it does not force a native compositor to send a close.

Evidence is under ignored `build/p2-deck-focus/`: `results.json` records every
final run's exact command, flags, exit and duration; `source-hashes.json` pins
the three source files; `suite.log`, per-run logs, screenshots and snapshots
retain the observations. `node.log` retains the unit output. Development
attempts `candidate-mm-1` through `candidate-mm-3` failed newly added harness
assertions: the headless `activeFocus` property was false despite successful
typing, the first Esc correctly cleared the query, and typing before mapping
settled lost the first character. The final assertions use actual input, the
existing two-Esc semantics and a 400 ms settling wait; `candidate-mm-4` passed
before the uninterrupted ten-run batch.

`qml-audit.json` covers all 33 startup/runtime QML logs: **zero error matches
before shutdown**. Two discarded startup-shell logs (`mm-04`, `mm-08`) contain
25 assignment warnings after their explicit `Exiting due to IPC request` lines
during singleton teardown; none mentions the Deck, and all replacement runtime
logs are clean. These warnings are recorded rather than counted as clean logs.
Expected headless protocol and RTKit/system-bus warnings also remain.

Limits: these checks use real Quickshell on headless sway with Hyprland IPC
mocked. Native Hyprland, physical hotplug and hardware/GPU timing remain
unverified. No visual design, host configuration, global package or production
checkout source was changed; no commit was made.
