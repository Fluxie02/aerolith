# Real application captures

These are real Linux application windows beside the real production QML shell,
rendered by headless Sway with pixman/software rendering. They are not app mockups.
The shell uses the Hyprland protocol fixture separately: its app roster and focus
labels do **not** describe Sway's actual clients. These captures establish shared
appearance and application compatibility, not live app-to-shell integration.

| Application | THEARS | PIYTI | What is established |
|---|---|---|---|
| Firefox 158.0.1 | [Screenshot](thears/firefox.png) | [Screenshot](piyti/firefox.png) | The isolated profile supplies matching `userChrome.css` and `userContent.css`, with `toolkit.legacyUserProfileCustomizations.stylesheets=true`. The screenshot visibly establishes the browser chrome treatment. A local HTML field-note document is an explicit content fixture; internal `about:home`/new-tab styling is not pictured. The static theme manifest is validated separately; it is not installed in these captures. |
| LibreOffice Writer 26.8.1.1 | [Screenshot](thears/libreoffice.png) | [Screenshot](piyti/libreoffice.png) | Actual GTK3 backend uses the shared GTK theme. LibreOffice's `unopkg` accepts the appearance extension containing both schemes, and a disposable profile selects the corresponding scheme. The document stays white: scheme acceptance does not establish that every canvas colour was applied. The read-only field-note document is a local FODT fixture. |
| ArtCraft PhotoCraft 0.10.0 | [Screenshot](thears/photocraft.png) | [Screenshot](piyti/photocraft.png) | The actual Linux binary starts and displays its own dark interface and CPU-rendering fallback modal in this software environment. This release does **not** load the proposed token recolouring; ArtCraft's documented theme override is debug-build-only. The screenshots establish launch and visual coexistence, not a themed PhotoCraft release. |

The screenshot pixels are unretouched. Sway places the windows for a readable
comparison; this is not evidence for the supplied Hyprland rules. Firefox's
sandbox warning and PhotoCraft's GPU fallback are container conditions and remain
visible. Steam and Discord were not launched, no accounts were used, and no
Steam/Discord image in the motion evidence should be read as a real client.

`start-container.sh`, `prepare.py`, `run-captures.sh` and `capture.sh` record the
reproducible container process. Firefox and LibreOffice were installed only into
an `aerolith-dev`-based `docker run --rm` container named
`aerolith-ui012-apps`; the downloaded PhotoCraft archive also lived inside it.
The container was stopped and removed after capture, with no image commit or host
app installation. Package caches were cleared inside the throwaway container.
The retained `app-versions.txt`, Sway trees, direction files, extension logs and
capture logs are evidence. Real Hyprland compositing, GPU use, game/fullscreen
VRAM reclamation and dynamic app state remain Claude's systems verification.
