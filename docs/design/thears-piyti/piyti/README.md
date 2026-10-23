# PIYTI shell evidence

`saturated/` and `insane/` contain full-resolution production-shell captures at
1920×1080. `00-settled.png` is the direction's resting composition;
`01-firefox-handoff-settled.png` and `02-creative-handoff-settled.png` show app focus;
`03-dock-settled.png`, `04-input.png` and `05-window-bay-settled.png` show functional
bays; `06-release-settled.png` shows restoration; `07-sharing.png` keeps the privacy
annunciator visible.

These are actual QML/software-renderer images. App roster, window titles, focus,
workspace and sharing events come from an explicit Hyprland protocol fixture.
Steam/Discord cells are shell views of fixture metadata, **not real app previews**.
Actual Firefox, Writer and PhotoCraft windows are documented in
[real-apps](../real-apps/README.md).

Each `motion/<gesture>/` keeps six unmodified full-resolution PNG frames
(00, 02, 04, 07, 11, 17), an 18-frame scaled WebP, a contact sheet of every frame,
and raw capture/trigger times plus `timing.json`. Labels on sheets/previews use
actual elapsed time relative to the IPC trigger; capture-start timestamps precede
`grim`, so they are not compositor presentation timestamps. Software capture
latency is included in the playback intervals. The preview's final duration
repeats its preceding interval because there is no following sample. Raw generated
PPMs are removed only after the archived images and animation reopen correctly.
