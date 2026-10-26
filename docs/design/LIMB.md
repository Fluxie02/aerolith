# Limb · UI-003

Limb is now the production visual language. Start with [Command Core](limb/02-command.png),
[Navigator](limb/03-navigator.png), then [idle ground](limb/01-idle.png).
The exposed collimator, its workspace marker and the straight chord remain the
round 2 design. No round 1 or alternate-concept material was introduced.

## Final tokens

Existing palette role names and all user settings remain compatible.

| Role | Value | Use |
|---|---|---|
| obsidian / Theme.bg | `#0d1215` | Ground, input, inset instruments |
| surface | `#1b282b` | Chord and notice planes |
| surface2 | `#25373a` | Selected rows, recessed controls |
| grid | `#3b5253` | Rules, map outlines, graduations |
| text | `#edf3f5` | Primary inscriptions |
| textDim | `#abc0bd` | Secondary inscriptions |
| signal | `#ceebac` | Selection, workspace marker, interaction |
| caution | `#ffd071` | Confirmation and warning |
| critical | `#ff9591` | Fault and sharing indicator |
| nominal | `#b3e6bd` | Success |
| Chord opacity | 0.86; lowEffects 1 | No blur or shadow |
| Type | Inter Display identification and titles; configured sans copy; JetBrains Mono commands and measurements | User font overrides retained; Noto fallback judged |
| Density | compact 0.92 / standard 1 / comfortable 1.08 for new spatial metrics | Existing density metrics retained |
| UI scale | Existing 0.75–2 setting | New metrics resolve through Theme |
| Frame | 20 px upper-right chamfer; 1 px rules; 2 px opposite registrations | No rounding |
| Header / inset | 56 / 28 logical px | Theme.headerHeight / contentInset |
| Input / result | 76 / 68 logical px | 28 px command input, 16 px result title |

## Component and layout rules

- One chord frame per bay. Bezel keeps its existing content, header and status API.
  Fine top-edge graduations and opposite phosphor registrations identify the plane.
- At 1920×1080, Command Core begins at 37% of the width and 22% of the height;
  wide bays begin at 12%. The field remains exposed. Below the available spatial
  budget the chord expands to 91% width, preserving font size and usable controls.
- Navigator workspaces sit on a shallow arc. Geometry stays in the small map;
  app ids and sans titles stay horizontal. Left/right selects workspaces;
  up/down and Tab select windows. Narrow layouts scroll horizontally and reveal
  keyboard selection; each window list can scroll independently.
- Systems uses four equal value/history instruments, followed by factual detail,
  cores, storage and processes. Small layouts scroll the instruments with a fixed
  status line; Page Up/Down and wheel scrolling reach the rest.
- Signal, Routine and Help use the same ruled mineral planes, restrained selection
  and monospaced controls. Notices are opaque, keyed and service-expired.
- Untrusted titles, media/device names, notices and status text are plain text.
  Only escaped Fuzzy.highlightMarkup uses styled text. Unknown readings remain N/A;
  swap total zero remains NONE; default volume uses Audio.volumeKnown.
- No polling, timer or ambient animation was added. CircularField repaints on
  workspace, theme and layout events, plus the Deck's bounded opening motion.
  Retained slots use the hosts' current state; demand and focus remain host-owned.
- Theme and shared component APIs used by AI remain intact. AI inherits Limb here;
  its dedicated console layout is deliberately left for the requested follow-up.

## Motion

Full motion expands each chord from its left origin, scale 0.94→1 and 12→0 px
vertical registration, with OutCubic easing over Theme.normal (160 ms). Opacity
settles during that interval. The radial workspace marker registers during opening.
Leaving slots reverse within the host's exit lifetime; incoming and outgoing bays
can coexist without waiting for input. The rail's selection rule uses Theme.fast
(90 ms). Reduced motion uses an 80 ms fade with no travel. Off and lowEffects use
zero durations and immediate layout, including gauge feedback. No idle loops.

[Six actual opening frames](limb/07-opening-01.png) through
[frame six](limb/07-opening-06.png) retain their [capture timing](limb/opening-timing.json).
Software frames may repeat; this is not evidence of GPU frame pacing.

## Critical review and verification

The review retained the circular/straight intersection and removed no defining
Limb element. It caught and fixed the Deck covering the privacy strip, Navigator
title truncation on the small layout, and telemetry overflowing its frame. The
small layout now preserves titles and scrolls detail instead of shrinking text.
No shader, blur, shadow, decorative timer, fabricated reading or schema change.

Node and Qt V4 each passed 103/103; Python passed 68 with one skip. All six
required headless scenarios passed. [Exact commands, logs and limits](limb/verification/RESULTS.md)
include real mock window open/move/focus/close and the plain-text title check.
Idle measured 0.06% of one core (original 0.12%); idle after use 0.07% (0.10%).
Initial RSS rose from 82.2 to 119.8 MiB; peak from 116.9 to 180.4 MiB.
Raw [original](limb/perf-original.json) and [final](limb/perf-final.json) results are retained. The [screenshot index](limb/README.md) contains unmodified captures judged
from the production shell, including all bays, notices over Deck, sharing,
1280×720 at uiScale 1.25 with Noto fonts, motion off and lowEffects, and reduced motion.

One read-only review of Claude's merged host/service handoff found no actionable
systems defect in retained-slot focus/demand release, GroundSurface, notice ordering
and expiry, or reference-counted audio detail. No host, service, schema or AI bridge
file was changed. Claude's single systems/performance review remains the handoff step.
