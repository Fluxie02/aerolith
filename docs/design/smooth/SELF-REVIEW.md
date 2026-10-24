# UI-016 self-review

The single biggest weakness was discontinuity on interruption. The old Deck
changed the sign of its displacement while retaining an intermediate progress
value, and changed incoming opacity from `.84 + .16 * progress` to `progress`
at retirement. A close halfway through opening could jump in position and
brightness before the exit even started. The old ambient cadence could also
restart on a workspace change, resetting a moving carrier to its origin.

The fix uses independent current-value Behaviors with transform/opacity
Animators for the Deck. There is no explicit `from` and no progress reset for
a live incarnation. Entry initialization happens only after a host slot gets a
new bay; the host still owns loading, focus and retirement. When motion is
disabled, an outgoing plane is immediately transparent. The protected host's
old retained deadline remains an integration finding, not a visual animation.

For an ambient round trip, both endpoints and the duration are captured once
at its start. A second cadence event cannot restart a running group. Workspace
changes affect the next stroke. Reduced/off/lowEffects and suspension cancel
the previous stroke as required. Focus response likewise starts from its
current rendered value, with a short attack instead of assigning a fresh
impulse of one.

Source review also caught the need to complete already-running animations
when a motion gate closes: disabling a Behavior alone is insufficient. Named
completion guards now cover the edited paths, including OSD exit detection,
colour feedback, and Help's authored keyboard flick.

Runtime position and fast-close evidence is collected from a diagnostic
marker in a disposable shell copy. Production CPU/timing runs exclude that
marker and exclude screenshot capture. The final measured results and any
limits are in the README and timing evidence; advertised Hz alone is not a
smoothness result.
