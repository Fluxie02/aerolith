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
import "modules"

ShellRoot {
    id: shell

    // Touch services so they initialise and register their commands even
    // before anything visible references them.
    readonly property var services: [Compositor, Apps, Audio, Media, Telemetry, Power, Routines, Notifications, ShellCommands]

    GroundSurface {}

    FlightStrip {}

    Deck {
        aiBay: aiLoader.bayComponent
    }

    NoticeColumn {}

    ControlSurface {}

    AiLoader {
        id: aiLoader
    }

    Component.onCompleted: {
        Log.info("shell", "AEROLITH started on " + (Ui.screenName || "no display") + (Ui.multipleDisplays ? " (" + Ui.screenCount + " displays connected; single-display mode)" : "") + "; Hyprland " + (Compositor.available ? "connected" : "not detected") + (Paths.devMode ? "; development mode" : ""));
    }
}
