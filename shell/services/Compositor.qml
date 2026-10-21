pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core
import "../lib/hyprdispatch.mjs" as HD

// Hyprland integration: workspace and window state from Quickshell's
// Hyprland module, and dispatches with verified results.
//
// Quickshell's Hyprland.dispatch() does not report success to QML, so
// actions here open Hyprland's request socket directly, send the request
// and interpret the reply ("ok" or an error). Requests are built only by
// lib/hyprdispatch.mjs, which validates every value and picks the Lua or
// hyprlang dialect from Hyprland.usingLua.
Singleton {
    id: root

    readonly property string signature: {
        const v = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        return v ? String(v) : "";
    }
    readonly property bool available: signature !== ""
    readonly property string dialect: available && Hyprland.usingLua ? HD.DIALECT_LUA : HD.DIALECT_LEGACY

    // Live state for the Flight Strip. Cheap bindings only; the full window
    // list is built on demand by windows().
    readonly property var workspaceObjects: available ? Hyprland.workspaces.values : []
    readonly property int focusedWorkspaceId: available && Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    // Quickshell only learns the active window from `activewindowv2` events,
    // so right after startup it is unknown. Until the first event arrives,
    // fall back to the window `j/activewindow` reported at startup.
    property string startupActiveAddress: ""
    readonly property var activeToplevel: {
        if (!available)
            return null;
        if (Hyprland.activeToplevel)
            return Hyprland.activeToplevel;
        if (startupActiveAddress === "")
            return null;
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++)
            if ("0x" + list[i].address === startupActiveAddress)
                return list[i];
        return null;
    }
    readonly property string activeTitle: activeToplevel ? activeToplevel.title : ""
    readonly property string activeClass: activeToplevel && activeToplevel.lastIpcObject ? String(activeToplevel.lastIpcObject["class"] || "") : ""
    readonly property int monitorCount: available ? Hyprland.monitors.values.length : 0

    // Screen sharing state from the documented `screencast` event.
    property bool screencastActive: false
    property string screencastOwner: ""

    // Normal workspaces (positive ids), with occupancy.
    readonly property var workspaces: {
        const out = [];
        const list = workspaceObjects;
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (w.id <= 0)
                continue;
            out.push({
                id: w.id,
                name: w.name,
                windows: w.toplevels ? w.toplevels.values.length : 0,
                focused: w.id === focusedWorkspaceId,
                urgent: w.urgent === true
            });
        }
        out.sort((a, b) => a.id - b.id);
        return out;
    }

    // Publish Hyprland's output order to the single-display picker.
    Binding {
        target: Ui
        property: "outputOrder"
        value: root.available ? Hyprland.monitors.values.slice().sort((a, b) => a.id - b.id).map(m => m.name) : []
    }

    function refresh() {
        if (!available)
            return;
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
    }

    // Build a plain window list. Positions come from the last IPC snapshot;
    // call refresh() first when geometry matters (the Navigator does).
    function windows() {
        if (!available)
            return [];
        const out = [];
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ipc = t.lastIpcObject || {};
            out.push({
                address: t.address,
                title: t.title || String(ipc.title || ""),
                appId: String(ipc["class"] || ipc.initialClass || ""),
                workspaceId: t.workspace ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : -1),
                at: Array.isArray(ipc.at) ? ipc.at : null,
                size: Array.isArray(ipc.size) ? ipc.size : null,
                floating: ipc.floating === true,
                fullscreen: ipc.fullscreen ? true : false,
                active: t.activated === true,
                urgent: t.urgent === true,
                toplevel: t
            });
        }
        return out;
    }

    function monitorGeometry() {
        if (!available)
            return null;
        const name = Ui.screenName;
        const list = Hyprland.monitors.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name || name === "")
                return {
                    x: list[i].x,
                    y: list[i].y,
                    width: list[i].width,
                    height: list[i].height,
                    scale: list[i].scale
                };
        return null;
    }

    // --- verified requests ---------------------------------------------------

    Component {
        id: requestComponent
        Socket {
            id: sock
            property string request: ""
            property bool raw: false
            property var resolve: null
            property string buffer: ""
            property bool finished: false

            function finish(error) {
                if (finished)
                    return;
                finished = true;
                watchdog.stop();
                const r = error ? {
                    ok: false,
                    message: error
                } : raw ? {
                    ok: true,
                    message: buffer
                } : HD.interpretReply(buffer);
                const cb = resolve;
                Qt.callLater(() => sock.destroy());
                if (cb)
                    cb(r);
            }

            parser: SplitParser {
                splitMarker: ""
                onRead: data => sock.buffer += data
            }
            onConnectionStateChanged: {
                if (connected) {
                    write(request);
                    flush();
                } else {
                    finish("");
                }
            }
            onError: error => finish("Hyprland socket error (" + error + ")")

            property Timer watchdog: Timer {
                interval: 3000
                running: true
                onTriggered: sock.finish("Hyprland did not answer within 3 s")
            }
        }
    }

    // Send a request ("dispatch ..." or "j/..."). Resolves with
    // { ok, message } from interpretReply, or with the reply text as
    // message when raw is true. Never rejects.
    function request(text, raw) {
        return new Promise(resolve => {
            if (!available) {
                resolve({
                    ok: false,
                    message: "Hyprland is not running"
                });
                return;
            }
            const sock = requestComponent.createObject(root, {
                request: text,
                raw: raw === true,
                resolve: resolve,
                path: Hyprland.requestSocketPath
            });
            if (!sock) {
                resolve({
                    ok: false,
                    message: "could not create Hyprland request"
                });
                return;
            }
            sock.connected = true;
        });
    }

    function dispatch(build) {
        let body;
        try {
            body = build(dialect);
        } catch (e) {
            return Promise.resolve({
                ok: false,
                message: String(e && e.message ? e.message : e)
            });
        }
        Log.debug("hypr", "dispatch " + body);
        return request("dispatch " + body);
    }

    function focusWorkspace(ws) {
        return dispatch(d => HD.focusWorkspace(d, ws));
    }
    function focusWindow(address) {
        return dispatch(d => HD.focusWindow(d, address));
    }
    function moveWindow(address, ws, follow) {
        return dispatch(d => HD.moveWindowToWorkspace(d, address, ws, follow));
    }
    function closeWindow(address) {
        return dispatch(d => HD.closeWindow(d, address));
    }

    function windowLabel(w) {
        return (w.appId ? w.appId + " — " : "") + (w.title || "untitled");
    }

    // --- events -------------------------------------------------------------

    Connections {
        target: root.available ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "screencast") {
                const args = event.parse(2);
                root.screencastActive = args[0] === "1";
                root.screencastOwner = args[1] === "1" ? "window" : args[1] === "2" ? "region" : "monitor";
            } else if (event.name === "configreloaded") {
                root.refresh();
            }
        }
    }

    // --- commands -------------------------------------------------------------

    readonly property var hyprAvailable: () => root.available ? true : "Hyprland is not running"

    function result(r, okMessage, extra) {
        return r.ok ? Registry.ok(okMessage, extra) : Registry.fail(r.message);
    }

    function query(command) {
        return request("j/" + command, true).then(r => {
            if (!r.ok)
                return null;
            try {
                return JSON.parse(r.message);
            } catch (e) {
                return null;
            }
        });
    }

    Component.onCompleted: {
        if (available)
            query("activewindow").then(w => {
                if (w && typeof w.address === "string" && /^0x[0-9a-f]+$/.test(w.address))
                    root.startupActiveAddress = w.address;
            });
        Registry.register({
            id: "workspace.focus",
            title: "Go to workspace",
            category: "workspaces",
            alias: "ws",
            keywords: ["switch", "workspace", "desktop"],
            description: "Switch to a workspace by number",
            params: [
                {
                    name: "workspace",
                    type: "int",
                    min: 1,
                    max: 99,
                    required: true,
                    description: "Workspace number"
                }
            ],
            routine: true,
            available: hyprAvailable,
            run: args => {
                const prev = root.focusedWorkspaceId;
                return root.focusWorkspace(args.workspace).then(r => root.result(r, "Workspace " + args.workspace, prev > 0 && prev !== args.workspace ? {
                    undo: {
                        commandId: "workspace.focus",
                        args: {
                            workspace: prev
                        }
                    }
                } : undefined));
            }
        });
        Registry.register({
            id: "workspace.next",
            title: "Next workspace",
            category: "workspaces",
            keywords: ["right"],
            routine: true,
            available: hyprAvailable,
            run: () => {
                const target = Math.min(99, Math.max(1, root.focusedWorkspaceId + 1));
                return root.focusWorkspace(target).then(r => root.result(r, "Workspace " + target));
            }
        });
        Registry.register({
            id: "workspace.previous",
            title: "Previous workspace",
            category: "workspaces",
            keywords: ["left", "prev"],
            routine: true,
            available: hyprAvailable,
            run: () => {
                const target = Math.max(1, root.focusedWorkspaceId - 1);
                return root.focusWorkspace(target).then(r => root.result(r, "Workspace " + target));
            }
        });
        Registry.register({
            id: "window.focus",
            title: "Focus window",
            category: "windows",
            hidden: true,
            params: [
                {
                    name: "address",
                    type: "string",
                    required: true,
                    maxLength: 18,
                    pattern: "(0x)?[0-9a-fA-F]{1,16}",
                    patternHint: "must be a window address"
                }
            ],
            available: hyprAvailable,
            run: args => root.focusWindow(args.address).then(r => root.result(r, "Window focused"))
        });
        Registry.register({
            id: "window.move",
            title: "Move window to workspace",
            category: "windows",
            hidden: true,
            params: [
                {
                    name: "address",
                    type: "string",
                    required: true,
                    maxLength: 18,
                    pattern: "(0x)?[0-9a-fA-F]{1,16}",
                    patternHint: "must be a window address"
                },
                {
                    name: "workspace",
                    type: "int",
                    min: 1,
                    max: 99,
                    required: true
                },
                {
                    name: "follow",
                    type: "bool",
                    default: false
                }
            ],
            available: hyprAvailable,
            run: args => root.moveWindow(args.address, args.workspace, args.follow).then(r => root.result(r, "Window moved to workspace " + args.workspace))
        });
        Registry.register({
            id: "window.move-active",
            title: "Move active window to workspace",
            category: "windows",
            alias: "mv",
            keywords: ["send", "move"],
            params: [
                {
                    name: "workspace",
                    type: "int",
                    min: 1,
                    max: 99,
                    required: true
                }
            ],
            routine: true,
            available: () => !root.available ? "Hyprland is not running" : root.activeToplevel ? true : "No active window",
            run: args => root.moveWindow(root.activeToplevel.address, args.workspace, false).then(r => root.result(r, "Window sent to workspace " + args.workspace))
        });
        Registry.register({
            id: "window.close",
            title: "Close window",
            category: "windows",
            hidden: true,
            description: "Ask the application to close (it may prompt to save)",
            params: [
                {
                    name: "address",
                    type: "string",
                    required: true,
                    maxLength: 18,
                    pattern: "(0x)?[0-9a-fA-F]{1,16}",
                    patternHint: "must be a window address"
                }
            ],
            available: hyprAvailable,
            run: args => root.closeWindow(args.address).then(r => root.result(r, "Close requested"))
        });

        Registry.registerProvider({
            id: "windows",
            kind: "window",
            items: () => {
                const list = root.windows();
                return list.map(w => ({
                            id: w.address,
                            title: w.title || w.appId || "untitled",
                            subtitle: w.appId + "  ·  workspace " + w.workspaceId,
                            keywords: [w.appId],
                            icon: w.appId,
                            category: "windows",
                            commandId: "window.focus",
                            args: {
                                address: w.address
                            },
                            badge: "WS" + w.workspaceId
                        }));
            }
        });
        Registry.registerProvider({
            id: "workspaces",
            kind: "workspace",
            items: () => root.workspaces.map(w => ({
                        id: String(w.id),
                        title: "Workspace " + w.id + (w.name !== String(w.id) ? " · " + w.name : ""),
                        subtitle: w.windows + (w.windows === 1 ? " window" : " windows") + (w.focused ? " · current" : ""),
                        category: "workspaces",
                        commandId: "workspace.focus",
                        args: {
                            workspace: w.id
                        }
                    }))
        });
    }
}
