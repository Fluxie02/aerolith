//@ pragma UseQApplication
//@ pragma AppId aerolith

// AEROLITH: adaptive command-centred desktop shell for Hyprland.
// Entry point loaded by Quickshell: `qs -p <this directory>`.

import QtQuick
import Quickshell
import qs.core
import qs.services
import "modules/strip"
import "modules/tour"
import "modules/welcome"
import "modules/deck"
import "modules/notices"
import "modules/ground"
import "modules/osd"
import "modules/session"
import "modules/lock"
import "modules"

ShellRoot {
    id: shell

    // Touch services so they initialise and register their commands even
    // before anything visible references them.
    readonly property var services: [Compositor, Displays, Idle, ShellState, Apps, Audio, Media, Telemetry, Power, Brightness, Routines, Notifications, ShellCommands, AppThemes, Welcome, Tour, SystemInfo]

    // Stable screen keys retain delegates on focus/metadata changes. Each
    // loader destroys only its output's surface while fullscreen owns it.
    Variants {
        model: Displays.groundScreens
        LazyLoader {
            id: groundLoader
            required property var modelData
            // A removed lifecycle falls back to desktop before Variants'
            // deferred delegate deletion. Never reload it on a dead screen.
            readonly property var outputScreen: Displays.liveScreen(modelData)
            active: !!outputScreen && !ShellState.releasedFor(outputScreen.name)
            GroundSurface { outputScreen: groundLoader.outputScreen }
        }
    }
    Variants {
        model: Displays.stripScreens
        LazyLoader {
            id: stripLoader
            required property var modelData
            // A removed lifecycle falls back to desktop before Variants'
            // deferred delegate deletion. Never reload it on a dead screen.
            readonly property var outputScreen: Displays.liveScreen(modelData)
            active: !!outputScreen && !ShellState.releasedFor(outputScreen.name)
            FlightStrip { outputScreen: stripLoader.outputScreen }
        }
    }

    LazyLoader {
        active: !!Ui.overlayScreen && (!ShellState.releasedFor(Ui.overlayScreen.name) || Ui.deckOpen || Ui.deckMapped)
        Deck {
            aiBay: aiLoader.bayComponent
        }
    }

    LazyLoader {
        active: !!Ui.noticeScreen && !ShellState.releasedFor(Ui.noticeScreen.name)
        NoticeColumn {}
    }

    // Volume and microphone feedback. Shown during fullscreen too: it answers
    // a key the user pressed, and its surface exists only while shown.
    OsdHost {}

    // Lock, suspend, log out, reboot, power off. Opened explicitly, so it also
    // opens over a fullscreen window; its surface exists only while open.
    SessionHost {}

    // AEROLITH's own lock screen (lock.enabled), through the Wayland
    // session-lock protocol: the compositor keeps the session locked even if
    // the shell stops.
    LockHost {}

    LazyLoader { id: welcomeSurface; objectName: "welcomeLoader"; active: Welcome.active; WelcomeHost {} }

    LazyLoader { id: tourSurface; objectName: "tourLoader"; active: Tour.active; TourHost {} }

    ControlSurface {}

    AiLoader {
        id: aiLoader
    }

    Component.onCompleted: {
        Log.info("shell", "AEROLITH started on " + (Ui.screenName || "no display") + (Ui.multipleDisplays ? " (" + Ui.screenCount + " displays connected)" : "") + "; Hyprland " + (Compositor.available ? "connected" : "not detected") + (Paths.devMode ? "; development mode" : ""));
    }
}
