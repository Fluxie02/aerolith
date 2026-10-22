# Limb / round 3 — UI-004

Three runnable, isolated extensions of production Limb. No winner selected.
The exposed circular instrument, straight command chord, shallow workspace arc,
petroleum field and phosphor focus marks remain in all three.

| Variant | What increases | Show the owner first | Idle CPU / RSS |
|---|---|---|---|
| Dense | Five concentric scales, 32-segment index, workspace occupancy arc, active-window hub, three-window register, CPU/memory histories, audio and route bus | [Dense idle](dense/01-idle.png) | Measurement in progress |
| Saturated | Screen-scale second instrument, eight screen datums, 64-segment index, core array, four-window register, RAM capacity and audio route; extra command-bus readouts | [Saturated idle](saturated/01-idle.png) | Measurement in progress |
| Insane | Twelve primary rings plus eighteen outer ribs, twelve secondary rings, fourteen screen datums, 96-segment index, structural combs, split monumental wordmark, actual command taxonomy, capacity/temperature/notice readouts, extra history tapes | [Insane idle](insane/01-idle.png) | Measurement in progress |

## Startup and return

Each starts with a one-time assembly: circular scales register, the workspace hub
and wordmark resolve, the window register appears, then the straight telemetry bus
locks into place. Nominal duration: Dense 1.56 s, Saturated 2.08 s, Insane 2.60 s.
The normal Deck opening remains 160 ms; input does not wait for either sequence.
Reduced motion, motion off and lowEffects skip the startup travel entirely.

The startup latch lives in the Theme singleton, outside the surfaces. Recreating
or remapping a view cannot reset it. Canvas paint reconstructs geometry from QML
properties, theme and compositor state. There are no shaders, blur, GPU snapshots
or live window thumbnails. Claude owns fullscreen surface unmapping; this round
does not implement or claim a measured GPU-memory drop.

## Motion and data

No variant uses a continuous animation loop. Existing telemetry samples, workspace
and window events, audio changes and notifications supply the activity. Ground
adds no timers, polling, processes, telemetry demand or audio-detail demand.
Core displays cap at 32/64 real logical CPUs; their captions state how many are
shown. Unavailable readings stay N/A. Histories show only collected samples.
The denser functional bay planes are 97% opaque (100% under lowEffects).

## Evidence

Every variant directory contains idle, queried Command Core, Navigator, Systems,
Sound, notice, notice over Deck, six actual opening frames and eight actual first-start
frames. Timing JSON records capture invocation times; compositor delivery and PNG
completion can differ. `small-*` images check 1280×720 at uiScale 1.25 with Noto,
opaque effects and motion off. See [validation](VALIDATION.md) for exact commands,
results, measurements and limitations. Production source hashes are retained in
[baseline-sha256.json](baseline-sha256.json).
