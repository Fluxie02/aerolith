# Actual production-view capture runs

All commands below exited 0. `run.sh` copies production QML into a disposable
headless session; it does not install/change host applications. The standalone
script `collect-evidence.py` copies PNGs byte-for-byte and records SHA-256
hashes. All eight logs have zero QML parse/type/reference/assignment/binding
errors; see `capture-log-audit.json`.

```sh
python3 docs/design/schemes/verification/prepare-captures.py
AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-register.sh build/ui015/register-final
RES=1280x720 CONFIG=build/ui015/compact.json AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-compact.sh build/ui015/compact-final
AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-switch.sh build/ui015/live-switch-final
AUDIO=1 MEDIA=1 MPV_AO=pipewire AI=1 ROUTINES=tests/fixtures/routines.json tools/headless/run.sh docs/design/schemes/verification/capture-bays.sh build/ui015/all-bays
RES=3840x2160 SCALE=2 CONFIG=build/ui015/saturated.json AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-4k.sh build/ui015/4k-piyti-saturated
RES=3840x2160 SCALE=2 CONFIG=build/ui015/insane.json AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-4k.sh build/ui015/4k-piyti-insane
RES=3840x2160 SCALE=1 SHELL_PATH=build/ui015/thears-shell CONFIG=build/ui015/saturated.json AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-4k.sh build/ui015/4k-thears-saturated
RES=3840x2160 SCALE=2 SHELL_PATH=build/ui015/thears-shell CONFIG=build/ui015/insane.json AUDIO=1 tools/headless/run.sh docs/design/schemes/verification/capture-4k.sh build/ui015/4k-thears-insane
python3 docs/design/schemes/verification/collect-evidence.py
ffmpeg -hide_banner -loglevel error -framerate 5 -i docs/design/schemes/live-switch/frames/frame-%02d.png -c:v libx264 -crf 22 -pix_fmt yuv420p -y docs/design/schemes/live-switch/switch.mp4
```

`compact.json` contains theme uiScale 1.25, motion off, lowEffects true, Noto
Sans/Noto Sans Mono, Glacial and Insane. The intensity seed files contain only
`theme.intensity` and `theme.motion: full`. `thears-shell` is an unmodified
production-shell copy except `Theme.applicationDirection: thears`.
The latest two-file count-label maintenance fix changes no displayed pixels;
full source hashes and the later focused Settings scenario record that exact
revision. All other production files match these capture runs.

Outputs: 29 register frames (12 applied pickers, 12 grounds, cursor/register/
trace demonstrations), 5 compact frames, 120 all-scheme bay/notice frames,
96 native 4K frames, and 16 live switch samples. The live switch's raw timing
is retained; the MP4 presents samples at 5 fps without interpolation.
The capture-only initial unset `OUT` environment error was fixed before the
final successful live sequence; no failed sequence is included as evidence.
The initial register cursor filenames predate the keymap timing adjustment;
`picker/review-cursor-limb-active-glacial.png` is the independently reviewed
proof of separate cursor and active states.
