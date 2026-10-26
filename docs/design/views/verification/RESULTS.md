# UI-007 verification

22 October 2026 · Astra · software rendering on headless sway.

Final result: three standalone production views, three complete preview
shells, 190 PNGs and the interface handoff in `docs/design/VIEWS.md`.
No production host, service, configuration/schema or AI files were edited.
`ai-bridge/qml/AiModule.qml` was already modified when UI-007 began; it was
left untouched. Git was used only for read-only inspection; no commit.

## Required checks

| Exact command | Result |
| --- | --- |
| `node tests/js/run-node.mjs` | 104 passed, 0 failed; `node-tests.txt` |
| `docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c 'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'` | 104 passed, 0 failed; `qt-tests.txt` |
| `python3 -m pytest -q tests/py` | 71 passed, 1 skipped in 12.76 s; `python-tests.txt` |
| `AUDIO=1 HYPR_MOCK_ARGS='--mode 2560x1440 --scale 1.5 --transform 1' tools/headless/run.sh tests/scenarios/deck.sh build/ui007-deck` | exit 0, `deck: ok` |
| `CONFIG=tests/fixtures/notify-config.json tools/headless/run.sh tests/scenarios/notify.sh build/ui007-notify` | exit 0, `notify: ok` |
| `AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh build/ui007-perf` | exit 0, `perf: ok`; full default 120/30 s windows; `perf.json` |
| `git diff --check` | exit 0 |

Performance: idle 0.25% of one core / 5.1 context switches per second /
119.3 MiB RSS; idle after use 0.23% / 5.0 / 122.6 MiB; peak RSS 179.2 MiB.
The prior UI-006 Saturated evidence (`saturated-perf-verified.json`) reports
idle 0.29% / 7.6 / 119.7 MiB and after use 0.27% / 5.2 / 130.7 MiB, peak
171.3 MiB. Systems-open switches were higher in this run (189.5/s versus
104.0/s) with lower CPU (4.06% versus 4.53%); captures ran concurrently, so
these are observational numbers, not an isolated performance comparison.
The new views are not imported by the production shell, so this required
regression run does not measure future host costs or GPU memory.

## Final preview commands

All finish with `UI-007 <view>: state captures and interaction checks passed`
and exit 0. Each matrix renders both intensities with full motion, reduced
motion, off + lowEffects, and 1.25 scale with Noto fonts.

```bash
SHELL_PATH=prototypes/views/lock tools/headless/run.sh prototypes/views/capture.sh build/ui007-lock-verified
RES=1280x720 SHELL_PATH=prototypes/views/lock tools/headless/run.sh prototypes/views/capture.sh build/ui007-lock-small-verified
SHELL_PATH=prototypes/views/osd tools/headless/run.sh prototypes/views/capture.sh build/ui007-osd-complete
RES=1280x720 SHELL_PATH=prototypes/views/osd tools/headless/run.sh prototypes/views/capture.sh build/ui007-osd-small-verified
SHELL_PATH=prototypes/views/session tools/headless/run.sh prototypes/views/capture.sh build/ui007-session-verified
RES=1280x720 SHELL_PATH=prototypes/views/session tools/headless/run.sh prototypes/views/capture.sh build/ui007-session-small-final
SHELL_PATH=prototypes/views/session tools/headless/run.sh prototypes/views/session-check.sh build/ui007-session-availability
```

The final extra session check passes empty-model keyboard navigation and
cancellation of a pending confirmation when an inhibitor refresh replaces
the action model. It records `event: none` and empty `pending`, without
performing any operation. The empty selection clamp and this fixture check
were added after the screenshot matrix; they do not change rendered states.
A final lock-only whitespace normalization also has no rendering effect.

Screenshot count: Lock 40, OSD 74, Session 76. `../captures.json` maps all
files, state names, sizes and SHA-256 hashes. Every lock state, OSD kind and
availability/mute/level variant, and session action selection/confirmation
choice is captured in both intensities and both resolutions. OSD's exit
frames show the empty background, as expected. The small OSD fixture clamps
its position to keep the full scaled view on screen.

Actual keyboard checks cover password submission and clearing, checking
and locked-out input blocking, failed-state retry, direct lock activation,
sensitive-action confirmation, default Go back, explicit confirmation,
Escape/back/cancel, unavailable and empty action guards, plus OSD exit
completion under full/reduced/off/lowEffects. Input assertions poll for
up to 1 second because Wayland key delivery and IPC are separate queues;
they do not resend a key or bypass the view's handlers.

## Log and visual audit

`log-audit.json` records the six final preview logs, the availability check,
and the required Deck/notification/performance logs: no QML parse/type/
reference/assignment errors or binding loops. Copies are saved as `*-qs.txt`.
The headless compositor emits the known `wl_keyboard.leave` and text-input
focus warnings during real wtype input; these also occur in production Deck
checks. The Deck test intentionally logs an unsuccessful config save when
it makes config.json read-only. Audio startup reports missing system-bus
realtime scheduling in the container. These are not view QML failures.

Reviewed state contact sheets and full-size samples: both intensities, idle,
checking/failure/lockout, literal markup, masked entry, amplified and unknown
OSD, session confirmations and 720p at 1.25 scale. Long lock prompts scroll
above the fixed button; long session lists scroll and selection follows the
visible row. LowEffects is opaque. The preview roots select only Ui.screen.

## Scope and integration limits

Lock preview is an ordinary PanelWindow, not a secure session lock. PAM,
WlSessionLock, backlight/audio service event mapping, actual logind/session
operations, hotplug security and real Hyprland/GPU behavior are not exercised.
The view contains no systems code or host lifecycle. Claude supplies that
layer using the documented property/signal contracts.

Reviewed Claude's current Power registry, Deck focus/lifecycle and notices
policy once: no actionable visual integration findings. Suspend's sensitive
flag is preserved in the fixture. Handoff requests one systems/performance
review with one revision; no external agent was dispatched.
