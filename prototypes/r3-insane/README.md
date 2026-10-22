# Limb Insane / UI-004

Complete production-shell snapshot plus visual-only prototype changes.
Run from the repository root with `SHELL_PATH=prototypes/r3-insane`
`AUDIO=1 MEDIA=1 MPV_AO=pipewire CONFIG=prototypes/r3-tools/config.json`
`tools/headless/run.sh prototypes/r3-tools/capture.sh build/r3/insane-capture`.

No idle animation loop. Existing strip telemetry drives readouts; no added demand.
First-start reveal is latched in Theme for the life of the process; reduced/off/lowEffects skip it.
Canvas and QML regenerate from CPU-side properties after unmapping.
Fullscreen unmapping remains the systems host's responsibility.
See `docs/design/round3/VARIANTS.md` and `VALIDATION.md`.
