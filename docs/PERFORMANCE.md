# Measuring AEROLITH's cost

There are two measurements. Neither replaces the other.

## Headless: `tests/scenarios/perf.sh`

```bash
AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh
```

It reads the quickshell process's CPU time and memory from `/proc` in four
states:
- `idle-strip`, 120 s (`PERF_IDLE_S`)
- `systems-bay-open`, 30 s (`PERF_OPEN_S`)
- `command-core-open`, 30 s
- `idle-after-use`, 30 s

It writes `perf.json` with:
- `cpu_percent`: percent of one core
- context switches per second
- resident memory and its peak

**Limits:**
- The harness renders in software (Qt's software backend on sway with pixman).
- Idle numbers are comparable with a real desktop.
- Numbers for drawing and animation are higher than on a GPU.
- It cannot show frame pacing or GPU memory.

## Real hardware: fullscreen games

While a fullscreen window owns the shell's output, AEROLITH:
- destroys its visual surfaces (Ground, Flight Strip, Deck and Notices),
- holds ambient motion,
- stops strip telemetry.

It rebuilds them once the window leaves fullscreen. See
`shell/services/ShellState.qml` and `tests/scenarios/fullscreen.sh`. The
headless scenario proves the lifecycle, but not GPU memory, because
software rendering has none to release.

Measure that on the target machine, inside Hyprland with the shell running:

```bash
tools/perf/fullscreen-profile.sh 30
```

It samples the shell for 30 s in three phases: on the desktop, during a
fullscreen game, and after it. It writes a JSON report to
`~/.local/state/aerolith/` with:
- CPU and wakeups
- resident memory
- the shell's GPU memory, from the kernel's DRM fdinfo (amdgpu, i915, xe,
  nouveau), or from `nvidia-smi` with the NVIDIA driver
- Hyprland's `render:direct_scanout` setting, which it only reads and
  never changes

**The target** is near-zero incremental GPU memory attributable to the shell
during fullscreen. Total GPU memory never reaches zero, because Hyprland
and the game keep rendering.

**Game frame times:** use MangoHud's frame-time log, recorded once with the
shell running and once without, and compare the two logs.
