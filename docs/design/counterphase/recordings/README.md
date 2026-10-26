# COUNTERPHASE recordings — UI-014

| Recording | Duration | Size |
| --- | ---: | ---: |
| [PIYTI Saturated](piyti-saturated.mp4) | 2:04.906 | 3.70 MB |
| [PIYTI Insane](piyti-insane.mp4) | 2:04.903 | 4.74 MB |
| [THEARS Saturated](thears-saturated.mp4) | 0:51.933 | 2.21 MB |

All three contain real keyboard/IPC interaction, first-boot assembly, idle
motion, workspace changes, all eight Deck bays, Tab, typing, notification
arrival/expiry, control attempts, Deck closure and final idle.

No production shell files are changed. PIYTI uses the existing
`build/counterphase-piyti-motion-shell`, verified against `shell/`: its only
difference is the pre-existing `Theme.applicationDirection = "piyti"`
selection. THEARS uses `shell/` directly. The installation-only selection
is not yet wired in production; this limitation is disclosed, not repaired.

The ordinary headless harness supplies software-rendered sway, Hyprland IPC
fixtures, PipeWire null devices, a real mpv MPRIS player, fixture routines,
and the optional AI module with fixture provider CLIs. Window identities are
protocol fixtures, not real application windows. The notification server is
enabled through an isolated fixture configuration. Full motion is enabled,
lowEffects is false, resolution is 1920×1080, scale is 1.

The recorder starts before a fresh production shell process, so the process's
first-boot assembly is captured. This is shell startup, not a full OS boot.
The initial process that the harness starts is stopped before recording;
its log is saved as `bootstrap-qs.log`. The recorded fresh process has its
own `qs.log` and timestamped companion `qs-timed.jsonl`.

Capture uses the unchanged harness's software Qt Quick backend and sway
pixman renderer, with the output set to native 30 Hz. `wf-recorder 0.6.0`
captures continuously (`-D --no-dmabuf`) to a lossless H.264 VFR Matroska
master. No animation clock or timer is changed. Wayland screencopy `ready`
timestamps share the driver's monotonic clock. The first presentation timestamp
is used to align input/chapter times with frame zero; initialization offsets
were 63.2 ms / 64.6 ms / 67.0 ms respectively.

Offline ffmpeg adds a dark strip, running `mm:ss.ff` timecode and chapter label
at the bottom left, clear of functional shell text. `ff` runs 00–29.
`fps=30` holds or drops captured frames for the required constant frame rate;
there is no interpolation, smoothing, speed change, edit, cut or hidden fault.
Original source PTS, raw masters and every capture warning are retained.
Frame gaps are listed in [FAULTS.md](FAULTS.md). Ambient rests are intentional:
960 ms travel in a 9.28 s Saturated / 5.12 s Insane cadence.

One capture-metadata correction is applied before the overlay: wf-recorder
incorrectly flags its limited-range YUV samples as full-range. The delivery
tags them limited range, checked against an untouched harness screenshot.
There is no color grading or pixel-level transformation. Original masters
remain in the profile directories; first previews with the incorrect flag
remain under `attempts/`.

The MP4s use H.264 High, level 4.0, yuv420p, 1920×1080, 30 fps, no audio and
`+faststart`. Encoding uses CRF 20 with a 2 Mbit/s ceiling and 4 Mbit buffer.
It happens after recording, so it cannot load the renderer during a take.
The target durations are 125 s / 125 s / 52 s; THEARS is a few seconds longer
than the requested approximate 45 s to retain all eight bays, the full
notification expiry and a two-second Tab hold before typing.

The production checkout has no OSD host or brightness service/command.
The attempted controls are included and their absence belongs in FAULTS.md.

[Chapter list](CHAPTERS.md) · [Observed faults](FAULTS.md) ·
[Verification results](verification.json) · [Source provenance](source-hashes.json)

## Verification results

The three `launch.py` commands and three final `render.py` commands exited 0.
`python3 docs/design/counterphase/recordings/verify.py` exited 0. It verifies
every video decodes completely without errors, is H.264 High/level 4.0,
yuv420p/1920×1080/30 fps, below 40 MB, and has the MP4 `moov` atom before
video data for progressive browser playback. Physical phone playback was
not exercised. The running overlay and selected final pixels were inspected.

Final raw effective frame rates were 29.951 / 29.583 / 29.854 fps. Maximum
source intervals were 76 / 46 / 44 ms; the two final source gaps over 50 ms
are retained and listed in FAULTS.md. No retiming was needed: compositor
presentation spans agree with the capture's wall-clock duration.

All three `qs.log` files were read and audited in full: no QML TypeError,
ReferenceError, assignment error or binding loop, and no fatal/process error.
There are 63 / 63 / 57 warnings, including repeated Wayland focus warnings;
the exact timestamped messages are in each profile's `log-warnings.json`.
The intentional invalid routine and missing system-bus services are disclosed
in FAULTS.md. Notification status changes from one popup to zero, Deck is
closed at the end, volume is confirmed by `wpctl`, and optional AI is loaded.

Full visual review covered all-second sweeps, boot, workspace switches and
every bay transition, with denser transition samples. It found notices covering
Help/Settings; no additional clear clipped/blank/stale bay fault was observed.
The final THEARS Tab hold and notification were rechecked after its longer
take. Corrected-color final pixels in all profiles match the untouched harness
screenshot's sampled RGB values within two levels; details are in
[color-range-evidence.json](color-range-evidence.json).

All captured production, PIYTI snapshot and harness hashes still match.
No shell code, host, service, config library or schema was changed, and git
was not written. Independent systems review was completed once; its missing
OSD/brightness finding remains open because UI-014 prohibits shell fixes.

## Exact commands

Run from the repository root. The read-only `wf-recorder` binary is supplied
at `/tmp/ui014-recorder/wf-recorder` (SHA-256 in `source-hashes.json`); it was
extracted from Arch's `wf-recorder 0.6.0-2` package. No image was changed.
The existing `aerolith-dev` image provides all its shared libraries.
`launch.py` invokes the unchanged `tools/headless/session.sh` in that image,
using the same `SYS_NICE` capability as `tools/headless/run.sh`.

```sh
python3 docs/design/counterphase/recordings/launch.py piyti-insane
python3 docs/design/counterphase/recordings/launch.py piyti-saturated
python3 docs/design/counterphase/recordings/launch.py thears-saturated
python3 docs/design/counterphase/recordings/render.py piyti-saturated
python3 docs/design/counterphase/recordings/render.py piyti-insane
python3 docs/design/counterphase/recordings/render.py thears-saturated
python3 docs/design/counterphase/recordings/verify.py
```

Each profile retains the exact Docker and ffmpeg argument arrays, input
events with command results, fixture config, output geometry, log warnings,
source hashes and chapter metadata. `launch.py` refuses to overwrite a raw
master. Keep or move an earlier run before rerunning a profile.
