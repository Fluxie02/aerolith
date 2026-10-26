# Owner brief: after first real use (26 October 2026)

The owner ran AEROLITH on their own PC (4K, scale 1.5, NVIDIA, Hyprland
0.56.2) and found the shell "alien" and "not new". These are their answers
to a structured interview, recorded as given. They are the input for the
next design round (Astra) and the systems work that goes with it (Opus,
Sol). AEROLITH is a public project: decisions must hold for every user,
not only the owner's gaming setup.

## Order

**Alpha first, then the redesign.** Fix what is broken, ship the alpha so
the owner can use it and list what is wrong, then redesign.

## What is wrong now

- **Decoration that does nothing.** The art itself is liked ("the art now
  is nice"), but some parts do not move, some are too big and do not fit,
  and some numbers are useless.
- **Useless:** the scale numbers (000, 330, 030, 300, 270, 240, 120 around
  the ring; 839 / 961 on the right edge) and the big split "PIY TI" title.
- **Too big / does not fit:** the wing (airframe) shape and the bottom app
  bar.
- The bottom app links only opened the Navigator (fixed for the alpha: they
  now switch to or start the application).

## Direction

- **Newness:** "surprise me", as long as it makes sense at once.
- **Motion:** both real data and ambient motion: rings, needles and bars
  show real things where they fit; slow ambient motion for the rest.
  Liveliness: **noticeable**, clearly alive but never distracting.
- **Words:** keep the technical capitals style, but every label must say
  something a user understands.

## Per element

- **Wing:** keep it as the centrepiece and **make it alive**, e.g. it turns
  to point at the active workspace when you switch.
- **Workspace ring (stations 01–05):** keep it and **make it work**: it
  clearly shows where windows are and is clickable.
- **Right side:** the "PIY TI" title goes; **Now playing** takes its place
  (title, artist, cover, play/pause).
- **Bottom app bar:** much smaller; **the user's own apps, chosen
  automatically by use** (most used), instead of the fixed five (Firefox,
  LibreOffice, Steam, Discord, ArtCraft).
- **Top bar:** add **network** (Wi-Fi/ethernet, click to switch) and
  **Bluetooth** (click to connect). Roadmap D08.
- **Overlay (Deck):** "too much at once". Keep **search and launch**
  (Command), **window overview** (Navigator) and **system monitor**
  (Systems). Signal, Routines, AI, Help and Settings were not chosen: fold
  them in, move them elsewhere or hide them (Settings must stay reachable).
  Audio and media controls were not chosen for the overlay; media lives on
  the desktop (Now playing).
- **First run:** a **short tour** of the four or five key things.

## Split of the work

- Astra (visual): wing motion, ring, Now playing panel, smaller app bar,
  label wording, overlay simplification, tour visuals, removing dead
  decoration, fit at every size including 4K at scale 1.5.
- Opus / Sol (systems): most-used application ranking (Store already
  records launches), workspace ring data and clicks, media service for Now
  playing, network and Bluetooth services (Quickshell Networking and
  Bluetooth modules), tour state, Deck bay registry changes.
