# UI-001 visual studies

Three executable QML compositions, using the production services, configuration,
registry and IPC unchanged. These are phase 3 explorations, not installable shells.

| Directory | Composition |
|---|---|
| parallax | Surveying instrument, dark field, static orbit and two-column workspace map. |
| cut | Warm planes, right slab, tall three-column workspace sections. |
| interleaf | Selected direction: inverse navigation margin, pale field, readable workspace passages. |

Each directory contains shell.qml and relative symlinks to the repository's
unchanged core/services/lib/components/modules. `visual` links to common/ so
Quickshell's scanner sees the shared presentation within the shell root. Do not
edit production files through these links. The prototypes need this checkout;
they are not standalone packages. AI=1's relocated copy is not supported by these
relative links. Systems/Routines/Help deliberately use the original bays and
retain their original appearance; AI has an explicit unavailable placeholder.

The background PanelWindow is a visual demonstration. Production lifecycle and
secure locking remain requests to Claude. There is no new process, IPC service,
network/backlight service, schema, shader or image asset. Command, navigator and
audio action/key functions are copied from the current presentation files; do
not promote these exploratory copies as a second systems implementation.

From the repository root, with the existing aerolith-dev Docker image:

```bash
SHELL_PATH=prototypes/interleaf AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh prototypes/capture.sh build/interleaf-review
SHELL_PATH=prototypes/cut AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh prototypes/capture.sh build/cut-review
SHELL_PATH=prototypes/parallax AUDIO=1 MEDIA=1 MPV_AO=pipewire \
  tools/headless/run.sh prototypes/capture.sh build/parallax-review
SHELL_PATH=prototypes/interleaf RES=1280x720 CONFIG=prototypes/accessibility.json \
  AUDIO=1 MEDIA=1 tools/headless/run.sh prototypes/check-layout.sh build/interleaf-small-review
```

Use a different output directory each time: run.sh empties it. Inspect every PNG
and qs.log, especially TypeError/ReferenceError/Unable to assign/binding loops.
Capture states: exposed desktop, launcher (`@ a` queries the real windows),
workspace overview, a real foot window displaying the repository README,
injected notice using real fixture titles, and live sound controls. The foot
colours and sway focus border are scenario-only preview styling. They are not
proof of Hyprland window-decoration integration. Mock window records are not
actual Firefox/Nautilus/Code windows. The injected shell.notify command also
reports its success, hence two annotations; that existing behavior is exposed.

The initial PipeWire setup sometimes reports mpv unlinked in this environment.
The UI faithfully displays “Unlinked” and any reported bound volume; it does not
invent an audible route or a finite duration for the live sine source.

Density, user fonts, scale and motion/effect flags drive the experimental style.
The selected direction collapses its navigation at smaller effective dimensions.
Additional production setting fidelity, maximum-window stress, scroll affordances
and cross-bay/exit motion are specified in docs/design/DIRECTION.md for the next
implementation phase.
