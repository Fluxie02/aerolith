pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/launch.mjs" as Launch

// Application discovery (Quickshell's DesktopEntries, which follows the XDG
// desktop entry spec and tracks changes live) and launching.
Singleton {
    id: root

    readonly property var entries: DesktopEntries.applications.values
    readonly property bool ready: entries.length > 0
    property var terminal: []

    function find(id) {
        const e = DesktopEntries.byId(id);
        return e ? e : null;
    }

    function launch(entry) {
        const r = Launch.buildLaunchArgv({
            command: Array.from(entry.command || []),
            runInTerminal: entry.runInTerminal
        }, {
            terminal: Config.commandCore.terminal.length > 0 ? Config.commandCore.terminal : terminal,
            prefix: Config.commandCore.launchPrefix
        });
        if (r.error)
            return Registry.fail(entry.name + ": " + r.error);
        Quickshell.execDetached({
            command: r.argv,
            workingDirectory: entry.workingDirectory || Paths.home
        });
        Store.recordUse("apps:" + entry.id);
        // execDetached gives no feedback; report what was actually done.
        return Registry.ok("Started " + entry.name, {
            detail: r.argv.join(" ")
        });
    }

    // Find a terminal for Terminal=true entries when none is configured.
    Process {
        id: terminalProbe
        running: true
        command: ["sh", "-c", "for t in foot kitty alacritty wezterm ghostty konsole gnome-terminal xterm; do command -v \"$t\" >/dev/null 2>&1 && echo \"$t\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(s => s.length > 0);
                const t = Launch.detectTerminal(name => found.indexOf(name) !== -1);
                root.terminal = t ? t : [];
            }
        }
    }

    Component.onCompleted: {
        Registry.register({
            id: "app.launch",
            title: "Launch application",
            category: "apps",
            alias: "run",
            hidden: true,
            params: [
                {
                    name: "app",
                    type: "string",
                    required: true,
                    maxLength: 255,
                    description: "Desktop entry id, e.g. firefox.desktop or firefox"
                }
            ],
            routine: true,
            available: () => root.ready ? true : "Application index not ready",
            describe: args => {
                const e = root.find(args.app);
                return e ? e.name : args.app + " (not installed)";
            },
            run: args => {
                const e = root.find(args.app) || root.find(String(args.app).replace(/\.desktop$/, ""));
                if (!e)
                    return Registry.fail("No application with id " + args.app);
                return root.launch(e);
            }
        });

        Registry.registerProvider({
            id: "apps",
            kind: "app",
            items: () => {
                const list = root.entries;
                const out = [];
                for (let i = 0; i < list.length; i++) {
                    const e = list[i];
                    out.push({
                        id: e.id,
                        title: e.name,
                        subtitle: e.genericName || e.comment || "",
                        icon: e.icon,
                        keywords: Array.from(e.keywords || []).concat(Array.from(e.categories || [])),
                        category: "apps",
                        commandId: "app.launch",
                        args: {
                            app: e.id
                        }
                    });
                }
                return out;
            }
        });
    }
}
