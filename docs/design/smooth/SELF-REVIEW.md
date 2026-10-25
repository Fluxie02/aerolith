# UI-016 self-review

The single biggest weakness was the first use of a retained Deck slot. The
initial Animator conversion passed unit, smoke and lifecycle checks, but actual
pixel probes rejected it: cold scene-graph nodes started near x0 instead of
the intended entry pose around x744. Later reuse could look correct. QML
property reads and settled screenshots would have missed the wrong-way entry.
The rejected source hashes, raw timings and frames are preserved under
`attempts/first-sync/`.

The correction commits the entry pose before starting its Animators. A
one-shot Window `afterAnimating` handler arms the sync opportunity;
`frameSwapped` queues docking after that render. The handlers disconnect when
docking starts. A presentation generation invalidates callbacks after release
or slot reuse, and a queued flag prevents duplicate starts. There is no guessed
Timer delay, ongoing frame observer, animated layout or per-frame Canvas paint.
The first entry pose is already visible and keyboard input is already active
while it waits for rendering. Corrected pixel checks, rather than the earlier
smoke result, establish whether the entry path is acceptable.

Ordinary interruption uses current-value transform/opacity Behaviors without
an explicit `from`. It avoids the old Deck's displacement-sign and opacity
formula change at retirement. A live close retargets the rendered pose rather
than resetting an opening scalar. Disabling motion makes an outgoing plane
transparent immediately; the protected host's old retained deadline remains
an integration finding.

For an ambient round trip, both endpoints and duration are captured once at
its start. A second cadence event cannot restart a running group. Workspace
changes affect the next stroke. Reduced/off/lowEffects and suspension cancel
the previous stroke. Focus response starts from the current rendered value,
with a short attack instead of assigning a new impulse of one.

Source review also caught the need to complete running animations when a
motion gate closes: disabling a Behavior alone is insufficient. Named guards
cover the edited paths, including OSD exit detection, colour feedback, and
Help's authored keyboard flick.

Diagnostic marker/capture builds are separate from production CPU and timing
runs. Screenshot capture can delay the first software-rendered frame; saved
capture bounds and event timestamps make that limitation explicit. No claim
of 144 fps follows from the monitor's advertised refresh metadata.
