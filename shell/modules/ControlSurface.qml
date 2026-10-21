import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core
import qs.services

// External control: `qs ipc` handlers (any compositor) and Hyprland global
// shortcuts. Keys are bound in Hyprland's config to the shortcut names below,
// e.g. Lua: hl.bind("SUPER + SPACE", hl.dsp.global("aerolith:command")).
Scope {
    id: root

    IpcHandler {
        target: "aerolith"

        function open(bay: string): string {
            return Ui.open(bay) ? "ok" : "unknown bay: " + bay;
        }
        function toggle(bay: string): string {
            if (Ui.bays.indexOf(bay) === -1)
                return "unknown bay: " + bay;
            Ui.toggle(bay);
            return "ok";
        }
        function close(): void {
            Ui.close();
        }
        // Run a command by id with JSON arguments. Sensitive commands are
        // not executed from IPC; they open the Command Core for confirmation.
        function run(command: string, argsJson: string): string {
            let args = {};
            if (argsJson && argsJson.trim() !== "") {
                try {
                    args = JSON.parse(argsJson);
                } catch (e) {
                    return "error: arguments are not valid JSON";
                }
            }
            const cmd = Registry.get(command);
            if (!cmd)
                return "error: unknown command " + command;
            if (cmd.sensitive === true) {
                Ui.openCommand(cmd.alias ? cmd.alias : "> " + cmd.title);
                return "needs confirmation in the Command Core";
            }
            Registry.run(command, args, {
                origin: "ipc"
            });
            return "started";
        }
        function status(): string {
            return JSON.stringify({
                display: Ui.screenName,
                displays: Ui.screenCount,
                hyprland: Compositor.available,
                dialect: Compositor.dialect,
                pipewire: Audio.ready,
                players: Media.players.length,
                commands: Registry.api.size(),
                configErrors: Config.errors.length,
                routineErrors: Routines.errors.length,
                ai: Registry.get("ai.ask") !== null,
                telemetryIntervalMs: Telemetry.interval
            });
        }
        function reload(): void {
            Config.reload();
        }
    }

    // Global shortcuts exist only on Hyprland (hyprland_global_shortcuts_v1).
    LazyLoader {
        active: Compositor.available
        Scope {
            AeroShortcut {
                name: "command"
                description: "AEROLITH: Command Core"
                onPressed: Ui.toggle("command")
            }
            AeroShortcut {
                name: "navigator"
                description: "AEROLITH: Spatial Navigator"
                onPressed: Ui.toggle("navigator")
            }
            AeroShortcut {
                name: "systems"
                description: "AEROLITH: Systems Bay"
                onPressed: Ui.toggle("systems")
            }
            AeroShortcut {
                name: "signal"
                description: "AEROLITH: Signal Rack"
                onPressed: Ui.toggle("signal")
            }
            AeroShortcut {
                name: "routines"
                description: "AEROLITH: Routine Console"
                onPressed: Ui.toggle("routines")
            }
            AeroShortcut {
                name: "volume-up"
                description: "AEROLITH: volume up"
                onPressed: Registry.execute("audio.volume.up", {}, {
                    record: false
                })
            }
            AeroShortcut {
                name: "volume-down"
                description: "AEROLITH: volume down"
                onPressed: Registry.execute("audio.volume.down", {}, {
                    record: false
                })
            }
            AeroShortcut {
                name: "mute"
                description: "AEROLITH: toggle mute"
                onPressed: Registry.execute("audio.mute.toggle", {}, {
                    record: false
                })
            }
            AeroShortcut {
                name: "play-pause"
                description: "AEROLITH: play/pause"
                onPressed: Registry.execute("media.play-pause", {}, {
                    record: false
                })
            }
        }
    }

    component AeroShortcut: GlobalShortcut {
        appid: "aerolith"
    }
}
