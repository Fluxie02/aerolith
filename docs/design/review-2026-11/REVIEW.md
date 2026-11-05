# AEROLITH design, customization and onboarding review (November 2026)

Opus's synthesis for the owner. Its sources:
- [FACTS.md](FACTS.md): facts verified in code by three read-only audits, a
  design system audit by Opus, and harness runs.
- [ASTRA.md](ASTRA.md): Astra's visual decisions and the Welcome and
  Personalize wireframes.
- [SOL.md](SOL.md): Sol's engineering second opinion, with feasibility,
  costs and corrections.

Everything below describes `main` at 9729b47 unless it is marked
*proposed*. Nothing here is built yet, apart from the quick fixes listed in
§5 Phase 0.

## 1. Assessment

### What is strong, and should be kept

- **A coherent token system.**
  - 12 schemes, density, UI scale, motion, intensity and direction all flow
    from `lib/schemes.mjs` and `lib/tokens.mjs` into `Theme`.
  - There are no hardcoded hex colours in QML.
  - True black and OLED behaviour exist per output through `DisplayProfile`.
- **A schema-first config.**
  - One schema (`lib/config.mjs`) generates the JSON schema, the docs and
    the rows of the Settings bay.
  - Invalid values fall back to their defaults, unknown keys are kept, the
    file reloads live, and the installer never overwrites a user's config.
- **Multi-monitor.**
  - The Ground and Strip are created per output.
  - The overlays are single surfaces placed by `overlayOn` and `noticesOn`.
  - Fullscreen handling and ambient motion are per output.
- **Low idle cost.**
  - 0.17% of one core at idle.
  - The only ambient timer is gated by motion settings, covered or
    fullscreen outputs, and OLED idle.
  - Pickers, the tour and the Deck exist only while open.
- **Identity.**
  - The instrument language, Bezel housings, technical capitals and the
    hatch are intact.
  - Everything the owner brief called useless decoration has been removed:
    the scale numbers, "PIY TI" and the wing.

### What is inconsistent, outdated or unfinished

**High:**
- The lock screen ignores the OLED profile. A lock screen is static and can
  stay up for hours, which is the worst case on OLED. Verified:
  `LockView.qml` uses `Theme` colours 21 times and has no profile.
- The session menu, OSD and notifications mix OLED and Theme colours.

**Medium:**
- Ground geometry is copied in several places, and the tour copies it again,
  so changing one layout misaims the others.
- The compact-layout thresholds disagree (`px` against `du`).
- There are unused tokens and components (`CircularField`, `MetricTape`,
  `Readout`).
- Old rail numbers ("CMD / 01") and "PIYTI / SATURATED" jargon are still
  shown.
- The ring and the strip count workspaces differently.
- Layouts break in portrait (the ring goes off-screen) and on ultrawide
  (nothing has a maximum width).

**Customization gaps:**
- Settings saves on every keypress: there is no preview, undo or reset.
- Palette overrides can only be set in the config file, with no contrast
  check.
- There are no presets and no import/export.
- No strip-item or ground-widget toggles, and no workspace names.
- A change made with the `aerolith scheme` CLI can be lost, because the
  shell's next Settings save may write over it.

**Integration gaps:**
- There is no Welcome, About or system-info screen, and the shell does not
  know its own version.
- The docs are not installed, and the code points to three documents that do
  not exist.
- `--startup systemd` never enables the service it writes.
- The Help bay shows shortcut names, not your actual key combinations.
- Some docs are stale: they say there is no network control and that
  AEROLITH supports one display.

### What would add complexity without enough benefit

- **Blur or translucency.** Astra and Sol both say no. It weakens the opaque
  instrument hierarchy and makes contrast depend on the wallpaper. It costs
  GPU work and power on NVIDIA, it conflicts with OLED, and Hyprland blur
  needs translucent surfaces. Variety comes from schemes, intensity and true
  black instead.
- **Reordering strip items:** high cost, low value. Toggling items on and
  off gives most of the benefit.
- **A separate Welcome application** (a second Quickshell config): it
  duplicates services and config. An in-shell surface is enough.
- **A general shared canvas engine:** a refactor with no user-facing gain.
  Fix the copied geometry instead.

## 2. Prioritized improvements

Complexity: S = small (hours), M = medium (one job), L = large (several
jobs). Owner: who builds it, following the team split. Opus reviews and runs
the harness for all of them.

| # | Improvement | Benefit | Cmplx | Drawbacks and risks | Owner |
|---|---|---|---|---|---|
| 1 | Lock screen, session menu, OSD and notices follow the output's profile (H1/H2) | Correct OLED black; protects static screens | S–M | Lock changes need PAM/lock regression runs | Sol, then Astra checks the captures |
| 2 | Stop CLI edits being lost: re-read before every write, serialise saves | No lost settings | M | A small race window remains without a shared lock | Sol |
| 3 | Tour: manual replay always allowed; `tour.enabled` gates only the auto-start | You can always replay the tour | S | Changes one tested contract (`tour.sh`) | Sol |
| 4 | Tour linked from Help, Settings and (later) Welcome; edge-aware wording; "2 of 5" | People can find it | S | none | Astra (copy), Sol |
| 5 | Old labels and jargon replaced (M4) | Words people understand | S | none | Astra (copy), Sol |
| 6 | Unknown-key warnings shown in Settings | Typos get noticed | S | Can be noisy: use a diagnostics list, not toasts | Sol |
| 7 | Install the user docs; links work offline | Help that works | S–M | Needs packaged paths too | Sol |
| 8 | systemd startup enables the unit when chosen | First boot reliably shows the shell | M | Duplicate launches if not reconciled | Sol |
| 9 | Tour targets report their real positions (anchor registry) | Tour stays right after layout changes | M | Cross-window coordinates need a real Wayland check | Sol |
| 10 | Shared compact classification, plus maximum widths for portrait and ultrawide | Fits every screen | M | Visual regressions; needs captures at 5 sizes | Astra (fit), Sol |
| 11 | Ring and strip use the same workspace set; overflow row | Consistent | M | none | Sol (data), Astra |
| 12 | Version plumbing (manifest → shell), `doctor --json`, offline "different source" check | Welcome and troubleshooting have real data | M | Packaged layout differs | Sol |
| 13 | Config draft and transaction (preview, Apply/Cancel, batch writes) | Foundation for Personalize and presets | M (appearance) / L (everything) | Side effects (app themes, notification server) must wait for Apply | Sol |
| 14 | **Personalize** mode in Settings: live preview, contrast-guarded palette, text size, black background on any output, strip and ground toggles, workspace names | Real customization | L | Depends on 2 and 13 | Astra (design), Sol/Terra (build) |
| 15 | Presets (Default, Readable, user) with import/export | Shareable setups | M | Merge rules for per-output keys | Sol/Terra |
| 16 | **Welcome** surface | One front door | M–L | Depends on 7 and 12 | Astra (design), Sol/Terra (build) |
| 17 | Tour resume and "skipped" separate from "completed" | Continuity | M | Small extra state writes | Terra |
| — | Blur/translucency, strip ordering, a separate Welcome app | — | — | Not recommended (§1) | — |

## 3. Guided tour: verified status

**Is it implemented? Yes.** It merged in #12, and I verified it in the code
and in the headless harness:
- **Code:**
  - state in `shell/services/Tour.qml` and `shell/lib/tour.mjs`;
  - visuals in `shell/modules/tour/TourHost.qml` and `TourCard.qml`;
  - mounted from `shell/shell.qml` while active;
  - completion saved, versioned, in `~/.local/state/aerolith/state.json`.
- **Tests:** `tests/scenarios/tour.sh` runs in CI with `TOUR=1`. It covers
  focus, Enter/Right, Left, Esc, fullscreen hiding and restoring, and that
  keyboard input reaches a window again afterwards.

**When it starts:**
- **Automatically, once:** on the first start of a shell that has no
  completed tour recorded, on the primary output, when `tour.enabled` is on
  (the default). It waits while the screen is locked or the primary output
  is fullscreen.
- **Existing installs that upgrade** also see it once, because they have no
  completion recorded.

**How to start it again:**
- Super + Space (search), type "tour", then choose "Show the tour again"
  (command `tour.start`).
- Developer IPC: `qs -p <shell dir> ipc call tour start`.

**How to control it:** Enter or Right goes on, Left goes back, Esc skips,
and Enter on the last step finishes. Skip and finish both mark it done.

**Turning it off:** `"tour": {"enabled": false}` in `config.json`. The
Settings bay shows this toggle.

**What's missing or wrong (fixes in §2):**
- Not linked from Help, Settings or the README (#4).
- Manual replay is blocked when `tour.enabled` is off (#3).
- Progress isn't saved, so a restart mid-tour starts over; and skip counts
  as completed (#17).
- The highlight positions copy other components' layout maths (#9).
- The wording says "top bar" even when the strip is at the bottom (#4).
- Settings is reached only through the line "open Search and type Settings"
  (#4).
- No contextual hints: they could come later, on keyboard focus or
  deliberate hover only, never on a timer (Astra §4).

## 4. Welcome screen proposal

The full wireframes are in [ASTRA.md §3](ASTRA.md); the integration rules
are in [SOL.md §5](SOL.md). Decisions:

**What it is:**
- An in-shell, layer-shell surface with a Bezel housing, created only while
  open, like the tour and the pickers.
- Not a separate app, and not a new Deck bay.
- Colours come from its output's profile (so OLED is black); sizes, type and
  motion come from Theme.

**Layout:**
- At 1920×1080, a housing of at most 1120×820 in the work area, with two
  columns of 680 and 368.
- At 4K ×1.5, the same logical size.
- Below 1000×800, one column of at most 880, with a scrolling body and fixed
  header and footer.

**Sections:** each section is a registered card, so a later feature adds a
card.
- **Overview:** five plain sentences: Search, Windows, Systems, the hatch,
  the strip.
- **Start here:** Take the tour, or "Resume · step n/5"; Personalize;
  Displays; System settings.
- **Learn and maintain:**
  - **Documentation:** the installed local docs.
  - **Updates:** the installed version and the real update procedure, with
    no network check.
  - **Troubleshooting:** config errors first, then "Run diagnostics" on
    request, and Copy report after a preview.
- **First-run checklist:** only real checks: config valid, primary output
  found, startup actually enabled, tour finished. Personalizing is optional
  and is never a required tick.
- **System info:** AEROLITH, Quickshell and Hyprland versions and dialect,
  GPU, outputs with mode, scale and profile. Anything unknown shows
  "Unavailable", never a false "OK".
- **Two separate toggles:** "Launch AEROLITH on startup" (reconciles the
  real startup method, with confirmation) and "Show Welcome on startup" (a
  new `welcome.showOnStartup` key).

**One first-run flow:**
- Welcome opens on the first eligible start, on the primary output, and
  replaces the tour's automatic start.
- "Take the tour" closes Welcome and starts the tour. Finishing returns to
  the checklist; skipping goes to the desktop.
- "Start using" dismisses onboarding without the tour.
- Upgrades don't restart onboarding.

**How it opens:** a `welcome.open` command ("Welcome" in search),
`aerolith welcome`, an IPC target, links from Help and Settings, and an
entry in the strip brand's menu. An optional shortcut, unbound by default.

**What it never does:**
- network calls when it opens;
- polling, or animation in the background;
- enabling services or editing config just because it opened.

Diagnostics run only on request, through `Exec` (argv, timeout).

**Prerequisites:**
- installed docs (#7);
- version plumbing and `doctor --json` (#12);
- the startup reconciliation (#8);
- a new `aerolith-welcome` layer rule.

## 5. Implementation roadmap

**Phase 0: quick, safe fixes (in progress now)**
- **Opus (done):** the Wi-Fi picker says "enterprise" only for real
  enterprise types, after Astra's review.
- **Sol (QF-1, running):**
  - Hyprland layer rules for the tour, network and Bluetooth surfaces;
  - the outdated "supports one display" doctor warning;
  - the three dead doc references;
  - stale lines in `ALPHA.md` and `CONFIGURATION.md`;
  - hiding the retired keys in Settings;
  - closing the array/map validation hole in `setPath`.

**Phase 1: quick improvements, about a day of agent work.** Items #1, #2,
#3, #4, #5, #6 and #7. Mostly Sol, with copy and captures from Astra, and
one PR. Each has tests:
- a lock-screen OLED capture;
- a CLI-replace-then-Settings-write regression;
- tour replay while disabled;
- doc links.

**Phase 2: foundations.** These are the larger architectural changes, so
they need your approval:
- #13 config transaction (appearance keys first);
- #9 anchor registry;
- #12 version and diagnostics;
- #8 startup reconciliation;
- #10 and #11 layout fit and workspaces.

Sol takes the systems work and Terra a disjoint part in parallel (anchors
and fit). Astra checks captures at 1080p, 4K ×1.5, 1280×720, portrait and
ultrawide.

**Phase 3: features.**
- #16 Welcome first, because it gives the most value for new users and
  depends only on Phase 1 and #12.
- Then #14 Personalize, then #15 presets, then #17 tour resume.
- Astra designs any visuals not already specified; Sol and Terra build;
  Opus reviews.

**Not planned:** blur and translucency, strip reordering, and a separate
Welcome app (see §1).

## 6. Decisions for the owner

1. **Approve Phase 1 as one PR?** It contains only small, safe changes.
2. **Approve the Phase 2 foundations,** above all the config transaction,
   which changes how Settings saves: from saving on every keypress to
   preview, then Apply.
3. **Welcome: auto-open on the first start of a fresh install only**
   (recommended), or also once after you upgrade?
4. **Default shortcut for Welcome:** none (recommended), or for example
   Super + F1?
5. **Agree to leave blur and translucency out?** Astra and Sol both
   recommend it.
