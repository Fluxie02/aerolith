# PIYTI CPU measurements

Each of the six cases runs the unchanged repository `tests/scenarios/perf.sh`
through `tools/headless/run.sh`, with its default 120 s initial idle sample
and 30 s Systems, Command and idle-after-use samples. `AUDIO=1 MEDIA=1`.
Output is 1920×1080 / scale 1, Qt Quick software, Sway pixman,
Quickshell 0.3.2 in the existing aerolith-dev image. CPU percentages refer to
one core, calculated from process CPU ticks divided by elapsed wall time.

Each `<intensity>-<mode>-result.txt` begins with the exact command and ends
with its exit code; `perf.json`, `qs.txt`, context-switch and memory data are
inside each case directory. Modes are `full`, `off` and `low` (full motion
with lowEffects enabled). Configs are in `../build-check/`.

The disposable `build/counterphase-piyti-perf-shell` is a frozen copy of the
production shell with only its applicationDirection default set to `piyti`.
For reproduction, copy `shell/` to that path and change that one default
before launching the recorded command. Never mutate a running snapshot.
`source-hashes.json` identifies the measured files; `source-comparison.json`
explains the later reduced-focus and live-setting callback guards. Those
guards do not alter any fixed full/off/lowEffects case. Final focused motion
and required scenario checks use the updated source.

The two intensity sequences ran concurrently, at most one benchmark per
intensity, with some overlap from screenshot/scenario verification. These
are not isolated hardware benchmark results. CPU ticks belong to the shell
process; screenshots are not part of perf.sh's timed samples. No threshold
was added to perf.sh. The owner's idle budget is about 2% Saturated and 4%
Insane. Stopped animation is compared with the prior ~0.14% idle baseline;
0.17% is a difference of 0.03 percentage points, not a claim of exact equality.

THEARS compatibility measurements from before the interruption are in
`../perf/`: ambient idle 1.49% / 3.65%. The exploratory continuous-motion
prototype and its rejected 13.03% idle cost are in `../perf-experiments/`.
PIYTI is the forward design and authoritative final review set.

These measurements say nothing about real Hyprland/GPU VRAM release. See
`../SYSTEMS-REQUESTS.md` for the required host lifecycle hook and unloading.
