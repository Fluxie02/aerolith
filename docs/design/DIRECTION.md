# Phase 4 — Interleaf

Astra · UI-001 · 22 October 2026. This is the visual handoff for phases 5–6, not a claim that the production shell has been redesigned.

## Decision and evidence

Choose **Interleaf**, the unknown direction: an interface organized as a readable index of the user's work. A dark navigation margin, pale celadon reading field, large workspace numbers and a precise red rule form the identity. A workspace is a passage containing real application titles. It is recognizable through composition and typography without a logo, texture or GPU effect.

Retain Cut's opaque material discipline and Parallax's exact numeric alignment. Do not carry over Cut's room frames or Parallax's orbit. This is one direction with two useful lessons, not an average of three appearances.

| Direction | What survived rendering | What failed the comparison | Decision |
|---|---|---|---|
| Parallax | Quiet dark working state, restrained brass, clear selection. Canvas arc renders on software. | Large equal frames still allocate empty workspaces too much space. The circle contributes atmosphere but no useful relationship to the list. Faint app text shows through the overlay. | Keep precision; reject orbit and transparent working surfaces. |
| Cut | Strong opaque figure/ground, warm material, distinctive entry from the right. | The left slogan uses space needed by long titles; three tall workspace rooms clip and need scrolling before five slots are visible. Repeated frames weaken the architectural idea. | Keep opacity; reject slogan and room grid. |
| Interleaf | All four seeded titles and five workspace slots fit at 1920×1080; windows on workspace 2 read as a group. Launcher, audio and notices share the same rule/ink relationship. | A purely textual index gives less visual recognition than previews. At 720 px height it must scroll. Large idle numerals remain prominent around a floating terminal. | Choose; keep optional preview subordinate and reduce environmental emphasis in phase 5 if real-window testing shows distraction. |

These are visual judgments, not measured user-study scores. See [the overview](shots/interleaf/03-overview.png), [launcher](shots/interleaf/02-launcher.png), [working state](shots/interleaf/04-active.png), [sound](shots/interleaf/06-sound.png) and [small, motion-off state](shots/interleaf/07-small-off.png). All 22 retained PNGs total about 1.5 MiB. Reproduction and verification are in [VALIDATION.md](VALIDATION.md).

## Principles

1. **An index before a picture.** Name the task and its workspace at reading size. Previews supplement identity, never replace it.
2. **One number, one rule, one passage.** Number locates; rule selects; passage explains. These are the three defining graphical elements.
3. **Unequal content earns unequal space.** Empty workspaces are short lines; occupied ones receive the height their titles need. Audio devices and media have different proportions.
4. **Opaque where people read.** No desktop pixels beneath functional text. The software renderer carries the complete meaning.
5. **The application remains the center of work.** The large index belongs behind windows. The persistent shell is a thin reserved strip; opening the Deck is explicit, fast and reversible.
6. **Nothing pretends to know.** No inferred workspace names, invented network status, guessed percentages, fake thumbnails, decorative telemetry or progress for live streams.
7. **Motion completes a sentence.** It explains a selection or transition, then stops. It never delays an action.

## Token system

All sizes below are logical pixels before `Theme.px()` rounds by uiScale. Keep tokens in Theme/tokens.mjs in the next phase. Prototypes centralize their experimental subset in `prototypes/common/Style.qml`; the document is the complete target specification. No new user config keys or palette renames are required.

### Colour: functional roles

Existing palette names remain the public compatibility API, including `obsidian` despite the new light default. Semantic inks are separate from decorative material colours.

| Public role | Default | Meaning / use |
|---|---|---|
| obsidian | `#DCE4D9` | Environmental ground and Deck reading field; no semantic status. |
| surface | `#F0F2E8` | Input, notice and controlled reading plane. |
| surface2 | `#E3E9DD` | Selected or recessed area; never selection's only indicator. |
| grid | `#AFB9A9` | Quiet structural rules; decorative separators, not sole control boundaries. |
| text | `#202A25` | Main ink, application/window names, control values. |
| textDim | `#526056` | Secondary labels, descriptions and timestamps. Still readable text. |
| signal | `#943F32` | Actionable selection, keyboard focus rule, active navigation. Not an error. |
| caution | `#77530D` | Warning ink with explicit “Caution”, “Confirm” or reason. |
| critical | `#A52B28` | Failure, urgent notice and privacy recording state; always a word/shape too. |
| nominal | `#286140` | Completed/successful operation with “Done” or a check. |

Measured with the repository's `contrast()` implementation, minimum ratios across obsidian/surface/surface2 are: text **11.37**, textDim **5.10**, signal **5.35**, caution **5.33**, critical **5.42**, nominal **5.62**. Normal text meets 4.5:1, including the palest and selected surfaces. A disabled control may use reduced emphasis, but its reason stays at textDim contrast. User overrides remain authoritative; validate actual foreground/background pairs after applying them, including alpha in legacy overrides. Do not assume this default measurement certifies arbitrary palettes.

### Colour: material and decorative roles

| Internal token | Value | Rule |
|---|---|---|
| margin | `#202B26` | Fixed inverse navigation material and idle vertical field. No warning meaning. |
| inverseText | `#F0F2E8` | Text on margin only; 12.94:1 contrast. |
| inverseDim | `#B8C4B8` | Secondary ink on margin; 8.10:1. |
| inverseFocus | `#F0F2E8` | 4–6 px margin selection mark; selection also names its destination. |
| inverseCritical | `#FFA6A0` | Privacy/critical text on dark material only. |
| inverseCaution | `#F6D085` | Warning text on dark material only. |
| decorativeRule | signal at 100% | Idle underline; its static location has no status meaning. Never reuse a flashing error treatment. |

Inverse tokens are derived visual tokens, not new palette keys. They have fixed, contrast-tested pairings with margin. Functional foreground overrides apply to the reading field and controls. Keep margin/inverse pairings coherent when adding a future theme variant. No automatic ambient palette, time-based hue changes or new dark-mode setting is needed. Users can supply a coherent dark palette through the existing roles; validate it before calling it supported.

### Typography

| Token / role | Standard size | Weight / treatment |
|---|---:|---|
| micro | 12 | Regular; keys, timestamps, app ids. Avoid all-caps paragraphs. |
| body | 15 | Regular; functional labels and search results. |
| bodyStrong | 15 | Medium; selected action / important value. |
| reading | 20 | Regular; overview window titles. |
| navigation | 22 | Regular; expanded margin destinations. |
| query | 30 | Regular; input text. Never stretch text during entry. |
| feature | 36 | Light; now-playing title, wrap at words. |
| index | 38 | Light; workspace number in overview. Tabular alignment. |
| heading | 48 | Light; bay title. Tracking -1.5 only at this scale. |
| environment | 220 maximum | Light; current workspace number, decorative slash. Idle only, no functional information at this size. |

Primary family is the user's `fontSans`, default Inter. Preferred fallback order: Inter Variable → Noto Sans → system sans-serif. Numerical/technical family is `fontMono`, default JetBrains Mono; fallback JetBrains Mono NL → Noto Sans Mono → system monospace. QML has `font.family`, not `font.families`: use the configured family and fontconfig fallback; explicit first-installed selection may be added visually after checking available families. Fonts are not bundled and no font package request is necessary. Noto Sans/Noto Sans Mono were rendered in the small-screen check.

Use native text rendering in these prototypes. Judge production at actual scale and fractional output scaling before making it universal. Body leading 1.35; descriptions 1.4; keys single-line. Letter spacing 1–3 only on short environmental captions. Functional labels never depend on wide tracking. App ids are secondary and may elide; titles elide only when necessary, with a readable selected-title/status line. User strings are always Text.PlainText. The one escaped Fuzzy highlighting path remains the sole rich-text exception.

### Space, density and composition

Base spacing scale: **2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128**. Use 1 px only for rules. Repeated row padding is 16/18 px, not arbitrary per app. Main title and content align on one left edge. Numbers have a 100 px gutter and window passages begin at 128 px. The environmental mark starts about 120 px from the left; the inverse field occupies the right 26% of an exposed desktop. It sits behind applications and never reserves their area.

| Density | Existing strip/row/pad/gap API | New content gap / result row / body |
|---|---|---|
| compact | 24 / 26 / 6 / 4 | 12 / 46 / 14 |
| standard | 28 / 32 / 10 / 6 | 18 / 56 / 15 |
| comfortable | 34 / 40 / 14 / 8 | 24 / 66 / 17 |

Preserve existing Theme token names and values used by external modules. Add visual-role aliases instead of repurposing `rowHeight` to 56 and unexpectedly enlarging AI. Fixed card compositions must use their own measured minimum heights; larger text must grow their content rather than clip.

At standard 1920×1080: expanded margin 340 px; content begins around 400 px, ends 100 px before the right edge, bay title at y=140. At effective width below 1200 or height below 800 (pixels divided by uiScale), collapse navigation into a horizontal top rail and use 32 px content side margins. Scroll the workspace list within the available region. Keep selection in view and a fixed status/hint region below it. Add a visible scroll thumb in production. At still smaller sizes, stack media beneath devices and wrap scope/hint controls; do not shrink functional text below the density minimum. At uiScale 2 the same breakpoint is calculated in logical space, not physical resolution.

### Shape, borders and depth

Shape tokens: plane radius **0**, control radius **2**, key-cap radius **2**, circular status marker radius **50%** only for its actual meaning. No universal pill shape. Borders: structural **1 px**, control boundary/focus **2 px**, selection rule **3–4 px**, expanded margin mark **6 px**. Snap to physical pixels where feasible. A control boundary uses signal/ink at sufficient contrast, not grid alone. Rules between noninteractive passages may remain quiet.

Depth has three discrete levels: ground behind apps; opaque reading plane above apps; annotations above the reading plane. No shadows in the selected direction. Optional offset seam: 4 px, opaque margin ink, used only when overlapping same-material planes need separation. No blur, glow, mask, ShaderEffect, MultiEffect or RectangularShadow. Depth is structural and survives software rendering.

Opacity: text **1**, functional surfaces **1**, selected fill **1**, disabled glyph **0.55** with reason at full textDim opacity. Hover is an opaque inset fill, never a dimming of the whole label. No transparency under text. The Parallax comparison's 0.94 backdrop is not adopted. `lowEffects` removes even optional seams and every transition; selected state remains fully legible.

### Focus, selection and markings

Selection is a filled inset plus a red rule; keyboard focus has a separate 2 px perimeter or underline with a 2 px separation from the control. A focused workspace also says CURRENT. A selected window and current workspace can differ. Confirmation changes the rule to caution and adds “Confirm”; errors say “Error” and explain the cause. Hover never removes keyboard focus. Disabled actions show their reason and never execute.

Graphical vocabulary: slash separates location from action; short horizontal rule locates a workspace; vertical rule locates its selected child. Use exact, filled simple shapes and 1.5–2 px icon strokes on a 16 or 20 px grid. Include a text label for Open, Workspaces, Sound, close, play/pause, mute and routing; recognizable icons are supplementary. AppGlyph may use actual application icons, with letters as a fallback. Empty = word “Empty”; unknown = N/A, hollow frame or --:--; zero = a real 0. No decorative hatching resembling measured data, fake waveforms or infinite progress sweep.

## Component rules

**Folio strip.** Preserve Theme.stripHeight, exclusiveZone, screen binding, configured top/bottom edge and visibility. Open, Workspaces and Sound are named entry points. Current workspace and active title are a single context line. Right end carries minute clock and actual sound state; preserve settings for date/12-hour time/seconds, telemetry, battery, DND, configuration errors and multiple-display caution in phase 5. Show only real values. Recording/sharing remains visible above every Deck state, with owner as plain text. Prototypes simplify these secondary settings; they are not a replacement strip implementation.

**Navigation margin.** Existing Ctrl+1..6 order: Open/command, Workspaces/navigator, System/systems, Sound/signal, Routines/routines, AI/ai; F1 Help. Hide the AI destination when unavailable in production, while preserving its slot/key identity. Prototypes show its explicit unavailable state. Click and keyboard have equal access. No hover-only launcher or obscure gesture.

**Search passage.** Input takes focus on first frame. Results align with query; selected row has the rule, title, subtitle and kind. Respect aliases, argument validation, unavailable reasons, sensitive confirmation, Shift+Enter stay-open and recent history. Keep all four prefixes `> @ ! ?` synchronized with registry. Empty index says “Start typing” or “No match” as appropriate; a bare prefix may have no featured results under today's registry. No fake suggested apps.

**Workspace passage.** Ascending numeric workspaces. Height equals header plus actual window lines; empty slots compact. Up/down select workspace, left/right are the existing adjacent-workspace aliases with columns=1, Tab/Shift+Tab select child, Enter focuses, M then number moves, X X/Delete confirms close, slash filters, Escape clears filter before closing. This retains production handler semantics. Selection follows live state without replacing confirmation behavior. Optional preview can appear beside the selected passage, single-capture and explicitly enabled; never an idle capture loop.

**Sound passage.** Outputs first, then input, then application streams; media in its own region. Default device says so; preferred-but-not-default must stay distinguishable in production. Volume is a linear track and number; clamp to audio.maxVolume, expose a 100% safety threshold if max exceeds 100, and keep muted distinct from unknown. Only bound node volumes are readable/writable. Media chooses the player before sending a command, advertises only supported actions and shows live/unknown length honestly. Only this bay owns Audio.detailed. No extra telemetry sampling.

**Annotations.** Width about 380, short wrapped title/body, explicit severity word and close action. Timers honor creation time; new notices must not restart existing ones. Limit visible stack and provide history through existing commands. The demo command produces a notice and its ordinary success report; the retained screenshot exposes that current behavior rather than concealing it. Stable identity and deduplication need Claude. No action button until the notification action actually invokes its service.

**System/routine/AI/help.** Carry the same number/rule/passage hierarchy into the existing components during phases 5–6. Metrics keep their units, N/A and demand ownership; do not restyle a graph into arbitrary artwork. Routine steps retain preview, confirmation, execution, failure and undo. AI review keeps its explicit approve/dismiss behavior and separate-package component API. Help must describe the actual keys. These bays deliberately use original presentation in the prototypes; the shared services and safety flows have not been rewritten.

**Lock/session.** A secure lock can use the same dark margin, large clock and a single opaque authentication passage with explicit password/error state. No live workspace title or thumbnail on the lock screen. No fake QML lock overlay is offered here. Until Claude supplies a real session lock, keep the external locker path.

## Motion language

Use existing Theme duration tokens, not literals in components.

| Mode | fast / normal / slow | Geometry and compositing |
|---|---|---|
| full | 90 / 160 / 260 ms | Bounded, event-triggered; travel at most 12–18 px for shell surfaces. |
| reduced | 0 / 80 / 120 ms | No travel, scale, width sweep or parallax; optional 80 ms emphasis crossfade. |
| off | 0 / 0 / 0 ms | All transitions and kinetic feedback disabled. |
| lowEffects, any motion setting | 0 effective | Opaque surfaces; no seams/shadows/effects or animation. |

Primary easing: OutCubic for arrival/selection; InCubic for departure; InOutCubic only for a continuous bounded change. No bounce, overshoot or free-running springs. Input and command dispatch are immediate; visual completion is never awaited.

**Signature: unfold the line.** A workspace selection receives a short red rule, which extends to its 100 px index gutter over normal/160 ms while the child title remains readable in place. On Deck entry, the same rule may extend into the passage as the text appears at its final coordinates. On selection change, old rule retracts and new rule extends; the selected child gets a vertical rule. Reduced replaces it with an emphasis crossfade; off/lowEffects draws final state. The prototype demonstrates selection-rule changes; coordinated Deck entry/exit and cross-bay continuity await S02. No text stretch, desktop rotation or app displacement.

| Event | Target behavior |
|---|---|
| Window open/close/focus | No shell-drawn window transformation. Update title and focus indication from compositor events. Compositor owns application animation; use a static, sharp border as the baseline. |
| Workspace switch | Current index changes immediately; selected rule uses fast feedback. Background number changes once; no sliding desktop panorama. |
| Launcher open | Final-coordinate input accepts keys immediately; rule/opacity completes within normal. |
| Launcher close / bay change | At most normal; cancel old demand immediately, then release retained visuals. Never stack multiple active bays. |
| Notice arrival/departure | Short 12 px entry only in full, opacity only reduced; close immediate to interaction. Keyed lifecycle needed first. |
| System control | Track follows actual acknowledged state; fast rule emphasis. No continuous pulse. |
| Loading/progress | Literal state and actual determinate progress. Unknown operation says “Working…” with static ellipsis; no perpetual spinner. |
| Success/error | One bounded semantic ink change with word and cause; no shake. |
| Background/session | Static while idle. Any allowed session crossfade runs once and ends; privacy/lock state never waits. |

Every Behavior/Transition must be gated by `Theme.animate && !Theme.lowEffects`; geometrical motion must additionally require `theme.motion === "full"`. Preserve list keyboard scrolling but make it immediate when motion is off. No new timers except existing data lifecycles and bounded notice expiry. Canvas repaints only for explicit size/state changes. No ambient animation, pointer sampling or periodic wallpaper work.

## Existing settings map

| Setting | Mapping / compatibility |
|---|---|
| theme.palette | All ten existing names stay valid, as in the colour table. Never silently rename a role. Legacy alpha values require composited contrast checks and opaque lowEffects fallback. |
| theme.density | Existing tokens retained; additional content-role tokens use the density table. No API break for AI or existing components. |
| theme.motion | full/reduced/off exactly as above; Help flick must also obey off before production acceptance. |
| theme.uiScale | Round token sizes with Theme.px(); breakpoints use available logical width/height. No second scaling multiplier on text. Scroll rather than crop essential controls. |
| theme.fontSans / fontMono | User preference wins; system fallback if absent. No hard-coded display family bypass. |
| theme.lowEffects | All surfaces opaque, no shadows/seams or transitions, regardless of full motion. Selection and semantic meaning unchanged. |
| strip.* / navigator.* / audio.* | Preserve edge, height, clock/telemetry visibility, workspace count/empty slots, optional thumbnails, stream visibility and max volume. Prototype simplifications are not new defaults for these keys. |

## Systems requests

These are requests to Claude, with acceptance criteria. **Essential** means required for the named final surface or behavior; it does not prevent the core visual implementation from proceeding on supported surfaces. **Optional** means the design remains complete without it. No systems code is changed in this run.

| ID / priority | Exactly what, and why | Surface | Done when |
|---|---|---|---|
| S01 Essential | Production background-layer host on Ui.screen, no focus, no exclusive area, static event-driven content, safe output disappearance. Enables the idle index behind actual windows. Keep existing three namespaces. | Idle desktop | Ground stays behind normal/maximized windows, does not intercept application input, hides on no screen, and remains near-zero idle CPU. Prototype ground is demonstration only. |
| S02 Essential for full motion | Separate requested bay from retained visual lifetime; provide bounded enter/exit completion and cancellation. Release telemetry/audio demand on deactivation immediately, independently of retaining pixels up to 160 ms. Release keyboard focus appropriately; tolerate rapid close/reopen/switch. | Deck and bays | Exit can be captured before unmap; closed telemetry returns to 5000 ms immediately, Audio.detailed releases; repeated switching has no double ownership/leak, stale callback or lost first key; off/lowEffects unmaps instantly. |
| S03 Essential | Stable keyed notice/popup records, expiry based on arrival time, and deterministic ordering above Deck. Guarantee privacy annunciator visibility when Deck is opaque. Avoid duplicate success notices for shell.notify if its purpose is already fulfilled. | Notices / Deck / strip | Add/expire one notice without recreating others or extending their lifetime; notices are visible above every bay; sharing indicator stays visible before/during/after open and close; no duplicate “Notice shown” annotation for one requested notice. |
| S04 Essential | Installer-managed Hyprland rules to disable compositor animations for shell namespaces so they do not stack with shell motion or ignore off. No compositor blur is requested. Support the detected config dialect without overwriting unrelated user rules. | All shell layers | Real Hyprland: motion off/lowEffects produces instant shell transitions, full produces exactly one bounded transition; current namespaces and exclusive-zone behavior preserved. |
| S05 Essential for complete system controls | Backlight brightness and network services with explicit availability, actual state and acknowledged actions. Supply permission/failure/unsupported reasons; no polling owned by visuals. Add volume/brightness OSD host that never takes focus. | System / Sound / OSD | On real hardware, read and adjust brightness, observe connectivity changes, handle absent hardware and denied operations as unavailable rather than 0/off; keyboard volume/brightness emits actual-value OSD without opening Deck. |
| S06 Essential for designed lock surface | WlSessionLock + PAM lifecycle, authenticated unlock, failure/retry and sleep/resume transitions, cancellation/output safety. Keep external locker until ready; never use a decorative overlay as security. | Lock / session | In a real session, no application input or desktop disclosure while locked; wrong password stays locked with readable error; successful authentication unlocks; suspend/resume and output changes remain secure. |
| S07 Optional | Bluetooth device/pair/connect service and display configuration provider, both capability-aware and demand-driven. | System controls | Real device connect/disconnect/configuration succeeds or gives an actionable error; unavailable hardware is labeled; no background scan while closed. Core visual release can omit these controls until then. |
| S08 Optional, prerequisite to any second consumer | Reference-count Audio.detailed, retaining cheap default-device tracking. Needed only if future OSD/another surface shows non-default stream/device volume. Current design avoids that. | Audio consumers | Closing one of two consumers leaves nodes bound for the other; final close releases them; default-only OSD needs no detailed demand. |
| S09 Optional | Implement notification action invocation and capability reporting before exposing action buttons. | Notices/history | Invoking an advertised action reaches the correct notification id/action; expired or unsupported action is disabled with reason; no focus theft. |
| S10 Optional | Installer-supported compositor focus-border mapping using the supplied signal/grid tokens, with user override preservation. No app animation change is required. | Application focus | Real Hyprland distinguishes focused/unfocused/maximized windows with sharp static borders; no QML overlay border or tracking loop; the sway screenshot's preview styling is not mistaken for proof. |

No palette role rename, config schema migration, bundled font, shader, blur rule, live-thumbnail service, task classifier or new telemetry feed is requested. If Claude's implementation needs a new public setting, agree the exact name/default/migration before phase 5; retain every current user key.

## Scope and remaining review

Phases 1–4 only. `shell/`, `ai-bridge/`, `installer/`, `tests/` and `tools/` are untouched. The prototypes reuse their services through symlinks and copy only visual-bay behavior into experimental components. They are not installable replacement shells. After Claude's systems response, implement the direction in production and perform phase 6 against real windows, maximized/tiled arrangements, long/untrusted titles, fractional scale and motion modes. The once-only handoff review is recorded in RECON.md; one revision is available when Claude supplies changes.
