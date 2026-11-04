pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// Quickshell 0.3.x IdleMonitor uses ext-idle-notify-v1 and seconds.
// Shared across outputs; OLED-2 opts in by setting a positive timeout.
Singleton {
    id: root

    property real timeout: 0 // seconds; zero/negative/non-finite means off
    readonly property bool idle: monitor.enabled && monitor.isIdle

    IdleMonitor {
        id: monitor
        enabled: isFinite(root.timeout) && root.timeout > 0
        timeout: enabled ? root.timeout : 0
        respectInhibitors: true
    }
}
