# Review November 2026: engineering second opinion (Sol)

Read-only advice (agent-sync task REVIEW-SOL), recorded verbatim. Opus's synthesis is in REVIEW.md.

Read-only review for **REVIEW-SOL**. I read `FACTS.md` first and spot-checked the paths below. No files or sync state changed. The hub still names Claude/UI-016; I treated this as an advisory assignment.

Verification: an inline Node runner using `runAll([config, tokens, tour], ...)` passed **47 tests, 0 failures**. Direct Node probes reproduced both structured-value validation holes. I did not run pytest, Quickshell, Hyprland or GPU measurements. Window-management and NVIDIA performance assessments below are expectations requiring runtime verification. Visual choices remain Astra’s.

1. **Config correctness**

   **(a) CLI clobber — M; high benefit; independently shippable.** `Config.setValue()` builds the entire replacement from cached `raw` at [Config.qml:115](shell/core/Config.qml:115). CLI `write_theme_values()` atomically replaces the file at [cli.py:237](installer/aerolith_install/cli.py:237), through `os.replace()` at [manifest.py:33](installer/aerolith_install/manifest.py:33). Config itself documents missed replacement events.

   Minimal safe mitigation: serialize shell saves, explicitly reload before writing, and continue from `onLoaded`. Compare that **freshly read text** with the previous `diskText`; if different, adopt it and return “configuration changed; retry.” Never compare two cached strings or assume `reload()` completed synchronously. Preserve unknown keys and reject malformed/non-object files; distinguish missing files from other read failures.

   Watching the parent directory can improve detection, but cannot prevent read/write races. Re-reading then merging the requested change preserves unrelated CLI edits, yet still leaves a TOCTOU window. A strict concurrent-writer guarantee requires a shared lock used by both CLI and shell. Atomic replacement prevents torn files, not lost updates.

   **(b) Array/map validation — S; high benefit; independent.** [config.mjs:374](shell/lib/config.mjs:374) explicitly bypasses validation for both. Reuse private `walk()` to validate the proposed subtree and reject any errors before constructing output. Do not silently persist its fallback result. Probes confirmed `[1]` succeeds for `commandCore.terminal`, and an invalid output profile succeeds through `setPath`, despite subsequent validation errors. Existing unrelated errors should not prevent repairing one valid subtree.

   **(c) Unknown-key warnings — S; useful; independent.** `Config.warnings` already exists and is populated at [Config.qml:96](shell/core/Config.qml:96). Expose path/message diagnostics through Settings, with counts in IPC. Preserve keys; distinguish warnings from errors. Risk: noisy repetitive notifications—use a persistent diagnostics view, not a toast per reload.

   **(d) Retired rows — S; modest benefit; independent.** Add schema metadata such as `deprecated`/`settingsHidden`, consumed by `buildRows()` at [SettingsBay.qml:43](shell/modules/settings/SettingsBay.qml:43). Hide `display.output` and `display.warnOnMultipleDisplays`, retaining compatibility parsing. An explicit skip list is the smallest patch; never infer status by parsing descriptions.

2. **Live preview with Apply/Cancel**

   **M for appearance-only; L for every setting. High benefit; ship after write correctness.**

   Keep committed `raw` separate from a partial `previewRaw`. Derive `data` by schema-aware merging and validation. Add `beginPreview`, `setPreviewValues`, `applyPreview`, `cancelPreview`, and transactional `setValues`: construct and validate the whole batch, publish one data replacement, persist once.

   Existing bindings largely follow automatically: accessors derive from `data` at [Config.qml:54](shell/core/Config.qml:54), Theme reads `Config.theme` at [Theme.qml:17](shell/core/Theme.qml:17), and Settings reads `Config.data` plus `revision` at [SettingsBay.qml:69](shell/modules/settings/SettingsBay.qml:69). Settings and Personalize should share this singleton transaction and mutation API, including SchemePicker’s selection callback, rather than maintaining separate drafts.

   Whole-schema validation is reasonable for this small schema; actual cost is unmeasured. Coalesce slider updates to one per frame. Repainting and surface recreation may dominate validation.

   Watcher events update the committed base, then reapply the draft. Preserve unrelated external changes; flag same-path conflicts against the transaction’s starting values. Apply must re-read again. Keep disk errors and draft errors separate.

   Drafts never call `setText()` or Store. Cancel restores current committed data; closing cancels unless ownership transfers between customization surfaces. Crashes discard drafts. Clear the draft only after successful save; serialize pending saves and retain retryable state on failure.

   **Limit preview to appearance keys initially.** Notification-server changes create/destroy a service at [Notifications.qml:48](shell/services/Notifications.qml:48); cancellation cannot recover dismissed notifications. GPU selection is startup-probed. Also separate committed-change signals from preview signals: [AppThemes.qml:17](shell/services/AppThemes.qml:17) currently reconciles `diskText` with effective theme state. External app-theme writes must follow successful commits only.

3. **Presets, import and export**

   **M; substantial reuse; independently shippable after batch writes, with preview optional.**

   Use partial nested config objects as payloads, optionally wrapped with preset name and format version. Add `Paths.presetsFile = configDir + "/presets.json"` beside [Paths.qml:27](shell/core/Paths.qml:27). This is user data, not disposable runtime Store state.

   Reuse `walk`/`validateConfig`, but reject import errors rather than applying forgiving defaults. Bound file size, nesting and entries; reject dangerous property names. Report unknown settings and unsupported newer versions. Export appearance keys by default, excluding installation metadata, AI settings and command-launch configuration.

   Define merging explicitly: supplied leaves override; omitted leaves survive; arrays replace. For `display.outputs`, merge by exact output name and supplied field, retaining other outputs and disconnected entries. Exclude output assignments from portable presets unless requested. Note that [schemaAt():352](shell/lib/config.mjs:352) cannot traverse map entries; output identifiers need structured paths, not dotted-string splitting.

   Reuse the backup location and copy-before-replace approach from [cli.py:1086](installer/aerolith_install/cli.py:1086), preferably through a shared installer helper. Add collision-resistant stamps—the existing seconds-only directory can collide. Backup once on import/Apply, never per preview movement. Risks are merge ambiguity and accidentally exporting machine-specific or executable settings.

4. **Customization keys**

   These are systems feasibility assessments; implementation would require Astra’s visual review.

   | Feature | Assessment, benefit and risk | Independent? |
   |---|---|---|
   | Accent/palette | **M.** Reuse `theme.palette`, [resolvePalette():92](shell/lib/tokens.mjs:92), `contrast()` and `MIN_TEXT_CONTRAST=4.5`. Warn/reject unknown roles; check text and semantic foregrounds against actual backgrounds. Initially restrict editor colors to opaque RGB: `contrast()` ignores alpha rather than compositing it. Valuable; arbitrary palettes can erase status distinctions. | Yes |
   | Type scale | **M.** Add a bounded font multiplier at [Theme.qml:87](shell/core/Theme.qml:87). Useful accessibility improvement, but fixed-height rows and directly sized text require overflow checks. Existing `uiScale` is cheaper today. | Yes |
   | Strip visibility | **S–M.** Existing indicators have local `visible` bindings at [FlightStrip.qml:167](shell/modules/strip/FlightStrip.qml:167). Useful low-cost toggles; preserve access to errors and active screencast status. | Yes |
   | Strip ordering | **L.** Replace hand-built layout with stable item IDs and delegates; handle unavailable items, duplicates, width pressure and picker ownership. Low initial value; defer. | Yes, later |
   | Ground widgets | **M.** Toggle/load existing children in [Instrumentation.qml:88](shell/components/Instrumentation.qml:88). Useful; hidden targets must disappear from tour anchors and release demand where relevant. | Yes |
   | Workspace names | **M for display aliases.** Numeric cells originate at [WorkspaceTape.qml:14](shell/modules/strip/WorkspaceTape.qml:14). Add bounded labels keyed by numeric ID; retain numeric dispatch. Actual Hyprland renaming is broader and not worth coupling initially. | Yes |
   | True black on LCD | **S for background only.** Reuse palette `obsidian`; per-output control belongs near [DisplayProfile.qml:18](shell/core/DisplayProfile.qml:18). Low benefit; do not enable OLED idle policy merely to select black. | Yes |
   | Transparency/blur | **L; defer.** Strip paints an opaque window background at [FlightStrip.qml:34](shell/modules/strip/FlightStrip.qml:34). Compositor blur needs transparent surface regions and matching layer rules; an opacity token alone is insufficient. Risks: wallpaper-dependent contrast, compositor/GPU work, NVIDIA power draw and fullscreen recovery. Keep OLED surfaces opaque and low-effects authoritative. No measured NVIDIA cost supports promising this cheaply. | Technically yes; poor priority |

5. **Welcome integration**

   **M–L; useful; can ship without Personalize or presets. Recommend an in-process, lazily created `PanelWindow`.**

   Reuse [TourHost.qml:8](shell/modules/tour/TourHost.qml:8) and [NetworkPicker.qml:9](shell/modules/strip/NetworkPicker.qml:9): explicit output, exclusive keyboard focus, lock/fullscreen gates, destruction on close.

   A `FloatingWindow` offers ordinary movable/alt-tab/window-rule behavior, but introduces a new focus and lifecycle path here. Prefer it only if persistent desktop-window behavior is a requirement. A separate qs config duplicates service/config plumbing and needs IPC synchronization; not worth it for this feature. AiLoader’s optional-file probing is appropriate only if Welcome is genuinely optional.

   Data sources:

   - Add `Paths.manifestFile`; read `aerolith_version` from state metadata, with missing/corrupt fallback. [paths.py:55](installer/aerolith_install/paths.py:55) defines its location. Label this **installed version**. Ship immutable build metadata beside the shell for the **running version** after upgrades.
   - Reuse outputs, config diagnostics and tour state from services/[ControlSurface.status():72](shell/modules/ControlSurface.qml:72).
   - Reuse Telemetry GPU fields, but `gpuDevice` is a sysfs path, not a product name: [Telemetry.qml:254](shell/services/Telemetry.qml:254). Unknown telemetry must remain “unavailable.”
   - Add Quickshell/Hyprland version fields using existing [checks.py:67](installer/aerolith_install/checks.py:67) helpers. These report executable versions; running compositor identity needs its IPC version.
   - Use `Exec.run([cli, "status", "--json"], ...)` for installation details. Run doctor on demand, cache results, prevent overlapping requests. Doctor hashes installed files and may probe AI, so avoid startup execution. [Exec.qml:93](shell/core/Exec.qml:93) provides argv validation, bounded output and timeout; descendant termination still needs verification. Never construct shell commands from diagnostic content.

   Resolve the CLI consistently for user and packaged installs; Python layout currently ignores QML’s `AEROLITH_CONFIG_DIR/STATE_DIR` overrides, so prevent diagnostics accidentally inspecting another installation.

   Add schema boolean `welcome.showOnStartup`, read once after config/state readiness; it controls Welcome opening, not shell autostart. Manual opening remains available. Centralize first-run ordering: **Welcome → explicit tour handoff**, with Tour’s automatic start suppressed until that decision. Never map both exclusive surfaces concurrently.

   Register `welcome.open`, an IPC target, Help/Settings actions, and optionally `AeroShortcut` plus conflict-checked `DEFAULT_BINDS` at [hypr.py:38](installer/aerolith_install/hypr.py:38).

   Install an allowlisted offline help bundle: introductory README, CONFIGURATION, COMMANDS, ALPHA and themes guidance. Keep relative links/assets intact under `<data-root>/docs`, resolving from `shellDir/..` for user and `/usr/share/aerolith` layouts. Extend [install_core():597](installer/aerolith_install/cli.py:597). Replace dead INSTALLATION/INTEGRATIONS references with real documentation; packaging scripts referenced by tests are absent here, so package delivery needs separate verification.

6. **Tour improvements**

   **Anchors: M; high maintenance benefit; independent.** Replace copied equations at [TourHost.qml:33](shell/modules/tour/TourHost.qml:33) with a registry keyed by output and anchor name. Targets publish their actual bounds using `mapToItem` into their own surface root, plus that surface’s output-relative origin.

   Ground, Strip and Tour are separate windows: do not assume cross-window mapping works. Validate coordinate conversion on real Wayland. Update on layout/scale/visibility changes, unregister on destruction, and use generation-safe removal during loader replacement. Missing targets should produce explanatory steps without highlights. No polling or retained dead Item references.

   **Manual start: S; independent.** Remove `enabled` from presentation safety eligibility at [tour.mjs:19](shell/lib/tour.mjs:19); retain it only in automatic-start policy. Update Registry availability at [Tour.qml:83](shell/services/Tour.qml:83). Keep readiness, lock and fullscreen gates.

   **Resume: M; independent.** Extend [Store.qml:17](shell/core/Store.qml:17) with versioned `stepId` and incomplete progress; save at transitions, validate restored IDs, and distinguish Resume from Replay. Preserve completion on replay. Costs: small extra writes; immediate restart durability still depends on save completion.

   **Contextual hints: M; defer broad coverage.** Reuse anchor IDs and versioned dismissal state. Start with a few explicit hints; uncontrolled automatic hints become interruptions and require focus arbitration.

7. **Installer/integration**

   - **Systemd — M; high benefit; independent.** Explicit `--startup systemd` should install, daemon-reload and enable the unit. Current [cli.py:651](installer/aerolith_install/cli.py:651) merely prints enable instructions. Avoid unconditional `--now`: confirm session environment/target readiness and avoid duplicate Hyprland startup. Handle unavailable user bus, switching startup modes, rollback and ownership of enablement.
   - **Namespaces — S; independent.** Add exact tour/network/bluetooth namespaces to [hypr.py:31](installer/aerolith_install/hypr.py:31), and Welcome when introduced. Test both dialects; avoid a broad wildcard.
   - **Offline update comparison — M; independent.** Compare installed metadata with the selected local checkout during install/status. Record commit/build identity because `0.1.0a1` alone cannot distinguish revisions. Report “different local source,” not “latest available.” Handle missing checkout, dirty trees and packaged mode; never import/execute checkout Python merely to obtain its version.
   - **Doctor JSON — M; independent.** Refactor [cmd_doctor():1028](installer/aerolith_install/cli.py:1028) into structured check collection plus text/JSON renderers. Preserve failure exit codes and emit JSON for partial failures. Add per-check/overall budgets; repair the obsolete single-display warning first.

8. **Corrections to FACTS**

   - “No contrast check” needs qualification: standard `resolvePalette()` lacks it, but OLED repairs foreground contrast at [tokens.mjs:136](shell/lib/tokens.mjs:136).
   - “Every surface paints opaque” is too broad. Tour and NetworkPicker have transparent windows; standard Ground does too. This does **not** establish useful configurable translucency.
   - Unknown palette roles survive config validation without warnings, then disappear during palette resolution; they are not removed from persisted raw config. Confirmed by probe.
   - `aerolith status --json` exists; `doctor --json` does not: [cli.py:1315](installer/aerolith_install/cli.py:1315). Diagnostic examples must distinguish them.
   - Fixed status colors are scheme defaults, but supported palette overrides can change them.

Dependency-ordered implementation:

1. **Safe fixes now:** `config.mjs`, `Config.qml`, SettingsBay, `tour.mjs`, Tour.qml, `hypr.py`, `checks.py`. Add JS rejection/compatibility tests; pytest coverage for both rule dialects and display checks; a headless atomic-CLI-replace → Settings-write regression. Test repeated saves and save failure.
2. **Config foundation:** Config plus new pure merge/transaction helpers; SettingsBay/SchemePicker and AppThemes. Test batch atomicity, conflicts, unknown-key retention, watcher updates, Cancel, failed Apply, crash-with-draft and absence of app-theme exports.
3. **Anchors/version foundation:** new anchor registry; target components, TourHost, Paths, installer metadata/status. JS tests for registry lifecycle and build comparison; headless scale/output hotplug/fullscreen tests and packaged-path fixtures.
4. **Features:** Astra’s Personalize consumes the shared transaction; presets add bounded import/export and backups; Welcome adds startup arbitration and doctor JSON. Add JS merge/contrast tests, pytest backup/JSON/offline-link/systemd tests, and headless Welcome → tour, manual replay-disabled, resume, lock/focus and clean-close scenarios. Real NVIDIA blur testing remains a prerequisite for any later blur feature.
