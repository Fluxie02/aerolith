//@ pragma UseQApplication
//@ pragma AppId aerolith
import QtQuick
import Quickshell
import qs.core
import qs.services
import "modules"
import "visual"
ShellRoot {
    readonly property var services: [Compositor, Apps, Audio, Media, Telemetry, Power, Routines, Notifications, ShellCommands]
    World { concept: 1 }
    ControlSurface {}
}
