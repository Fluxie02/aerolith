# COUNTERPHASE — UI-013

PIYTI is the base following the owner's decision during the pause. Its cyan
application instrument now carries SHEAR's living structure: opposed datum
carriers, an Insane return vernier and a leading-edge tension stroke. The
focused workspace determines carrier direction; real compositor state drives
the application ports, workspace index and focus response. Moving marks are
mechanical registration, not invented telemetry. Text and controls stay still.

THEARS remains working in both intensities. It is frozen as a direction;
the shared motion/readability corrections preserve it. Claude will wire the
one-time installation choice. There is no new Settings control. The existing
shipped THEARS default is unchanged; forward review copies select PIYTI.

The full-motion escapement moves for 960 ms, then rests: a 9.28 s cycle in
Saturated and 5.12 s in Insane. Reduced uses a 24 s cycle, at most 3 logical
pixels of travel and .07 opacity variation. Every ambient job uses one
`Theme.ambient` gate, with local exposure checks. Motion off and lowEffects
stop/reset the marks. A single slow timer starts finite all-Animator groups;
there is no per-frame JavaScript, ambient Canvas repaint or animated layout.
Startup also stopped repainting the screen-sized Canvas every frame.

Review began with a continuous-motion prototype costing 13.03% of one core.
The coordinated movement/rest cadence brought it inside the requested CPU
budgets. All geometry is native/procedural; no bitmap asset, shader, blur or
GPU effect was added. Optional shading belongs to Claude's next pass.

## Idle CPU

Percent of one core, software-rendered PIYTI, using `perf.sh`'s default
120 s initial idle sample and 30 s samples for the other states:

| Intensity | Ambient on | Motion off | lowEffects |
| --- | ---: | ---: | ---: |
| Saturated | 1.42% | 0.17% | 0.17% |
| Insane | 3.59% | 0.17% | 0.17% |

After use, ambient idle measured 1.30% / 3.80% respectively. Disabled
measurements are close to the prior ~0.14% baseline. Full state data, memory,
context switches, exact commands and source manifests are in `perf-piyti/`.
The paired intensity runs overlapped verification containers; these are
process CPU ticks over wall time, not an isolated hardware benchmark.
No real-GPU VRAM result is implied.

## Evidence to open first

* [PIYTI Saturated / integrated apps](motion-piyti/saturated/00-piyti-integrated.png)
  and [Insane](motion-piyti/insane/00-piyti-integrated.png): actual QML output
  using explicit Hyprland protocol fixture windows, not real application
  screenshots or a concept render.
* Actual [Saturated motion](motion-piyti/saturated/motion.webp),
  [Insane motion](motion-piyti/insane/motion.webp), contact sheets and timestamped
  PNG sequences are in `motion-piyti/`. [Pixel evidence](motion-piyti/pixel-verification.json)
  confirms restart after off/lowEffects, stationary disabled states, a 2 px
  observed reduced stroke and no reduced focus flash.
* Final PIYTI compact and 4K screenshots are under `verification/final-runs/piyti-*`.
  Compact checks use 1280×720/uiScale 1.5 with off, reduced and lowEffects.
  Both intensities use actual 3840×2160 outputs at scale 2/uiScale 1,
  scale 1.5/uiScale 1 and scale 1/uiScale 1.5, with matching Hyprland mock
  arguments. Output/mocked geometry JSON is retained alongside the frames.

## Review and self-review

Independent visual and motion reviewers checked the source, native 4K frames
and motion while the work developed. Fixes include compact title clearance,
measured vernier ticks, live reduced-mode Animator restarts, immediate
Insane-return cancellation and removal of the reduced focus flash.

My final self-review's biggest weakness was the deferred cadence restart:
it checked the motion gate before scheduling, so a later disable could be
overtaken by the queued callback. I fixed it immediately by checking the gate
inside `restartCadence()` when it actually executes. Rapid intensity/motion
changes now finish with pixel-identical off frames in both intensities.

One short-settle 4K/scale 2 frame lost Canvas faces without a QML error.
Visual review rejected it. The settled, remapped and reopened captures render
correctly; the original is retained under `verification/attempts/`. No
rendering code fix is claimed for that non-repeating harness observation.

Exact test commands/results and the final log audit are in
[verification/RESULTS.md](verification/RESULTS.md); reviewer findings are in
[REVIEWS.md](REVIEWS.md). Node and Qt V4 each passed 104/104; pytest passed
71 with 1 skipped. Smoke, full, Deck and AI scenarios exercise the existing
keyboard/IPC/bay contracts in both directions and both intensities.

## Handoff

[SYSTEMS-REQUESTS.md](SYSTEMS-REQUESTS.md) specifies the exact
`Theme.ambientSuspended` hook, installation-only choice and the inherited
portrait-output focus observation. [SHADER-REQUESTS.md](SHADER-REQUESTS.md)
specifies placement, material, colours and state reactions for Claude.
Fullscreen/game VRAM release requires systems-side unmapping and visual
unloading; stopping animation alone cannot achieve it. Real Hyprland/GPU
VRAM behaviour remains outside this software-rendered harness.

This agent did not write to git or create a commit; Claude owns the
commit handoff. The coordination event and unlock are the final task steps.
