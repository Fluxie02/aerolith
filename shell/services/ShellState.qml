pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import "../lib/shellstate.mjs" as S

// The shell's lifecycle state (roadmap B01/B02): the one place that decides
// whether a fullscreen window owns the selected output. Components subscribe
// to these properties instead of detecting fullscreen themselves.
//
// Detection is event-driven. Hyprland events only ask Quickshell to refresh
// its client and monitor snapshots; `detected` is a binding over those
// snapshots, so it re-evaluates when the data actually arrives. Nothing polls.
//
// Ordering on entry: ambient motion is held first (Theme.ambientSuspended),
// and the surfaces are released one event-loop turn later, so every animation
// has completed before its surface goes away. On exit the surfaces return
// first and ambient motion resumes only when the phase is back to desktop.
Singleton {
    id: root

    readonly property bool available: Compositor.available

    // "desktop", "suspended" or "restoring" (lib/shellstate.mjs).
    property string phase: S.DESKTOP
    // Ambient motion must stay still (suspended or still restoring).
    property bool ambientHeld: false
    // Visual surfaces are unmapped and their content unloaded.
    property bool surfacesReleased: false

    // The window that owns the output, for logs and the Systems bay.
    readonly property var detected: available ? S.outputFullscreen(snapshot()) : S.outputFullscreen(null)
    readonly property bool fullscreen: detected.fullscreen
    readonly property string ownerClass: detected.appClass

    function snapshot() {
        const monitors = [];
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const ipc = m.lastIpcObject || {};
            monitors.push({
                name: m.name,
                activeWorkspaceId: m.activeWorkspace ? m.activeWorkspace.id : (ipc.activeWorkspace ? ipc.activeWorkspace.id : -1),
                specialWorkspaceId: ipc.specialWorkspace ? ipc.specialWorkspace.id : 0
            });
        }
        const clients = [];
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ipc = t.lastIpcObject || {};
            clients.push({
                address: t.address,
                workspaceId: t.workspace ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : -1),
                ipc: ipc
            });
        }
        return {
            output: Ui.screenName,
            monitors: monitors,
            clients: clients
        };
    }

    onFullscreenChanged: lifecycle.update(fullscreen)

    readonly property var scheduler: ({
            setTimeout: (fn, ms) => {
                const t = timerComponent.createObject(root, {
                    interval: ms
                });
                t.triggered.connect(() => {
                    t.destroy();
                    fn();
                });
                t.start();
                return t;
            },
            clearTimeout: t => {
                if (t) {
                    t.stop();
                    t.destroy();
                }
            }
        })
    readonly property var lifecycle: S.createLifecycle({
        scheduler: scheduler,
        onChange: (next, previous) => root.enter(next, previous)
    })

    function enter(next, previous) {
        phase = next;
        Log.info("state", previous + " -> " + next + (next === S.SUSPENDED ? " (fullscreen: " + (ownerClass || "unknown") + ")" : ""));
        if (next === S.SUSPENDED) {
            ambientHeld = true;
            Ui.close();
            Qt.callLater(() => root.surfacesReleased = root.phase === S.SUSPENDED);
        } else if (next === S.RESTORING) {
            surfacesReleased = false;
        } else {
            surfacesReleased = false;
            ambientHeld = false;
        }
    }

    Binding {
        target: Theme
        property: "ambientSuspended"
        value: root.ambientHeld
    }

    // Hyprland events that can change who owns the output. Several arrive in
    // a burst (a fullscreen toggle sends fullscreen, activewindow and more),
    // so refreshes are coalesced.
    readonly property var triggers: ["fullscreen", "workspacev2", "workspace", "activewindowv2", "openwindow", "closewindow", "movewindowv2", "movewindow", "activespecial", "activespecialv2", "focusedmon", "focusedmonv2", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"]
    Connections {
        target: root.available ? Hyprland : null
        function onRawEvent(event) {
            if (root.triggers.indexOf(event.name) >= 0)
                refresh.restart();
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

    Component {
        id: timerComponent
        Timer {}
    }

    Component.onCompleted: if (available)
        refresh.start()
}
