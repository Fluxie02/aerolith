pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import "../lib/displays.mjs" as D

// One event-driven output policy for the whole shell. Qt owns screen lifetime;
// the Hyprland snapshot contributes metadata, focus and primary ordering only.
Singleton {
    id: root
    readonly property bool available: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property var monitors: {
        const out = [];
        const list = available ? Hyprland.monitors.values : [];
        const focused = available ? Hyprland.focusedMonitor : null;
        for (let i = 0; i < list.length; i++) {
            const m = list[i];
            const ipc = m.lastIpcObject || {};
            out.push({ name: m.name, id: m.id, scale: m.scale,
                refreshRate: ipc.refreshRate, focused: focused ? m === focused : m.focused });
        }
        return out;
    }
    readonly property var resolved: D.resolveDisplays(Quickshell.screens, monitors, Config.display,
        { strip: Config.strip, ground: Config.ground })
    readonly property var outputs: resolved.outputs
    readonly property var primary: resolved.primary
    readonly property var focused: resolved.focused
    readonly property var overlay: resolved.overlay
    readonly property var notices: resolved.notices
    readonly property var groundScreens: outputs.filter(o => o.ground).map(o => o.screen)
    readonly property var stripScreens: outputs.filter(o => o.strip).map(o => o.screen)
    readonly property var overlayScreen: overlay ? overlay.screen : null
    readonly property var noticeScreen: notices ? notices.screen : null

    function output(name) { return D.namedOutput(outputs, name); }
    function settings(name) { return D.settingsFor(Config.display, name, { strip: Config.strip, ground: Config.ground }); }

    // Quickshell updates snapshots asynchronously. Refresh only after events,
    // coalescing a hotplug/focus burst into one request, never an idle poll.
    readonly property var triggers: ["focusedmon", "focusedmonv2", "monitoradded", "monitoraddedv2",
        "monitorremoved", "monitorremovedv2", "configreloaded"]
    Connections {
        target: root.available ? Hyprland : null
        function onRawEvent(event) {
            if (root.triggers.indexOf(event.name) >= 0) refresh.restart();
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { if (root.available) refresh.restart(); }
    }
    Timer {
        id: refresh
        interval: 30
        onTriggered: Hyprland.refreshMonitors()
    }
    Component.onCompleted: if (available) refresh.start()
}
