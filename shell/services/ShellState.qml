pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import "../lib/shellstate.mjs" as S

// Independent output lifecycles, driven by shared Hyprland snapshots. One
// scheduler serves transient entry/restore/release work for every output.
Singleton {
    id: root
    readonly property bool available: Compositor.available
    property var outputStates: ({})
    readonly property var desktopState: ({ phase: S.DESKTOP, fullscreen: false,
        ownerClass: "", ambientHeld: false, released: false })
    function stateFor(name) { return outputStates[name] || desktopState; }
    function releasedFor(name) { return stateFor(name).released; }
    function heldFor(name) { return stateFor(name).ambientHeld; }

    // Compatibility: the original public state describes the primary output.
    readonly property var primaryState: stateFor(Ui.screenName)
    readonly property string phase: primaryState.phase
    readonly property bool ambientHeld: primaryState.ambientHeld
    readonly property bool surfacesReleased: primaryState.released
    readonly property bool fullscreen: primaryState.fullscreen
    readonly property string ownerClass: primaryState.ownerClass

    readonly property var detection: {
        const monitors = [];
        const mons = available ? Hyprland.monitors.values : [];
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const ipc = m.lastIpcObject || {};
            monitors.push({ name: m.name,
                activeWorkspaceId: m.activeWorkspace ? m.activeWorkspace.id : (ipc.activeWorkspace ? ipc.activeWorkspace.id : -1),
                specialWorkspaceId: ipc.specialWorkspace ? ipc.specialWorkspace.id : 0 });
        }
        const clients = [];
        const list = available ? Hyprland.toplevels.values : [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ipc = t.lastIpcObject || {};
            clients.push({ address: t.address,
                workspaceId: t.workspace ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : -1), ipc: ipc });
        }
        return { monitors: monitors, clients: clients };
    }

    property var pending: []
    property int timerId: 0
    readonly property var scheduler: ({
        setTimeout: (fn, ms) => {
            const id = ++root.timerId;
            root.pending.push({ id: id, at: Date.now() + ms, fn: fn });
            root.schedule();
            return id;
        },
        clearTimeout: id => {
            root.pending = root.pending.filter(t => t.id !== id);
            root.schedule();
        }
    })
    function schedule() {
        deadline.stop();
        if (!pending.length) return;
        pending.sort((a, b) => a.at - b.at);
        deadline.interval = Math.max(1, pending[0].at - Date.now());
        deadline.start();
    }
    Timer {
        id: deadline
        onTriggered: {
            const now = Date.now();
            const due = root.pending.filter(t => t.at <= now);
            root.pending = root.pending.filter(t => t.at > now);
            for (let i = 0; i < due.length; i++) due[i].fn();
            root.schedule();
        }
    }
    readonly property var lifecycles: S.createOutputLifecycles({
        scheduler: scheduler,
        onChange: states => root.outputStates = states,
        onTransition: (name, next, previous, detected) => {
            Log.info("state", previous + " -> " + next + " [" + name + "]"
                + (next === S.SUSPENDED ? " (fullscreen: " + (detected.appClass || "unknown") + ")" : ""));
            if (next === S.SUSPENDED && Ui.overlayScreen && Ui.overlayScreen.name === name) Ui.close();
        }
    })
    function update() {
        lifecycles.update(Displays.outputs, available ? detection : null);
    }
    onDetectionChanged: Qt.callLater(root.update)
    Connections {
        target: Displays
        function onOutputsChanged() { Qt.callLater(root.update); }
    }

    Binding {
        target: Theme
        property: "ambientSuspended"
        value: root.ambientHeld
    }

    readonly property var triggers: ["fullscreen", "workspacev2", "workspace", "activewindowv2", "openwindow", "closewindow", "movewindowv2", "movewindow", "activespecial", "activespecialv2", "focusedmon", "focusedmonv2", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"]
    Connections {
        target: root.available ? Hyprland : null
        function onRawEvent(event) {
            if (root.triggers.indexOf(event.name) >= 0) refresh.restart();
        }
    }
    Timer {
        id: refresh
        interval: 30
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
    }
    Component.onCompleted: {
        update();
        if (available) refresh.start();
    }
    Component.onDestruction: lifecycles.dispose()
}
