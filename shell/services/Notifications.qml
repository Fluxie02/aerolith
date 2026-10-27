pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.core

// Optional desktop notification server (org.freedesktop.Notifications).
// Off by default: most Hyprland setups already run mako, dunst or swaync,
// and only one process can own the bus name. Enable with
// notifications.server = true after stopping the other daemon.
Singleton {
    id: root

    readonly property bool enabled: Config.notifications.server
    property var server: null
    property var items: []
    readonly property int count: items.length
    readonly property bool doNotDisturb: Config.notifications.doNotDisturb
    property var popups: []

    Component {
        id: serverComponent
        NotificationServer {
            keepOnReload: false
            bodySupported: true
            bodyMarkupSupported: false
            actionsSupported: true
            imageSupported: false
            onNotification: n => {
                n.tracked = true;
                const all = [n].concat(root.items);
                root.items = all.slice(0, 100);
                // Dropping our reference alone leaves a tracked notification
                // alive in Quickshell and open for its sender.
                for (let i = 100; i < all.length; i++)
                    all[i].dismiss();
                if (!root.doNotDisturb && n.urgency !== NotificationUrgency.Low)
                    root.showPopup(n);
                n.closed.connect(() => {
                    root.items = root.items.filter(x => x !== n);
                    root.dropPopup(n);
                });
            }
        }
    }

    function sync() {
        if (enabled && !server) {
            server = serverComponent.createObject(root);
            Log.info("notifications", "notification server enabled");
        } else if (!enabled && server) {
            server.destroy();
            server = null;
            items = [];
            popups = [];
            popupExpiry = {};
        }
    }

    // Popups are the notification objects themselves, so views can key on
    // them. Each popup expires popupTimeoutMs after it was shown; the time is
    // fixed then, so later popups never extend earlier ones.
    property var popupExpiry: ({})

    // While a fullscreen window owns the output the notice surfaces are
    // released (ShellState), so popups cannot be seen: their clock stops and
    // they get their remaining time after the game. A popup that arrives
    // during it gets its full time.
    readonly property bool held: ShellState.surfacesReleased
    property real heldAt: 0
    onHeldChanged: {
        if (held) {
            heldAt = Date.now();
            popupTimer.stop();
            return;
        }
        const shift = Date.now() - heldAt;
        const expiry = {};
        for (const k in popupExpiry)
            expiry[k] = popupExpiry[k] + shift;
        popupExpiry = expiry;
        popupTimer.schedule();
    }

    function showPopup(n) {
        const expiry = Object.assign({}, popupExpiry);
        expiry[n.id] = (held ? heldAt : Date.now()) + Config.notifications.popupTimeoutMs;
        const kept = popups.concat([n]).slice(-3);
        const ids = kept.map(x => String(x.id));
        for (const k in expiry)
            if (ids.indexOf(k) === -1)
                delete expiry[k];
        popupExpiry = expiry;
        popups = kept;
        popupTimer.schedule();
    }

    function dropPopup(n) {
        if (popups.indexOf(n) === -1)
            return;
        const expiry = Object.assign({}, popupExpiry);
        delete expiry[n.id];
        popupExpiry = expiry;
        popups = popups.filter(x => x !== n);
        popupTimer.schedule();
    }

    function actionsOf(n) {
        const out = [];
        const list = n && n.actions ? n.actions : [];
        for (let i = 0; i < list.length; i++)
            out.push(list[i]);
        return out;
    }

    // Invoke one of a notification's actions by identifier. Quickshell
    // dismisses non-resident notifications after an action.
    function invokeAction(n, identifier) {
        const action = actionsOf(n).filter(a => a.identifier === identifier)[0];
        if (!action)
            return false;
        action.invoke();
        dropPopup(n);
        return true;
    }

    // Clicking a popup: the freedesktop "default" action when the sender
    // offers one, otherwise just hide the popup (it stays in the list).
    function activate(n) {
        if (!invokeAction(n, "default"))
            dropPopup(n);
    }

    Timer {
        id: popupTimer
        function schedule() {
            stop();
            if (root.held)
                return;
            let next = -1;
            for (let i = 0; i < root.popups.length; i++) {
                const at = root.popupExpiry[root.popups[i].id];
                if (at !== undefined && (next === -1 || at < next))
                    next = at;
            }
            if (next === -1)
                return;
            interval = Math.max(1, next - Date.now());
            start();
        }
        onTriggered: {
            const now = Date.now();
            const expired = root.popups.filter(n => (root.popupExpiry[n.id] || 0) <= now);
            for (let i = 0; i < expired.length; i++)
                root.dropPopup(expired[i]);
            schedule();
        }
    }

    function clearAll() {
        const list = items.slice();
        for (let i = 0; i < list.length; i++)
            list[i].dismiss();
        items = [];
        popups = [];
        popupExpiry = {};
    }

    Connections {
        target: Config
        function onReloaded() {
            root.sync();
        }
    }

    Component.onCompleted: {
        sync();
        Registry.register({
            id: "notifications.clear",
            title: "Clear notifications",
            category: "shell",
            keywords: ["dismiss", "notifications"],
            available: () => root.enabled ? true : "AEROLITH is not the notification server (notifications.server)",
            run: () => {
                const n = root.count;
                root.clearAll();
                return Registry.ok("Cleared " + n + " notification" + (n === 1 ? "" : "s"));
            }
        });
        Registry.register({
            id: "notifications.dnd.toggle",
            title: "Toggle do not disturb",
            category: "shell",
            alias: "dnd",
            keywords: ["focus", "quiet", "notifications"],
            available: () => root.enabled ? true : "AEROLITH is not the notification server (notifications.server)",
            run: () => {
                const next = !root.doNotDisturb;
                const err = Config.setValue("notifications.doNotDisturb", next);
                return err ? Registry.fail(err) : Registry.ok("Do not disturb " + (next ? "on" : "off"));
            }
        });
        Registry.register({
            id: "notifications.dismiss",
            title: "Dismiss notification",
            category: "shell",
            hidden: true,
            record: false,
            params: [
                {
                    name: "id",
                    type: "int",
                    min: 0,
                    required: true
                }
            ],
            run: args => {
                const n = root.items.filter(x => x.id === args.id)[0];
                if (!n)
                    return Registry.fail("Notification is gone");
                n.dismiss();
                return Registry.ok("Dismissed");
            }
        });
        Registry.register({
            id: "notifications.action",
            title: "Run notification action",
            category: "shell",
            hidden: true,
            record: false,
            params: [
                {
                    name: "id",
                    type: "int",
                    min: 0,
                    required: true
                },
                {
                    name: "action",
                    type: "string",
                    required: true,
                    maxLength: 200
                }
            ],
            run: args => {
                const n = root.items.filter(x => x.id === args.id)[0];
                if (!n)
                    return Registry.fail("Notification is gone");
                if (!root.invokeAction(n, args.action))
                    return Registry.fail("The notification has no action " + args.action);
                return Registry.ok("Done");
            }
        });
        Registry.registerProvider({
            id: "notifications",
            kind: "notification",
            items: () => root.items.slice(0, 30).map(n => ({
                        id: String(n.id),
                        title: n.summary || n.appName,
                        subtitle: (n.appName ? n.appName + " · " : "") + (n.body || "").replace(/\s+/g, " ").slice(0, 120),
                        category: "shell",
                        keywords: ["notification", n.appName],
                        commandId: "notifications.dismiss",
                        args: {
                            id: n.id
                        }
                    }))
        });
    }
}
