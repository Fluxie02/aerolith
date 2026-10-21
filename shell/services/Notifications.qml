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
                root.items = [n].concat(root.items).slice(0, 100);
                if (!root.doNotDisturb && n.urgency !== NotificationUrgency.Low)
                    root.popups = root.popups.concat([n]).slice(-3);
                n.closed.connect(() => {
                    root.items = root.items.filter(x => x !== n);
                    root.popups = root.popups.filter(x => x !== n);
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
        }
    }

    function dropPopup(n) {
        popups = popups.filter(x => x !== n);
    }

    function clearAll() {
        const list = items.slice();
        for (let i = 0; i < list.length; i++)
            list[i].dismiss();
        items = [];
        popups = [];
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
