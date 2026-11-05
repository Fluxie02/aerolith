# Astra decisions — REVIEW-ASTRA

5 November 2026. Review and proposal only; no shell implementation.
Authority: [FACTS](FACTS.md), [owner brief](../OWNER-BRIEF-2026-10.md),
[OLED decisions](../oled/ASTRA-DECISIONS.md), [network/tour results](../network-tour/RESULTS.md).
Spot-checked the twelve requested source files. Preserve PIYTI, maintained
THEARS, twelve schemes, Bezel housings and the three-bay Deck. Borrow Hello's
useful entry points and short explanations; retain AEROLITH's composition.
Everything below describing new behavior is proposed.

1. **Visual fixes: repair consistency and fit before adding surfaces.**

   - **H1 — fix; Sol mechanical, Astra checks captures.** Give every lock
     surface its output's complete DisplayProfile, including secondary black
     backings. Keep the existing clock/form hierarchy and authentication
     behavior. Use OLED near-black planes and full-contrast functional text;
     hide idle ornament, never the password prompt or errors. No lock animation loop.
   - **H2 — fix; Sol mechanical.** Session, OSD and notices take every colour
     from their destination profile, geometry/type/motion from Theme. Preserve
     OLED plane separation and opaque focus edges; test actual selected/tinted fills.
   - **M1 — fix; Sol systems, Astra acceptance.** Tour targets report measured
     rectangles; shared Ground geometry owns the remaining composition.
     ChordSlot owns its constraints. Stop copying equations before changing fit.
   - **M2 — fix; Astra defines fit, Sol centralizes policy.** Compute available
     logical work area after strip reservation and UI scale. Share shell-wide
     compact classification (below 1500 wide or 850 high) across
     Strip/Ground/Deck/Tour; retain explicitly
     named local minimum-size rules for Bezel and Lock. Density changes required
     content size, not competing px/du thresholds. Require two Theme gaps between
     compact stations and either strip edge, including comfortable density.
   - **M3 — drop unused internal tokens/components after reference checks;
     Sol mechanical.** Do not instantiate CircularField, MetricTape or Readout
     merely to justify them. Preserve public palette keys and component APIs
     consumed by optional packages; no visual redesign or speculative abstraction.
   - **M4 — fix; Astra copy, Sol substitutions.** Remove obsolete rail numbers;
     use SEARCH, WINDOWS, SYSTEMS, SETTINGS, HELP and AI where installed.
     Replace ambient “PIYTI / SATURATED” inscriptions with useful state or omit
     them. Retain the names in About and explanatory installation metadata;
     intensity remains Saturated / Insane with “decoration level” helper text.
   - **M5 — fix; Sol mechanical.** Say “status strip”; describe its configured
     edge when relevant. Hidden-strip guidance offers Search/Settings directly.
   - **Static vernier — fix; Astra motion specification.** Keep its geometry;
     sweep once on workspace change, using existing normal duration and gates.
     Reduced/off is static. No new ambient clock or invented telemetry.
   - **Workspace mismatch — fix; Sol data, Astra overflow.** Ring and strip
     use the same ordered set of configured plus existing workspaces. Preserve
     station spacing; overflow uses a labelled “More workspaces” row, including
     the active name. Never silently omit a live workspace. Per-output focus
     correctness remains a separate systems dependency. Sol must also resolve
     refresh/ambient cadence per output, not from primary alone.
   - **Portrait/ultrawide/1080p — fix; Astra layout.** Portrait uses the existing
     compact station row instead of an off-screen orbit. Cap Now playing at
     420 and the app register at 1120 logical units before UI scaling; align
     them to existing bearings. Bound the 1080p window register before the
     second bearing and scroll its contents. Preserve primary-only app links;
     do not stretch instruments across ultrawide empty space. Verify 4K ×1.5
     remains unchanged in character.
   - **Minor residue — fix mechanically, defer broad refactors.** Remove dead
     InstrumentField branches; normalize raw ticks, tint alphas, panel opacity
     and letter spacing to existing role tokens. Reuse selectable rows/popup
     housing when touched; a shared canvas engine is outside this review.

2. **Personalize belongs inside Settings; one schema owns every setting.**

   Add Personalize / All settings modes, reachable from Welcome and Search,
   without a fourth main Deck bay. Reuse SchemePicker specimens and Settings
   rows. Schema metadata supplies labels, groups, bounds, capability/restart
   hints and custom map/array editors; advanced rows expose the same values.
   Hide retired/deprecated keys from editing. Avoid a second config model.

   | Choice | Priority and decision |
   |---|---|
   | Scheme/accent | **Must:** twelve schemes; **should:** advanced palette-role editor with swatch, hex, reset and contrast diagnostics. Keep status meanings and derived appLink; no independent appLink override. |
   | Transparency/blur | **Won't:** neither control nor compositor edits. Keep opaque mineral planes; variation comes from scheme, intensity and black backing. Glass would weaken hierarchy and introduce continuous composition cost. |
   | True black | **Should:** separate “Black background” appearance choice per output, available on LCD too. Retain distinct near-black planes. OLED remains a separate profile with its established idle policy; black alone promises no OLED protection. |
   | Type size | **Must:** retain overall UI scale; **should:** independent text-size steps 100/112/125/150%, with row/header growth and reflow. Fonts get installed-family pickers and fallback samples. |
   | Spacing | **Must:** Compact / Standard / Comfortable, using existing density tokens; never shrink text to fit. |
   | Motion/effects | **Must:** Full / Reduced / Off, low effects and Saturated / Insane; one labelled “Play transition” sample on request, no looping preview. |
   | Strip | **Must:** retain visibility, edge and existing clock/telemetry controls; **should:** per-item visibility/order with keyboard Move up/down alongside drag. Privacy and critical warnings stay available; Help/Welcome remain reachable without a strip. |
   | Ground | **Must:** retain enable; **should:** independent media, telemetry and app-register toggles. **Could:** hatch/stations toggles with clear alternate commands. |
   | Workspace names | **Should:** ID/name rows, shared by ring, strip and Windows; names wrap in editors and elide with full-name disclosure elsewhere. IDs remain stable. |
   | Per monitor | **Must:** named-output picker for existing strip/ground/OLED settings; global schemes/type/motion by default. **Could:** per-output text/density overrides after mixed-scale validation. Disconnected output settings remain labelled and retained. |
   | Presets/files | **Must:** immutable Default and Readable presets plus reset-to-saved; **should:** named user presets and versioned JSON import/export. Presets describe values, not new themes. |

   **Live preview is a transaction, not today's immediate-save behavior.**
   Entering Personalize captures the saved baseline; edits resolve an in-memory
   draft through all shell visual consumers on all outputs, including surfaces
   opened later. No config writes or external application-theme refresh before
   Apply. Cancel restores the baseline. Apply validates and saves once, then
   allows existing consented app-theme refresh; label this boundary explicitly.
   Leaving a dirty editor offers Apply / Discard / Keep editing. Lock, crash
   or output loss discards the draft safely. A scale/visibility change requires
   “Keep preview” within 20 seconds or reverts that change; this one-shot recovery
   timer exists only during an active preview.

   Contrast guard checks all text-bearing roles at ≥4.5:1 on actual normal,
   selected and tinted fills, under standard, black and OLED resolution. Invalid
   edits retain the last safe draft; show failing pair/ratio and explicit Repair,
   never silently alter colour. Validate map keys and imports too. Reconcile
   external edits before Apply; conflicting paths require reload/review, not
   overwrite. Broken JSON blocks saving while preserving the last good display.

   **Wireframe, 1120-wide housing:** 176-unit section rail (Colour, Text & space,
   Motion, Strip & Ground, Displays, Presets); flexible control register; 300-unit
   specimen inspector. Header reads PERSONALIZE / UNSAVED PREVIEW. Inspector
   shows labelled sample text, selected row, status/error, strip and workspace
   name, resolved for the selected output. “View desktop” temporarily reduces
   the editor to a fixed Return / Apply / Cancel bar, revealing the real draft.
   Footer stays reachable while controls scroll. Compact: section selector above
   one column; specimen is an expandable first row, never a second scroll pane.

   Tab/Shift+Tab crosses sections, controls and footer; arrows navigate/change
   rows, Enter edits/chooses a scheme for preview, Space toggles. Escape cancels
   a field before leaving the editor; focus returns to its caller. Colour alone
   never indicates selection. Imports show a change summary and unsupported keys
   before preview; export only allowlisted appearance settings, excluding AI,
   routines, binds, direction and startup. Map output-specific values explicitly;
   never assign another machine's connector names automatically.

3. **Welcome is a useful front door, with one first-run flow.**

   Use one lazy, bounded layer-shell surface with a Bezel housing, not a new
   desktop dashboard. Small mono capitals identify sections; plain sans sentences
   explain actions. Colours all come from its output profile; dimensions, type
   and motion come from Theme. Reuse row selection, recessed inputs, registration
   marks and near-black OLED planes. Use existing fontMd body, fontXl title,
   fontSm secondary text; grow layout for larger type.

   **Text wireframes; dimensions are logical units before theme UI scaling.**
   At 1920×1080, center a 1120×820 maximum housing in the work area excluding
   the strip. Use 24-unit inner margins and a 24-unit gutter; columns are
   680/368. At 3840×2160 scale 1.5 the work area is approximately 2560×1440:
   keep the same cap and typography, producing a 1680×1230 physical housing.
   At usable width below 1000 or height below 800, use a single column capped
   at 880, with 16-unit outer margins. At 1280×720, portrait and enlarged type,
   scroll the body; header and action footer stay fixed. No horizontal scroll.

   ```text
   WELCOME                           output name     Close
   AEROLITH
   Search, switch windows and control your desktop.
   ┌ 680 ─────────────────────────┬ 368 ──────────────────┐
   │ START HERE                   │ FIRST-RUN CHECKLIST  │
   │ Take tour / Resume · step n/5 │ real checks + actions│
   │ Personalize →                │                      │
   │ Displays →                   │ LAUNCH ON STARTUP    │
   │ System settings →            │ detected method/state│
   │                              │                      │
   │ LEARN & MAINTAIN              │ SYSTEM INFO          │
   │ Documentation →              │ version / outputs    │
   │ Updates →                    │ Show details / Copy  │
   │ Troubleshooting →            │                      │
   └──────────────────────────────┴──────────────────────┘
   Show Welcome on startup [ ]                 Start using
   ```

   In compact mode order cards: overview, tour, checklist, personalize, displays,
   system settings, startup, documentation, updates, troubleshooting/system info.
   Cards are registered sections separated by rules inside one housing, not
   independent floating rectangles. Overview expands to five short explanations:
   Search opens apps/actions; Windows finds/moves windows; Systems shows resource
   use; the hatch holds parked windows; the strip offers status/connections.
   List actual available actions; do not advertise unavailable controls.

   **Destinations and truthful state:** Personalize opens decision 2; Displays
   selects an output for shell placement/profile and explains that resolution
   and refresh belong to external system settings. System settings lists detected
   tools or readable manual guidance, never an invented universal launcher.
   Documentation opens installed local user docs; missing docs show an explicit
   “Open online documentation” action. Installing those docs is a dependency.
   Updates says “No automatic update check”; show installed version and the
   documented source-install procedure (`git pull`, then `./install.sh`) only
   for a verified source install. Other installations get method-specific
   guidance or “Update method unavailable.” No automatic update execution.

   Troubleshooting shows Config.errors first, each with path/message and a
   repair destination; offer explicit Run diagnostics and Copy report. System
   info includes AEROLITH manifest version, Quickshell/Hyprland versions and
   dialect, GPU vendor/device/status, outputs with mode/scale/profile, and config
   errors. Reuse IPC status, Telemetry and installer status/version functions;
   these facts exist but need a systems adapter, not invented shell properties.
   Show Unavailable rather than zero/healthy on failure. Refresh only on action
   or existing events while open. Preview a report before copying/sharing it.

   **Checklist checks reality:** Configuration valid (Config.errors/parse state);
   Output selected (resolved primary exists); Startup configured (detected
   mechanism and effective enabled state); Tour finished (versioned completion).
   Personalization is optional and never marked required. Opening a card never
   earns a check. Unknown and needs-attention differ from passed; rows expose
   the corrective action. The systemd service file's existence is insufficient.

   **Launch on startup is separate from Show Welcome on startup.** Present a
   toggle with detected Hyprland/systemd/manual method and pending/error state.
   An explicit toggle action asks the systems adapter to reconcile the selected
   method, avoid duplicate launch paths and verify the result. Never enable a
   service or edit Hyprland simply because Welcome opened. If detection or safe
   mutation is unavailable, show explanation and setup instructions.

   First eligible launch opens Welcome on the primary output, held while locked
   or fullscreen. It replaces tour auto-start. “Take tour” closes Welcome before
   starting; finishing returns to the checklist, skipping goes to the desktop.
   “Start using” dismisses onboarding without requiring the tour. Persist these
   distinct states and an incomplete tour's step; upgrades do not restart onboarding.
   Manual opens use the focused output, falling back to primary; only one surface
   exists and output removal relocates it. An active personalization draft must
   be resolved before starting the tour.

   Proposed Registry command `welcome.open` (“Welcome”), CLI `aerolith welcome`
   and IPC entry share one action; Help and Settings link it. Strip branding's
   context menu offers Welcome without adding a permanent indicator. Offer an
   optional configurable shortcut, unbound by default; display actual resolved
   binds or “Not assigned,” never shortcut names masquerading as key combinations.
   Tab order follows the wireframe's reading order, Enter activates rows, Space
   toggles, Escape closes, and pointer rows have full-width targets. Return from
   child Settings/Help restores card focus and scroll. Existing Theme entry/fade
   durations apply; reduced removes travel, off is immediate.

   **Modularity and cost:** registered cards declare ID, order, capability,
   view, action and optional check provider; unavailable capabilities render
   honest fallback guidance. Construct only while open, release demand/focus on
   close, and follow existing fullscreen surface-release rules. No network calls
   on open, polling/update daemon, background animation, automatic scans,
   package installs or unsolicited config edits. New namespace/layer rules and
   process lifecycle belong to Sol/Claude, not visual implementation.

4. **Tour: five steps are enough; improve continuity and discoverability.**

   Keep hatch, workspaces, Search, used apps and strip. Show “2 of 5 · Workspaces”
   with Back / Next / Skip and a real Settings action at the end. Explain one
   capability per step; contextual hints appear on keyboard focus or deliberate
   hover and vanish on dismissal, with no idle loop. Target measured rectangles;
   if hidden, explain its alternate command rather than point into empty space.
   Save step/version on advance; Help, Welcome and Settings offer Resume and
   Restart. Separate automatic-onboarding preference from explicit replay.
   Skip records “skipped,” not “completed,” but prevents automatic replay.
   Preserve Enter/Right, Left and Esc; restore prior application focus on exit.

5. **One peer review; implementation gates and priorities.**

   Current NetworkPicker now gates password input and reports immediate errors,
   addressing the earlier NB-2 finding in part. **Low — misleading guidance,
   NetworkPicker.qml:61–63:** `!takesPassword` does not establish enterprise
   authentication, yet the text promises username/certificate setup. Minimal
   correction: “This sign-in method needs your network settings” unless actual
   security metadata proves enterprise. One correction/review cycle; escalate
   unresolved alternatives to the owner. This is a source review, not hardware evidence.

   Follow-up acceptance: 1080p, 4K ×1.5, 1280×720, portrait, ultrawide, comfortable
   density, large text, both strip edges, mixed OLED/LCD and output removal;
   all motion modes, preview rollback/conflicts, keyboard/focus, fullscreen
   release and zero closed-surface demand. Hardware OLED/NVIDIA and real startup
   need systems verification. Text wireframes are specifications, not runtime captures.

   Document checks: `wc -w docs/design/review-2026-11/ASTRA.md` below 2500;
   `git diff --exit-code -- shell/` passed; whitespace and local links checked.
   No runtime tests: documentation only.

   - **Quick wins:** H1/H2 profile parity, useful labels, edge-aware tour copy,
     Help/Settings tour links. Benefit: readable OLED and discoverable controls;
     risk low except lock surfaces require all-output/PAM regression checks.
   - **Medium:** bounded layouts/shared targets, workspace overflow, tour resume,
     Welcome with installed docs and truthful status adapters. Benefit: fitting,
     coherent first use; risk mixed-scale geometry, persistence and focus handoff.
   - **Larger:** staged Personalize, validated presets/palette, strip ordering,
     widget controls and startup reconciliation. Benefit: safe ownership of the
     desktop; risk stale config writes, external-theme side effects and migration.
     Fix atomic-replace watching and map/array validation before shipping Apply.
