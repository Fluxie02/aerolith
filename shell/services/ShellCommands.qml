pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Commands that act on the shell itself: opening bays, reloading, settings.
Singleton {
    id: root

    function openBay(bay, title) {
        return () => {
            Ui.open(bay);
            return Registry.ok(title);
        };
    }

    function setting(path, value, label) {
        const err = Config.setValue(path, value);
        return err ? Registry.fail(err) : Registry.ok(label + " (saved to config.json)");
    }

    Component.onCompleted: {
        const bays = [["navigator", "Spatial Navigator", "nav", ["overview", "windows", "expose"]], ["systems", "Systems Bay", "sys", ["telemetry", "cpu", "memory", "gpu", "monitor"]], ["signal", "Signal Rack", "sig", ["audio", "media", "mixer", "devices"]], ["routines", "Routine Console", "", ["routine", "automation"]], ["help", "Help and shortcuts", "help", ["keys", "keyboard", "shortcuts", "commands"]], ["settings", "Settings", "set", ["settings", "preferences", "configuration", "options"]]];
        for (let i = 0; i < bays.length; i++) {
            const b = bays[i];
            const def = {
                id: "shell.open." + b[0],
                title: "Open " + b[1],
                category: "shell",
                keywords: b[3],
                featured: true,
                record: false,
                run: openBay(b[0], b[1])
            };
            if (b[2] !== "")
                def.alias = b[2];
            Registry.register(def);
        }
        Registry.register({
            id: "shell.reload-config",
            title: "Reload configuration",
            category: "settings",
            keywords: ["config", "reload", "settings"],
            run: () => {
                Config.reload();
                return Registry.ok("Configuration reloaded" + (Config.errors.length ? " with " + Config.errors.length + " problem(s)" : ""));
            }
        });
        Registry.register({
            id: "settings.strip.edge",
            title: "Move Flight Strip",
            category: "settings",
            alias: "edge",
            keywords: ["strip", "bar", "top", "bottom", "position"],
            params: [
                {
                    name: "edge",
                    type: "enum",
                    required: true,
                    choices: ["top", "bottom"]
                }
            ],
            run: args => root.setting("strip.edge", args.edge, "Flight Strip moved to " + args.edge)
        });
        Registry.register({
            id: "settings.density",
            title: "Set interface density",
            category: "settings",
            alias: "density",
            keywords: ["compact", "comfortable", "size", "spacing"],
            params: [
                {
                    name: "density",
                    type: "enum",
                    required: true,
                    choices: ["compact", "standard", "comfortable"]
                }
            ],
            run: args => root.setting("theme.density", args.density, "Density " + args.density)
        });
        Registry.register({
            id: "settings.motion",
            title: "Set motion level",
            category: "settings",
            alias: "motion",
            keywords: ["animation", "reduced", "accessibility"],
            params: [
                {
                    name: "motion",
                    type: "enum",
                    required: true,
                    choices: ["full", "reduced", "off"]
                }
            ],
            run: args => root.setting("theme.motion", args.motion, "Motion " + args.motion)
        });
        Registry.register({
            id: "settings.intensity",
            title: "Set interface intensity",
            category: "settings",
            alias: "intensity",
            keywords: ["saturated", "insane", "density", "appearance"],
            params: [
                {
                    name: "intensity",
                    type: "enum",
                    required: true,
                    choices: ["saturated", "insane"]
                }
            ],
            run: args => root.setting("theme.intensity", args.intensity, "Intensity " + args.intensity)
        });
        Registry.register({
            id: "settings.low-effects",
            title: "Toggle low-effects mode",
            category: "settings",
            keywords: ["performance", "opaque", "effects", "recording"],
            run: () => root.setting("theme.lowEffects", !Config.theme.lowEffects, "Low-effects " + (!Config.theme.lowEffects ? "on" : "off"))
        });
        Registry.register({
            id: "settings.strip.telemetry",
            title: "Set Flight Strip telemetry",
            category: "settings",
            keywords: ["cpu", "memory", "strip", "readout"],
            alias: "readouts",
            params: [
                {
                    name: "mode",
                    type: "enum",
                    required: true,
                    choices: ["off", "alert", "always"]
                }
            ],
            run: args => root.setting("strip.telemetry", args.mode, "Strip telemetry " + args.mode)
        });
        Registry.register({
            id: "shell.history.clear",
            title: "Clear action history",
            category: "shell",
            keywords: ["history", "recent", "privacy"],
            record: false,
            run: () => {
                Store.clearRecent();
                Registry.api.clearHistory();
                return Registry.ok("History cleared");
            }
        });
    }
}
