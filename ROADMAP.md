# AEROLITH — Repository-Grounded Development Roadmap

The owner's roadmap, recorded verbatim. All three agents follow it; progress is
tracked in the Status table at the end.

- **Audit date:** 26 October 2026
- **Repository:** Fluxie02/aerolith

**Roles:**
- **Opus 5.5:** Systems architect, integration lead, final reviewer.
- **GPT-6 Astra:** Visual architecture, rendering, shaders, motion and visual QA.
- **GPT-6.1 Sol:** Bounded implementation, automation, tests, installer and mechanical integration.

## Phase 0 — Reconcile the Existing Work

| ID | Task | Owner | Priority |
|----|------|-------|----------|
| A01 | Reconcile PR #1 with codex/astra-visual-language and newer main changes. Preserve the actual SHEAR → THEARS/PIYTI → Counterphase → Spectra → Smoothness work. | Opus | P0 |
| A02 | Compare the three code histories by file and component. Resolve any incompatibilities between Astra's theme components and newer systems infrastructure. | Opus + Sol | P0 |
| A03 | Run baseline Node, Qt V4, pytest, headless smoke, full, Deck, notification, AI and installer tests on the integrated branch. | Sol | P0 |
| A04 | Validate the updated three-agent bridge against real authenticated Codex sessions and fix any account, model-ID, worktree or agent-sync issues. | Opus | P1 |
| A05 | Separate bulky historical verification assets from deployable sources. Keep reproducibility manifests, representative media and meaningful failed-case evidence. | Sol | P1 |

**Gate:** The integrated branch compiles and passes the existing relevant tests. Record the exact commit SHA. Do not declare integration complete merely because Git reports a successful merge.

## Phase 1 — Fullscreen and Game Resource Management

| ID | Task | Owner | Priority |
|----|------|-------|----------|
| B01 | Implement an event-driven fullscreen state for the selected Hyprland output. Handle window focus, fullscreen mode changes, output removal and stale compositor state. | Opus | P0 |
| B02 | Connect Theme.ambientSuspended to the fullscreen lifecycle and stop visual effects before teardown. | Opus | P0 |
| B03 | Suspend and unmap Ground, Flight Strip, Deck and Notices. Unload GPU-backed visual content and release resources where supported. Preserve the nonvisual services. | Opus + Sol | P0 |
| B04 | Implement restoration without repeating first-boot animations, leaking render resources or losing pending notifications. Explicit shell interaction must have a defined wake policy. | Opus + Astra | P0 |
| B05 | Test twenty fullscreen enter/exit cycles with both directions and intensities, active notifications, open Deck, focus changes and optional thumbnails. | Sol + Opus | P0 |
| B06 | Profile actual shell GPU memory, CPU wakeups, game frametime impact and direct-scanout eligibility. Record before/during/after behavior on real hardware. | Opus | P0 |

**Gate:** The shell becomes visually and computationally inactive during qualifying fullscreen gaming, without breaking essential services or subsequent restoration.

**Important:** Target near-zero incremental GPU memory attributable to AEROLITH. Measure the result rather than promising an absolute zero-VRAM process.

## Phase 2 — Installer, Design Selection and Application Themes

| ID | Task | Owner | Priority |
|----|------|-------|----------|
| C01 | Add the installation-only THEARS/PIYTI selection using Astra's existing visual seam. PIYTI is the forward design; THEARS remains supported. | Sol; Opus reviews | P1 |
| C02 | Persist the chosen direction, support clean reinstall/upgrade behavior, and make sure Settings does not expose an unsupported live direction switch. | Sol | P1 |
| C03 | Offer Saturated/Insane intensity during installation, reusing the already implemented theme.intensity configuration and command. | Sol | P2 |
| C04 | Integrate the existing 12 Spectra schemes into the installer without duplicating palette definitions. | Sol | P2 |
| C05 | Implement opt-in app-theme deployment using existing assets for GTK, Qt, terminal apps, Hyprland and supported application themes. | Sol + Opus | P1 |
| C06 | Implement supported app-theme refresh on scheme change, with per-app consent, safe config preservation, backup, rollback, race handling and compatibility checks. | Opus + Sol | P1 |

**Gate:** Both visual directions install cleanly. External app theming is optional, reversible and based on the already generated color-scheme assets. Never overwrite entire application configurations or install third-party modification systems silently.

## Phase 3 — Complete Existing System Interfaces

| ID | Task | Owner | Priority |
|----|------|-------|----------|
| D01 | Integrate the existing OsdView.qml with Audio and microphone state changes. Add a proper OSD host with expiry, queueing and focus-safe layering. | Sol + Opus | P1 |
| D02 | Add a real brightness service using supported backlight interfaces, capability detection and optional external-monitor support. Connect it to the existing OSD. | Opus + Sol | P1 |
| D03 | Resolve Help/Settings notification overlap using existing NoticeStack and Deck layering. Test both intensities, compact outputs and multiple notices. | Astra + Sol | P1 |
| D04 | Correct the outgoing Deck lifecycle when motion changes to off or lowEffects during an exit. | Opus | P1 |
| D05 | Disable duplicate Hyprland layer animations for AEROLITH's own namespaces through reversible managed installer rules. | Sol; Opus reviews | P1 |
| D06 | Integrate SessionView.qml with existing power/session commands and deliberate confirmation of destructive operations. | Opus + Sol | P2 |
| D07 | Integrate LockView.qml only through a secure Wayland session-lock host and real authentication backend. Test failure states, recovery and session security. | Opus | P2 |
| D08 | Implement missing network and Bluetooth status/control services if their corresponding interfaces are required by the release scope. | Sol + Opus | P2 |

**Gate:** All real system controls function independently of visual animation, and security-sensitive functions do not depend on cosmetic interface behavior.

## Phase 4 — Shaders, Motion and Visual Refinement

| ID | Task | Owner | Priority |
|----|------|-------|----------|
| E01 | Implement the four existing requests in docs/design/counterphase/SHADER-REQUESTS.md: SHEAR bevel shading, workspace annulus relief, return-vernier light catch and Deck undercarriage shading. | Astra | P2 |
| E02 | Create reusable shader interfaces for existing semantic colors, output scale, motion mode, intensity, application direction and fullscreen resource lifecycle. | Astra + Opus | P2 |
| E03 | Profile GPU shader compilation, render targets, scene-graph memory, cache lifetime and actual shader cost. Ensure fallback geometry remains meaningful without GPU effects. | Astra + Opus | P2 |
| E04 | Revalidate high-refresh animations on a real GPU-backed 60/120/144 Hz output. Fix visible pacing problems in Deck docking, bay changes, Spectra switching and startup transitions. | Astra + Opus | P1 |
| E05 | Conduct a final visual consistency pass covering THEARS, PIYTI, Saturated, Insane, all 12 Spectra schemes, notifications, OSD, lock, session and app-theme adapters. | Astra | P2 |

**Gate:** Shader effects improve physical depth and visual readability without introducing idle rendering, hidden continuous workloads or significant gaming overhead. No shaders should be added merely to increase the number of effects.

## Phase 5 — Release Engineering

| ID | Task | Owner | Priority |
|----|------|-------|----------|
| F01 | Implement CI for Node, Python, Qt compatibility, formatting, generated schemes and installer correctness. Include headless integration jobs where runner capabilities permit. | Sol | P1 |
| F02 | Fix the documented provider-specific Codex AI fixture mismatch instead of allowing a Claude-specific test to fail for Codex. | Sol | P1 |
| F03 | Validate real Arch/CachyOS installation, upgrade, configuration rollback and full uninstall on a disposable environment. | Opus + Sol | P1 |
| F04 | Benchmark idle and active CPU/RAM, frame pacing and fullscreen VRAM behavior. Compare against the existing saved measurements. | Opus + Sol | P1 |
| F05 | Produce lean release packages, updated documentation, a known-limitations list and a reproducible source/verification manifest. | Sol; Opus reviews | P2 |
| F06 | Perform final architectural review, regression testing and release-candidate approval. | Opus | P1 |

## Rules for All Three Agents

1. Reuse existing work. Before implementing a feature, search the source, relevant branch and design handoff documents.
2. Respect ownership: Opus owns critical systems contracts; Astra owns visual behavior; Sol works on bounded, testable implementation tasks.
3. Work in isolated branches/worktrees. Integrate through reviewed commits, not simultaneous edits of the same files.
4. Do not silently alter established owner decisions. THEARS is maintained, PIYTI is the forward design, intensity remains live-switchable, and direction is installation-only.
5. Maintain single-monitor correctness first.
6. Measure performance. Software rendering tests are not proof of GPU frame pacing or VRAM behavior.
7. Preserve optional AI installation, including a fully functional no-AI choice.
8. Preserve security and user configurations. Test rollback and clean removal.
9. Prioritize release-blocking systems work before optional shaders and decorative enhancements.
10. Report completion with evidence: changed paths, commit hashes, exact test commands, measured results and known limitations.

## Recommended Execution

1. **First:** A01–A04, establishing one working integration baseline.
2. **Second:** B01–B06, establishing the gaming lifecycle and proving the most important performance requirement.
3. **Then in parallel:** C01–C06 (Sol), D01–D08 (Opus/Sol) and E01–E05 (Astra), with separate file ownership.
4. **Last:** F01–F06 and final release verification.

Opus should coordinate the complete plan, delegate mechanical work to Sol, assign creative rendering decisions to Astra, and personally approve all changes to the fullscreen lifecycle and security-critical integration.

## Status

| ID | State | Evidence |
|----|-------|----------|
| A01 | In progress | |
