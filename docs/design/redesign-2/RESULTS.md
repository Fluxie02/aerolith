# UI-018 — the hatch

The wing is replaced by a framed, two-leaf hatch into the scratch space.
Implementation is based on `7f2908693f97868f807a22e5b9747321f42605ad` in the
assigned worktree. No commit made.

The frame, centre seam and paired handles make the opening mechanism explicit.
The leaves retract in 260 ms with the full-motion tokens; the frame and
surrounding desktop stay fixed. The inventory label remains readable when
closed: EMPTY or the number PARKED. Opening reveals up to three plain-text
window titles/app names and a remaining count. The action says OPEN/CLOSE
SCRATCH SPACE, with Super+S and Super+Shift+S hints underneath. Empty and
disconnected states are distinct.

The hatch calls the guarded `scratch.toggle` Registry command and follows
`Compositor.scratchOpen` and `scratchWindows`. There is no optimistic state,
window-moving logic or new shortcut implementation in this change. Missing
integration shows UNAVAILABLE and disables the action. Registry revision
changes re-evaluate command availability.

Only the two retained leaves animate. Reduced/off motion jumps directly to
the new state; loss of exposure, ambient hold, low effects or opening Deck
completes travel immediately. There are no new timers, canvases, shader
passes, captures, textures or surfaces. The existing host/fullscreen release
path is untouched. All text uses existing semantic palette/type roles.

Production files:

- Added `shell/components/Hatch.qml`.
- Updated `shell/components/InstrumentField.qml` to instantiate the hatch on
  Ground, and removed the wing-only Counterphase beat connection. The hatch
  is absent from the Deck's decorative instrument.
- Deleted `shell/components/ShearField.qml` and its dedicated
  `shell/shaders/bevel.frag` / `bevel.frag.qsb`.
- Inspected and retained `Instrumentation.qml`, `WorkspaceOrbit.qml`,
  `Counterphase.qml`, Ground, Theme, Deck and all systems services. The
  rest of redesign round 1 keeps its existing layout and behavior.

Evidence files and reproducible visual-only fixtures are confined to this
directory. The fixture changes only a disposable shell copy: it supplies
scratch-shaped data and a unique `visual.hatch.toggle` Registry command.
Screenshots show real Quickshell rendering and actual pointer delivery to
the hatch. They do **not** validate Hyprland special-workspace dispatch or
the global keybinds; those belong to Sol's parallel implementation.

| Native capture, output scale 1.5 | Before | Closed, empty | Open, empty | Closed, parked | Open, parked |
|---|---|---|---|---|---|
| 1920×1080 (1280×720 logical) | [Before](before-1920.jpg) | [Closed](1920-closed-empty.jpg) | [Open](1920-open-empty.jpg) | [Closed](1920-closed-parked.jpg) | [Open](1920-open-parked.jpg) |
| 2560×1440 (1706.67×960 logical) | [Before](before-2560.jpg) | [Closed](2560-closed-empty.jpg) | [Open](2560-open-empty.jpg) | [Closed](2560-closed-parked.jpg) | [Open](2560-open-parked.jpg) |
| 3840×2160 (2560×1440 logical) | [Before](before-3840.jpg) | [Closed](3840-closed-empty.jpg) | [Open](3840-open-empty.jpg) | [Closed](3840-closed-parked.jpg) | [Open](3840-open-parked.jpg) |

The before version has a wing and no scratch-space states. Fresh baseline
captures use the unmodified shell archived from the base above. Full views
are reduced to at most 1280×720; native dimensions and archive sizes are
recorded in [evidence.json](evidence.json). Detail views:
[closed empty](detail-closed-empty.jpg), [open empty](detail-open-empty.jpg),
[closed parked](detail-closed-parked.jpg), [open parked](detail-open-parked.jpg).
Also archived: [unmodified shell without the interface](interface-unavailable.jpg),
[reduced closed](detail-reduced-closed.jpg), [reduced open](detail-reduced-open.jpg),
[motion off closed](detail-off-closed.jpg), [motion off open](detail-off-open.jpg).
The [motion strip](motion.jpg) contains consecutive real opening and closing
frames at the production duration, with intermediate pixel states checked
against both endpoints ([evidence](checks/motion-evidence.json)).

Palette/state contact sheets:
[PIYTI Saturated](schemes-piyti-saturated.jpg),
[PIYTI Insane](schemes-piyti-insane.jpg),
[THEARS Saturated](schemes-thears-saturated.jpg),
[THEARS Insane](schemes-thears-insane.jpg).
Each shows all 12 schemes, closed and open. The literal `<b>` title in the
parked fixture intentionally checks that window metadata stays plain text.

| Check | Final result |
|---|---|
| Node | 170 passed, 0 failed — [output](checks/node.txt) |
| Python | 295 passed, 1 skipped — [output](checks/python.txt) |
| Qt V4/offscreen | 162 passed, 0 failed — [output](checks/qt.txt) |
| smoke | PASS — [output](checks/smoke.txt) |
| deck, AUDIO=1 | PASS — [output](checks/deck.txt) |
| fullscreen | PASS, 20 release/restore cycles; RSS 163228 → 165964 → 169072 KiB, sustained-growth gate false — [output](checks/fullscreen.txt) |
| direction | PASS — [output](checks/direction.txt) |
| app-links | PASS — [output](checks/app-links.txt) |
| Visual fixture, all three target modes at scale 1.5 | PASS; empty, parked, click delivery, open/close, reduced/off — [1920](checks/after-1920.txt), [2560](checks/after-2560.txt), [3840](checks/after-3840.txt) |
| Palette matrix: 12 schemes × 2 intensities × 2 directions × open/closed | PASS, 96 views — [output](checks/matrix.txt) |
| Remaining shader packages | PASS; `tools/build-shaders.sh --check` — [output](checks/shaders.txt) |
| Opening/closing motion capture | PASS; real intermediate pixel states in both directions — [output](checks/motion.txt), [pixel check](checks/motion-evidence.json) |
| Final QML logs | 27 logs, zero matched QML errors — [audit](checks/qml-audit.json), [production hashes](checks/source-hashes.json) |
| Arithmetic geometry | PASS; default density/UI scale, stations/media/app bar clear — [data](checks/geometry.json). This is supplementary, not a rendering test. |
| Fixture Python compilation, shell syntax, whitespace | PASS |

All headless scenarios run one at a time. Disposable container settings and
processes only; no host setup, package installation or system restart.
Docker was initially unavailable, then became available externally; the
final results replace those initial connection failures.
Expected harness warnings remain: sway has no Hyprland global-shortcut
protocol; audio-disabled runs have no PipeWire context; the throwaway audio
session has no system D-Bus/RTKit. These are separate from the zero-error
QML parse/type/reference/binding audit.

Commands, from the repository root (raw captures/logs in `build/redesign-2`):

```bash
node tests/js/run-node.mjs
python3 -m pytest -q tests/py
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'
docker run --rm -v "$PWD:/src:ro" aerolith-dev bash -c \
  'cd /src && tools/build-shaders.sh --check'
tools/headless/run.sh tests/scenarios/smoke.sh build/redesign-2/smoke
AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/redesign-2/deck
AUDIO=1 tools/headless/run.sh tests/scenarios/fullscreen.sh build/redesign-2/fullscreen
tools/headless/run.sh tests/scenarios/direction.sh build/redesign-2/direction
tools/headless/run.sh tests/scenarios/app-links.sh build/redesign-2/app-links

mkdir -p build/redesign-2/baseline
git archive 7f2908693f97868f807a22e5b9747321f42605ad shell | tar -x -C build/redesign-2/baseline
for size in 1920x1080 2560x1440 3840x2160; do
  width=${size%x*}
  SHELL_PATH=build/redesign-2/baseline/shell RES="$size" SCALE=1.5 \
    HYPR_MOCK_ARGS="--mode $size --scale 1.5" \
    tools/headless/run.sh docs/design/redesign-1/scripts/capture.sh build/redesign-2/before-"$width"
  AUDIO=1 RES="$size" SCALE=1.5 HYPR_MOCK_ARGS="--mode $size --scale 1.5" \
    tools/headless/run.sh docs/design/redesign-2/scripts/visuals.sh build/redesign-2/after-"$width"
done
AUDIO=1 RES=1920x1080 SCALE=1.5 HYPR_MOCK_ARGS='--mode 1920x1080 --scale 1.5' \
  tools/headless/run.sh docs/design/redesign-2/scripts/matrix.sh build/redesign-2/matrix
AUDIO=1 RES=1920x1080 SCALE=1.5 HYPR_MOCK_ARGS='--mode 1920x1080 --scale 1.5' \
  tools/headless/run.sh docs/design/redesign-2/scripts/motion.sh build/redesign-2/motion
python3 docs/design/redesign-2/scripts/motion.py
python3 docs/design/redesign-2/scripts/archive.py
python3 docs/design/redesign-2/scripts/audit.py
python3 docs/design/redesign-2/scripts/geometry.py
python3 -m py_compile docs/design/redesign-2/scripts/*.py
bash -n docs/design/redesign-2/scripts/*.sh
git diff --check
```

Shared coordination: the hub named `Claude_Performance_Audit` / Claude on
entry. Your explicit isolated-worktree assignment was recorded with a note
before editing, without changing Sol's workflow or locks. Astra reserved the
visual files for UI-018. Reviewed Sol's merged app-ranking change `4183709`
once: its socket/delegate layout and activation flow are preserved; no
actionable visual finding. The parallel scratch patch is not in this
worktree and cannot yet be reviewed here.

Follow-up and limits:

- Sol: land the shared scratch interface/keybinds, then verify actual
  parking, output selection, empty toggle, cross-output behavior and
  special-workspace lifecycle against this hatch. The current base lacks
  that interface; its guarded disconnected rendering is also captured in
  each run's `interface-state.png`.
- Systems/performance review: check real Hyprland/GPU restoration and native
  input once. The headless harness uses software sway with a Hyprland mock;
  it cannot establish physical GPU/VRAM cost. The hatch remains part of
  Ground, so real client windows can cover it; Super+S is the alternate
  close action when its location is covered.
