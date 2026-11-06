# P3-ASTRA-1 — Personalize in Settings

Astra · 5 November 2026. Worktree implementation; no commit made.

## Design and scope

Settings has **Personalize / All settings** modes. The existing immediate-save
register and config diagnostics are retained in `AllSettings.qml`; the new
mode stages appearance through the Phase 2 Config transaction. Presentation
labels/grouping live in `personalize.mjs`, with schema-derived types, limits
and defaults. Structured output paths are copied out of Qt model sequences
without flattening connector names. No config library, core, host, installer or service is edited.

The housing caps at 1120 logical units before Theme scaling. On a sufficiently
wide/tall surface it has a 176-unit section rail, flexible control register
and 300-unit specimen for the selected output. Short or narrow surfaces use
section buttons above one scrolling column, with an expandable specimen.
The footer remains anchored outside that scroll, including at enlarged scale.
The spectrum register grows with available height (capped at 650 units),
showing all twelve choices at 4K while retaining the same type sizes. Profile colours, existing type sizes,
spacing and motion gates preserve the shell's mineral instrument identity.
Presets is visible, disabled, and labelled “Coming in the next update”.

Scheme, density, overall scale, font families, motion, decoration level,
low effects and allowlisted strip/Ground settings preview across the shell.
Font editing offers installed-family matches and a fallback sample. The motion
sample plays once on request. There is no looping animation or closed-editor
polling. Scale/global visibility changes arm a single 20-second timer; expiry
restores only those changes, retaining the other draft edits. Apply waits for
Keep preview or rollback. Cancel restores current saved values.

Advanced palette editing supplies raw-role swatches, hex input, individual
reset and explicit reset-all. It accepts opaque `#RRGGBB`, validates role names,
and reuses `Tokens.contrast`, `MIN_TEXT_CONTRAST` and profile resolution. It
checks normal/background/selected fills, 15% signal over both housing and
navigator background, 12% caution over housing, and the 18% urgent strip tint
over the actual strip background,
under standard, black-background and OLED resolution. Text-bearing roles
include text, secondary text, interaction, status and derived app link.
PIYTI checks the scheme link; THEARS derives that link from the already checked
signal role, rather than reporting a failure for a colour it does not use. A
failure names the profile, role, fill, ratio and required 4.5:1; the previous
safe draft remains unchanged. No automatic repair writes another colour.

Escape first cancels a field, then offers Apply / Discard / Keep editing.
Settings mode changes and keyboard bay changes use the same dialog, whose
Tab/Shift+Tab order stays within its actions. Focused scroll controls are
brought into view, and the spectrum register participates in Tab navigation. Keep editing restores caller
focus. Arrows change focused fields; Enter edits strings/chooses schemes;
Space toggles. View desktop temporarily suppresses Deck pixels and creates
one on-demand layer-shell inspection surface with a fixed bar: Return / Apply / Cancel (and Keep preview
when needed). Its transparent input catcher prevents backdrop clicks from
dismissing the draft; restore/destruction restores the previous visual opacity.

## Integration limits and peer review (one pass)

The Phase 2 Config/Theme/DisplayProfile consumers were reviewed. The parallel
P3-SOL-1 implementation is not present in this checkout. Two actionable
integration findings were published in agent-sync; no peer-owned file was
changed:

- **High — universal leave confirmation requires a host hook.**
  `shell/modules/deck/Deck.qml`, `syncSlots()`/`BaySlot.retire()`, retire the
  editor immediately on rail, backdrop or IPC navigation. Settings guards its
  own keyboard and mode changes, and discards on forced retirement/destruction
  to avoid orphan drafts. A pointer/IPC leave therefore discards without the
  three-choice dialog. Minimal correction for Sol/Opus: a host-owned
  `beforeLeave(destination)` contract, resolved before bay retirement, covering
  rail/backdrop/IPC/Welcome/Tour. Do not intercept lifecycle by reopening bays
  recursively. One peer revision remains available.
- **Medium — output visibility exists in the schema but not the preview
  allowlist.** `shell/lib/config.mjs`, `PREVIEW_PATHS`, allows
  `display.outputs.*.profile` but excludes `.strip` and `.ground`. The named
  output picker previews its profile; the two existing visibility settings
  show their stored permissions read-only with preview-support guidance. Minimal
  correction for Sol: allowlist both leaves and extend transaction tests,
  then these controls become writable without new presentation metadata.
  Extend `Personalize.safetyPath` to those two visibility leaves in the same
  integration before enabling them.
  The global controls govern effective visibility; the disabled rows explain
  that their global master must also be on. The old schema register skips
  maps, so it cannot edit those per-output leaves either.

- **Medium — intermittent startup assignments need systems review.**
  One original startup emitted ten `Unable to assign [undefined]` warnings at
  `Theme.qml:141,197,198`, `Idle.qml:14`, `Telemetry.qml:28`, `Ui.qml:24`,
  `Tour.qml:33,34`, `Notifications.qml:70` and `Compositor.qml:62`.
  Evidence: [startup-warning-qs.log](startup-warning-qs.log). No warning names a
  new Settings file. Root cause and whether the change affects initialization
  order are **unverified**; this is not claimed to be pre-existing. Minimal
  owner follow-up: reproduce the cold singleton initialization and ensure its
  typed consumers receive schema defaults/valid values before first evaluation.
  The final strict scenario now audits both original-startup and instrumented
  runtime logs, and its clean rerun exited 0. A clean retry does not establish
  a fix. Core/service files remain untouched.

The desktop bar uses namespace `aerolith-personalize-preview`; real Hyprland
animation rules, fullscreen release and keyboard handoff need the systems
owner's review. Its visual suppression uses the current window content item's
opacity and restores it; a host-owned presentation property would be a cleaner
integration seam. The inspection surface retains input while viewing the desktop: this
mode is for judging the draft, not interacting with underlying applications.

These proposed controls **need a schema key** for Sol and are omitted:
independent text-size steps; black background per output; additional strip item
visibility/order; Ground widget visibility; workspace names; per-output text
and density overrides. Existing strip telemetry/workspace count, display
placement and OLED idle policy are available in All settings but are outside
the preview allowlist. Preset/import/export UI waits for P3-SOL-2.

## Checks and evidence

The final requested checks ran one at a time in the order below; all exited
**0**. The final guard refinement additionally has the targeted checks
recorded below. Node reported **275 passed, 0 failed**. All instrumented UI
runs and the final strict cold rerun have **zero**
parse, type, reference, assignment or binding-loop errors. One earlier original
startup had ten typed-assignment warnings; that exception is preserved and
reported above rather than hidden by the clean retry. Headless tests use
sway/pixman and a Hyprland IPC mock; they do not establish physical OLED/GPU,
real Hyprland, output-removal focus or external app-theme behavior. Lock
coverage uses the shell-observed `Ui.locked` event in the disposable copy, not
PAM authentication or a real external session locker.

Coordination uses the shared main-checkout hub. The user explicitly delegated
Opus's Claude-held P3-ASTRA-1 reservation to Astra. A direct Astra lock request
was refused by that existing reservation; the start and integration findings
were published as Astra. The hub's top-level UI-016/Claude audit owner was
stale relative to the explicit Phase 3 assignment. After the delegated
reservation expired, Astra acquired its own reservation at 20:15 UTC; only
that reservation is released on completion.


| Exact command | Result |
|---|---|
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/personalize.sh build/ci/p3-astra/personalize` | personalize: ok; exit 0 |
| `OUTPUTS=2 tools/headless/run.sh tests/scenarios/config.sh build/ci/p3-astra/config` | config: ok; exit 0 |
| `AUDIO=1 tools/headless/run.sh tests/scenarios/deck.sh build/ci/p3-astra/deck` | deck: ok; exit 0 |
| `tools/headless/run.sh tests/scenarios/smoke.sh build/ci/p3-astra/smoke` | smoke: ok; exit 0 |
| `AI=1 OUTPUTS=2 CONFIG=tests/fixtures/oled-config.json tools/headless/run.sh tests/scenarios/oled.sh build/ci/p3-astra/oled` | oled: ok; exit 0 |
| `node tests/js/run-node.mjs` | 275 passed, 0 failed; exit 0 |

The Personalize scenario uses real pointer/key/text input and probes only in a
throwaway shell copy. It verifies mode entry; previewed scheme/density and
matching strip geometry on both outputs; no writes before Apply; Cancel;
exactly one write per Apply (one footer Apply, one later Apply-on-leave); a
named-output profile preview and rollback; typed font-field Escape; the
20-second scale rollback; visible pair/ratio contrast refusal; dirty-leave
Apply/Discard/Keep editing; modal Tab focus; automatic reveal of a focused
scroll action; View desktop's return and pointer catcher; and lock discard.
The config scenario separately exercises conflicts, watcher reload, failed
Apply, output loss and process-death rollback. Its `Killed` line is deliberate.

Additional capture runs also exited 0, with no QML errors:

- `RES=3840x2160 SCALE=1.5 HYPR_MOCK_ARGS='--mode 3840x2160 --scale 1.5' tools/headless/run.sh tests/scenarios/personalize.sh build/ci/p3-astra/personalize-4k`
- `RES=1280x720 HYPR_MOCK_ARGS='--mode 1280x720' tools/headless/run.sh tests/scenarios/personalize.sh build/ci/p3-astra/personalize-compact`
- `CONFIG=docs/design/phase3/oled-personalize-config.json tools/headless/run.sh tests/scenarios/personalize.sh build/ci/p3-astra/personalize-oled`

The targeted `node docs/design/phase3/contrast-audit.mjs` also exited 0. It
checks all twelve default schemes, rejection of an actual navigator tint that
would otherwise reach only 4.16:1, both app-link derivations, invalid role/alpha
rejection, input
immutability and a literal-dot connector path.

Static checks: `git diff --check`, `bash -n tests/scenarios/personalize.sh` and
`node --check shell/modules/settings/personalize.mjs` all exited 0. New-file
trailing whitespace was checked separately. Docker preflight
`docker info --format '{{.ServerVersion}}'` returned `29.9.1`; the daemon was
not started, stopped or cleaned. No global packages were installed.

Resolved development failures included a height binding loop, missing enum
metadata defaults, Qt sequence conversion, text-field activation loss, and
virtual-keyboard delivery timing. One overlapping development retry was
discarded; the final six checks above ran sequentially. Input retries inspect
actual UI state and never call production mutation methods through a probe.

| Runtime capture (JPEG) | Physical pixels | Bytes |
|---|---:|---:|
| [Personalize / 1080p](personalize-1080.jpg) | 1920 × 1080 | 255397 |
| [Personalize / compositor scale 1.5](personalize-4k-1.5.jpg) | 3840 × 2160 | 586040 |
| [Compact / single column](personalize-compact.jpg) | 1280 × 720 | 149822 |
| [Contrast refusal](personalize-contrast-refused.jpg) | 1920 × 1080 | 207054 |
| [View desktop](personalize-desktop.jpg) | 1920 × 1080 | 250350 |
| [Dirty leave](personalize-dirty-leave.jpg) | 1920 × 1080 | 140697 |
| [OLED / black planes](personalize-oled.jpg) | 1920 × 1080 | 223947 |

All captures were inspected and are below 4 MiB each. JPEGs preserve the
original capture dimensions; no generated mockups are used. Machine-readable
commands, results, log audits, screenshot sizes/hashes and final source hashes
are in [verification.json](verification.json). Raw run artifacts remain in
`build/ci/p3-astra/` (ignored build output).

## Files changed

- `shell/modules/settings/SettingsBay.qml`: mode shell, entry and keyboard-leave routing.
- `shell/modules/settings/AllSettings.qml`: byte-for-byte extraction of the previous Settings bay.
- `shell/modules/settings/PersonalizePane.qml`: staged controls, inspector, safety, dialog and desktop inspection.
- `shell/modules/settings/PersonalizeField.qml`: schema-driven fields and installed-family picker.
- `shell/modules/settings/PersonalizeAction.qml`: shared keyboard/pointer action target and focus routing.
- `shell/modules/settings/personalize.mjs`: labels, grouping, path normalization and contrast guard.
- `shell/modules/settings/SchemePicker.qml`: embedded columns and stable specimen identities.
- `tests/scenarios/personalize.sh`: disposable instrumentation and real-input acceptance scenario.
- `docs/design/phase3/`: this report, the OLED capture fixture, contrast audit, verification manifest and seven JPEGs.

No commit was made. Integration acceptance still needs the host leave hook,
output-visibility preview support and investigation of the preserved startup
warnings, followed by the systems owner's real Hyprland/fullscreen/keyboard
review. Missing-schema controls and
Presets remain explicitly deferred rather than represented by invented keys.
