# Hyprland Desktop Shell — Development & Integration Roadmap

The owner's roadmap, recorded verbatim on 26 October 2026. All agents follow
it. Progress is tracked in the "Status" section at the end.

**Technical lead:** Claude Opus 5.5
**Visual and shader lead:** GPT-6 Astra
**Implementation and testing lead:** GPT-6.1 Sol

**Core objective:** Build an exceptionally distinctive, shader-rich, command-centred Hyprland desktop shell that remains efficient, responsive, reliable, and almost entirely inactive during fullscreen gaming.

**Platform:** Hyprland first, single-monitor architecture first. Expand compatibility only after the primary implementation is stable.

## Phase 1 — Integration & Architecture

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 1 | Merge Astra's existing work from SHEAR through Smoothness into PR #1. Resolve conflicts, inspect the shaders, and verify they render correctly. | Opus | Critical |
| 2 | Audit the current repository: rendering framework, resource lifecycle, services, animations, IPC, themes, installer, and unfinished functionality. Produce an actionable issue list. | Opus | Critical |
| 3 | Establish clear ownership boundaries and integration contracts for Astra, Sol, and Opus. Separate parallel work into dedicated branches. | Opus | Critical |
| 4 | Introduce a central shell state controller for desktop, fullscreen, gaming, suspended, and recovery states. Components must subscribe to changes rather than implement conflicting detection logic. | Opus + Sol | Critical |

## Phase 2 — Fullscreen Gaming & Performance

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 5 | Implement automatic fullscreen detection using Hyprland events and state inspection. Distinguish actual fullscreen applications from maximized windows. | Sol; Opus reviews | Critical |
| 6 | Develop a gaming mode that suspends unnecessary shader loops, animations, rendering timers, background effects, and GPU workloads. | Opus + Astra | Critical |
| 7 | Release unnecessary GPU framebuffers, cached textures, offscreen render targets, and rendering contexts where technically possible. Restore them on demand. | Opus + Astra | Critical |
| 8 | Optimize fullscreen presentation. Investigate direct scanout, overlay interference, compositor behavior, and methods to avoid unnecessary surface commits. Do not alter global Hyprland settings without user consent. | Opus | Critical |
| 9 | Implement reliable resource restoration when leaving fullscreen. No flashing, frozen surfaces, lost input, or unnecessary full shell restarts. | Sol; Opus reviews | Critical |
| 10 | Build a performance testing harness measuring idle CPU, process memory, GPU utilization, attributed VRAM, frame timing, and gaming-mode resource deltas. | Sol + Opus | High |

**Acceptance criteria:**
- Fullscreen entry and exit work repeatedly.
- Unnecessary rendering stops.
- Eligible fullscreen games can benefit from compositor optimizations.
- Resources are reclaimed when possible.
- Gaming performance is not meaningfully degraded by the shell.

**Important:** Zero total VRAM usage is not physically achievable while Hyprland and the game are rendering. Minimize the incremental memory and GPU workload attributable to the shell, rather than claiming absolute zero VRAM.

## Phase 3 — Installer & Personalization

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 11 | Redesign installer flow to let users select THEARS or PIYTI, with visual previews and a clear default. Preserve the chosen option across installation and updates. | Sol + Astra | High |
| 12 | Add explicit opt-in installation of supported application themes. Keep a clean manifest of affected apps and provide reversible changes. | Sol | High |
| 13 | Implement a centralized theme-token system covering colors, surfaces, transparency, typography, highlights, borders, shaders, and OSD elements. | Sol + Astra | High |
| 14 | Make supported application themes follow the shell's selected color scheme, including runtime updates when supported by the target application. | Sol | High |
| 15 | Improve installer failure recovery, dependency checks, idempotency, configuration backup, upgrade handling, and full uninstall behavior. | Opus + Sol | High |

**Acceptance criteria:**
- Users can install either visual identity.
- Users can opt out of app modification.
- Users can change colors without inconsistencies.
- Users can uninstall or update without leaving damaged configurations.

## Phase 4 — Essential Shell Functionality

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 16 | Fix notifications overlapping Help and Settings. Introduce consistent overlay stacking, layout constraints, and notification placement rules. | Astra + Sol | High |
| 17 | Finish wiring the OSD into real system events: volume, mute, microphone, media, and brightness. Ensure animations and colors match the chosen theme. | Opus + Sol | High |
| 18 | Implement brightness controls with capability detection, supporting compatible laptop backlights and optional external-monitor backends. | Sol | High |
| 19 | Audit all shell navigation, settings, Help screens, keyboard shortcuts, and command-centred interactions. Eliminate nonfunctional controls and inconsistent navigation. | Opus | High |
| 20 | Improve monitor configuration, DPI scaling, fractional scaling, animation timing, and recovery after resolution changes, while prioritizing one-monitor correctness. | Sol | Medium |
| 21 | Add robust error handling for missing services, unavailable hardware, failed IPC calls, crashed shell modules, and partially initialized components. | Opus + Sol | High |

## Phase 5 — Shader & Motion Engine

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 22 | Implement Astra's requested shader list. Preserve the existing visual direction but allow substantial creative improvements where they improve the result. | Astra | High |
| 23 | Standardize shader interfaces: time, resolution, scale, theme colors, intensity, motion state, input data, and quality level. Ensure compatibility with the actual rendering backend. | Astra + Opus | High |
| 24 | Create advanced shader transitions for window overview, workspace switching, opening and closing panels, command palette activation, and system-status changes. | Astra | High |
| 25 | Develop a cohesive motion language inspired by sophisticated avionics and experimental technical instrumentation. Avoid generic neon dashboards and excessive decorative effects. | Astra | Medium |
| 26 | Introduce configurable shader quality profiles and a reduced-motion mode. Profile expensive passes, prevent excessive shader compilation, and eliminate unnecessary continuous redraws. | Astra + Sol | High |

**Creative direction:** The shell should feel like an entirely new interface rather than a conventional desktop with added blur and glow. Explore spatial transformations, procedural geometry, visual continuity between panels, carefully controlled distortion, and animations that communicate system state.

**Performance constraint:** Shaders must be event-driven wherever possible. Effects that require continuous animation must be rate-limited or suspended when inactive, obscured, or in gaming mode.

## Phase 6 — Reliability, Testing & Release

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 27 | Add automated tests for state changes, theme switching, settings persistence, installer operations, and shell service behavior. | Sol | High |
| 28 | Test representative gaming and desktop workloads, including Steam/Proton, Vulkan/OpenGL applications, fullscreen transitions, notifications, and video playback. | Opus + Sol | High |
| 29 | Conduct an architecture and performance review. Remove duplicated logic, obsolete code, expensive polling, memory leaks, and unnecessary dependencies. | Opus | High |
| 30 | Finalize documentation, record known limitations, review integration branches, and merge tested work into the main development branch. | Opus | High |

## Coordination Rules

1. Opus is the final integrator. It reviews architecture, security-sensitive operations, compatibility changes, and merges.
2. Astra owns visual implementation decisions, subject to technical feasibility and performance requirements.
3. Sol receives clearly bounded, independently testable tasks, rather than unrestricted changes across the entire repository.
4. All agents must inspect existing code before changing it. Do not rewrite working components merely for stylistic preference.
5. Separate shader development, installer changes, and critical runtime changes into branches to minimize conflicts.
6. Every implementation must include a summary of changed files, known risks, verification performed, and remaining limitations.
7. Do not claim a feature is complete without relevant testing.
8. Measure real performance before and after optimization rather than relying on theoretical estimates.
9. Preserve the user's configurations and provide rollback paths for potentially destructive modifications.
10. Avoid adding dependencies, background services, polling loops, or GPU workloads without justifying their costs.
11. Prioritize Linux-native, maintainable implementations and avoid fragile hacks tied to one Hyprland release.
12. Commit logical units of work and keep PRs reviewable.

## Required Execution Order

- **Milestone A — Stabilization:** Complete tasks 1–4, establishing a reliable baseline and shared architecture.
- **Milestone B — Gaming performance:** Complete tasks 5–10 and validate resource release before starting major rendering expansion.
- **Milestone C — Parallel development:** Begin installer and theming tasks 11–15, core functionality tasks 16–21, and shader tasks 22–26 on separate branches.
- **Milestone D — Integration:** Merge independently verified components into a release candidate. Resolve conflicts and rerun regression tests.
- **Milestone E — Release readiness:** Complete tasks 27–30, including profiling, compatibility validation, documentation, and rollback testing.

## Final Standard

The shell must deliver three things simultaneously:

- **Visual originality:** A recognizably unique technical interface with carefully designed shaders, motion, and interaction.
- **Gaming compatibility:** Minimal incremental GPU/VRAM overhead during fullscreen games, with no unnecessary background rendering.
- **Engineering quality:** Predictable state management, reliable installation, maintainable code, graceful error handling, and measurable performance.

The goal is not merely to complete a list of features. The result should feel like one intentionally engineered system, not a collection of unrelated visual experiments.

## Status

| Task | State | Notes |
|------|-------|-------|
| 1 | In progress | Merge of `codex/astra-visual-language` into PR #1 |
