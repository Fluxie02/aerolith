# UI-009 · critical review

Saturated remains the default; Insane retains the extreme engraving and extra
instrumentation. Limb's exposed annulus, asymmetric command chord, phosphor
registration and workspace arc remain the identity.

Owner feedback, verbatim:

> I feel like the tabs are too deviant from the limb design and need to be more fluent and intuitive

> Like all of them look really alien and I think all system things like all terminal things like kitty or alcritty, system monitors and settings need to be into the system and be more rounded and stuff now it looks just like a cool background but not really anything else

The harsh findings were practical: small bays wasted space on large padding
and empty status lines; shortcut codes dominated navigation names; background
engraving interfered with the route; the compact workspace identity crowded
its dial; scrolling was signalled by inconsistent, sometimes horizontal marks;
and lock failures could fall below the visible password field.

Changes:

- Shared compact Bezel spacing gives every bay the same header and usable
  viewport at 1280×720/uiScale 1.5. Empty status messages take no space;
  actual feedback wraps to two lines.
- Names lead the rounded arc navigation; shortcuts sit below. An opaque
  navigation bus protects them from engraving. Redundant Deck core bars no
  longer collide with that bus. Scope navigation uses the same component.
- The compact workspace identity fits inside its instrument. Ground exposes
  usable Command, Navigator, Systems and Settings controls in both layouts.
- First boot now assembles datum, annulus, index band and outer architecture
  in distinct phases, using the existing finite, process-latched animation.
  Startup now waits for saved configuration, fixing Insane’s duration latch
  and preventing a brief animation under motion off. Reduced/off/lowEffects
  start complete with zero animation events.
- A shared vertical position marker replaces misleading horizontal marks in
  Signal, Routines and AI and aligns Systems, Help and lock scrolling.
- Lock failure/wait state remains in the header; compact identity and message
  typography leave more room for the password and readable explanation.
  Shared Bezel canvases explicitly repaint after surface remapping.

The UI-008 Settings patch landed externally during reconnaissance (e577eb4).
Its source remained under Claude's lock and was not edited here. Shared
components refine it alongside the other bays. Existing optional application
fragments retain matching opaque mineral colours, phosphor selection and
rounded compositor decoration; installer integration remains Claude's work.

[Before/after captures](review/README.md) and [verification](review/verification/RESULTS.md)
are saved. Node and Qt each pass 104 tests; Python passes 71 with one skip.
All six required scenarios pass in both intensities; every qs.log was read.
Initial idle is 0.24% / 0.26% of one core (Saturated / Insane), versus 0.25%
before; idle after use is 0.23% in both. Git was used read-only. The systems
review records two harness findings for Claude. No production systems code was changed.
