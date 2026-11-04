pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Quickshell 0.3.x IdleMonitor uses ext-idle-notify-v1 and seconds.
// One shared seat monitor, disabled when no connected output opts in.
Singleton {
    id: root

    property real timeout: Displays.outputs.some(o => o.profile === "oled") ? Config.display.oled.idleDimAfter : 0
    readonly property bool idle: monitor.enabled && monitor.isIdle

    IdleMonitor {
        id: monitor
        enabled: isFinite(root.timeout) && root.timeout > 0
        timeout: enabled ? root.timeout : 0
        respectInhibitors: true
    }
}
