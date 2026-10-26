//@ pragma UseQApplication
//@ pragma AppId aerolith

// AEROLITH: adaptive command-centred desktop shell for Hyprland.
// Entry point loaded by Quickshell: `qs -p <this directory>`.

import QtQuick
import Quickshell
import qs.core
import qs.services
import "modules/strip"
import "modules/deck"
import "modules/notices"
import "modules/ground"
import "modules/osd"
import "modules/session"
import "modules"

ShellRoot {
    id: shell

    // Touch services so they initialise and register their commands even
    // before anything visible references them.
    readonly property var services: [Compositor, ShellState, Apps, Audio, Media, Telemetry, Power, Brightness, Routines, Notifications, ShellCommands, AppThemes]

    // While a fullscreen window owns the output (ShellState), the visual
    // surfaces are destroyed, not just hidden: a hidden window keeps its
    // scene graph and render resources. They are rebuilt once when it ends.
    // Summoning the Deck during fullscreen maps the Deck alone; ambient
    // motion stays held until the shell is back to desktop.
    LazyLoader {
        active: !ShellState.surfacesReleased
        GroundSurface {}
    }

    LazyLoader {
        active: !ShellState.surfacesReleased
        FlightStrip {}
    }

    LazyLoader {
        active: !ShellState.surfacesReleased || Ui.deckOpen || Ui.deckMapped
        Deck {
            aiBay: aiLoader.bayComponent
        }
    }

    LazyLoader {
        active: !ShellState.surfacesReleased
        NoticeColumn {}
    }

    // Volume and microphone feedback. Shown during fullscreen too: it answers
    // a key the user pressed, and its surface exists only while shown.
    OsdHost {}

    // Lock, suspend, log out, reboot, power off. Opened explicitly, so it also
    // opens over a fullscreen window; its surface exists only while open.
    SessionHost {}

    ControlSurface {}

    AiLoader {
        id: aiLoader
    }

    Component.onCompleted: {
        Log.info("shell", "AEROLITH started on " + (Ui.screenName || "no display") + (Ui.multipleDisplays ? " (" + Ui.screenCount + " displays connected; single-display mode)" : "") + "; Hyprland " + (Compositor.available ? "connected" : "not detected") + (Paths.devMode ? "; development mode" : ""));
    }
}
