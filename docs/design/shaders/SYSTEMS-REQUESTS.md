# E01/E02 handoff to Opus

These are requests, not changes to system contracts. Astra did not modify
services, Deck.qml, host visibility/loader logic, config or schema.

1. **Quality seam (P2).** Wire a validated `off | standard` setting through
   config/schema/CLI, mapping to `Theme.shaderQuality` 0 or 1. The current
   visual token defaults to 1; `lowEffects` always overrides it. There is
   deliberately no speculative high-quality pass. Direction remains
   installation-only and intensity remains independently live-switchable.
2. **CI/build (P2).** Run `tools/build-shaders.sh --check` in aerolith-dev
   with Qt 6.12 qsb. Regeneration uses the required GLSL 100es/120/150,
   HLSL 50 and MSL 12 targets. Ship `shell/shaders/*.frag.qsb` along with
   `.frag` and `material.glsl`, preserving the components' relative paths.
   Audit the minimum runtime Qt against the qsb package version. The user
   installer copies the shell recursively; packaging/CI are Opus/Sol work.
3. **Hardware gate (P1 before approving the shader appearance/cost).**
   Capture both directions/intensities on a working RHI backend, verify
   actual pixel output and startup/focus/workspace/carrier/docking motion,
   then run B06 and E03/E04 measurements. Record pipelines, GPU memory,
   compilation/cache lifetime, frame times and 60/120/144 Hz cadence.
   Container software rendering cannot establish these results.
4. **Matrix runner correction (P2, Sol; one revision requested).**
   `tests/scenarios/notices-layout-matrix.sh` still asserts the literal
   `property string applicationDirection: "piyti"`. C01 now binds that
   property to `Config.applicationDirection` (`shell/core/Theme.qml`).
   Default invocation aborts before launching QML. Minimal correction:
   update the disposable-copy injection to recognize the current seam,
   or seed installation metadata in the harness. Keep production direction
   installation-only. E01's compatibility run changes only the initial
   declaration in a disposable input copy; the scenario itself is unchanged.

Read-only systems review covered ShellState, shell.qml, Deck.qml, the
headless harness and installer copying. The existing fullscreen hold and
destruction order need no visual workaround. Shader instances live only
under the existing Ground/Deck content; Material also unloads them when
`Theme.ambientSuspended` becomes true. OSD gains no shader. No dispatcher
was used, and no cloud agent is claimed to have been started.
