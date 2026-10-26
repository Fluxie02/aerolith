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
        // Lock the session with AEROLITH's lock screen (lock.enabled); for
        // hypridle: lock_cmd = qs -p <shell> ipc call aerolith lock
        function lock(): string {
            return Registry.get("session.lock") ? (Registry.execute("session.lock", {}, { origin: "ipc" }), "started") : "error: no lock command";
        }
        // Session menu: lock, suspend, log out, reboot, power off.
        function session(): void {
            Ui.sessionOpen = true;
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
            }).then(r => Log.info("ipc", command + ": " + (r.ok ? "ok: " : "failed: ") + r.message));
            return "started";
        }
        function status(): string {
            return JSON.stringify({
                display: Ui.screenName,
                displays: Ui.screenCount,
                hyprland: Compositor.available,
                dialect: Compositor.dialect,
                focusedWorkspace: Compositor.focusedWorkspaceId,
                activeWindow: Compositor.activeTitle,
                toplevels: Compositor.available ? Compositor.windows().map(w => w.address) : [],
                pipewire: Audio.ready,
                players: Media.players.length,
                commands: Registry.api.size(),
                configErrors: Config.errors.length,
                configFileBroken: Config.fileBroken,
                direction: Theme.applicationDirection,
                theme: ({ intensity: Theme.intensity, scheme: Theme.scheme }),
                stripEdge: Config.strip.edge,
                routineErrors: Routines.errors.length,
                ai: Registry.get("ai.ask") !== null,
                telemetryIntervalMs: Telemetry.interval,
                telemetrySamples: Telemetry.samplesTaken,
                cpuPercent: Telemetry.cpu.total,
                memoryPercent: Telemetry.memory ? Telemetry.memory.percent : null,
                monitor: Compositor.monitorGeometry(),
                bay: Ui.activeBay,
                query: Ui.pendingQuery,
                deckMapped: Ui.deckMapped,
                deckMaps: Ui.deckMaps,
                audioDetail: Audio.detailDemand,
                notices: Ui.notices.length,
                popups: Notifications.popups.length,
                ground: Config.ground.enabled,
                motion: Config.theme.motion,
                phase: ShellState.phase,
                fullscreen: ShellState.fullscreen,
                fullscreenOwner: ShellState.ownerClass,
                surfacesReleased: ShellState.surfacesReleased,
                ambient: Theme.ambient,
                osd: Ui.osdKind,
                session: Ui.sessionOpen,
                locked: Ui.locked,
                lockSecure: Ui.lockSecure,
                lockState: Ui.lockState,
                lockAttempts: Ui.lockAttempts,
                osdValue: isFinite(Ui.osdValue) ? Math.round(Ui.osdValue * 100) / 100 : null,
                brightness: Brightness.available ? Brightness.percent : null
            });
        }
        // Diagnostics: how PipeWire nodes are classified (no volumes or
        // stream contents beyond names).
        function audio(): string {
            return JSON.stringify(Audio.nodes.map(n => ({
                        id: n.id,
                        name: n.name,
                        isSink: n.isSink,
                        isStream: n.isStream,
                        audio: n.audio !== null,
                        type: String(n.type)
                    })));
        }
        function reload(): void {
            Config.reload();
        }
        // The command catalogue as JSON (ids, aliases, typed parameters,
        // flags). Used by tools/gen-commands-doc.py and scripts.
        function commands(): string {
            return JSON.stringify(Registry.api.list().map(c => ({
                        id: c.id,
                        alias: c.alias || null,
                        title: c.title,
                        category: c.category,
                        description: c.description || "",
                        source: c.source,
                        sensitive: c.sensitive === true,
                        routine: c.routine === true,
                        aiAllowed: c.aiAllowed !== false && c.sensitive !== true,
                        params: c.params.map(p => ({
                                    name: p.name,
                                    type: p.type,
                                    required: p.required === true,
                                    default: p.default === undefined ? null : p.default,
                                    min: p.min === undefined ? null : p.min,
                                    max: p.max === undefined ? null : p.max,
                                    choices: Array.isArray(p.choices) ? p.choices.map(ch => (ch && typeof ch === "object" && "value" in ch) ? ch.value : ch) : (typeof p.choices === "function" ? "dynamic" : null),
                                    description: p.description || ""
                                }))
                    })));
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
                name: "session"
                description: "AEROLITH: session menu"
                onPressed: Ui.sessionOpen = !Ui.sessionOpen
            }
            AeroShortcut {
                name: "brightness-up"
                description: "AEROLITH: brightness up"
                onPressed: Registry.execute("brightness.up", {}, {
                    record: false
                })
            }
            AeroShortcut {
                name: "brightness-down"
                description: "AEROLITH: brightness down"
                onPressed: Registry.execute("brightness.down", {}, {
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
