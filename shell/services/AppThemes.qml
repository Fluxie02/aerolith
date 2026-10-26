pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Payload refresh is independent of all visual surfaces and never polls.
Singleton {
    id: root

    property bool ready: false
    property bool busy: false
    property string observed: ""
    property string pending: ""
    property string handled: ""

    function observe() {
        if (!Config.loaded || Config.fileBroken)
            return;
        // setValue applies before its asynchronous save finishes. Only
        // observe a scheme once Config's last-known disk text agrees with it.
        let saved;
        try { saved = JSON.parse(Config.diskText || "{}"); }
        catch (e) { return; }
        const scheme = saved && saved.theme && typeof saved.theme.scheme === "string" ? saved.theme.scheme : "limb";
        if (scheme !== Config.theme.scheme)
            return;
        if (!ready) {
            ready = true;
            observed = handled = scheme;
            return;
        }
        if (scheme === observed)
            return;
        observed = scheme;
        pending = scheme;
        debounce.stop();
        if (!ShellState.surfacesReleased && !busy)
            debounce.restart();
    }

    function refresh() {
        if (busy || ShellState.surfacesReleased || !pending)
            return;
        if (pending === handled) {
            pending = "";
            return;
        }
        busy = true;
        // A fixed shell expression only discovers the CLI; user data is never
        // interpolated into shell source. Missing CLI is intentionally silent.
        Exec.run(["sh", "-c", "command -v aerolith"], {timeoutMs: 1000}).then(probe => {
            if (probe.code !== 0 || !probe.stdout.trim() || ShellState.surfacesReleased)
                return null;
            const scheme = pending;
            pending = "";
            handled = scheme;
            return Exec.run([probe.stdout.trim(), "themes", "refresh", "--json"], {timeoutMs: 12000});
        }).then(result => {
            busy = false;
            if (result) {
                try {
                    const report = JSON.parse(result.stdout);
                    const apps = report.apps || [];
                    if (apps.length) {
                        const failed = apps.filter(a => a.status === "error").length;
                        const updated = apps.filter(a => a.status === "refreshed").length;
                        Ui.notify("App themes: " + updated + " refreshed" + (failed ? ", " + failed + " kept with errors" : ""), failed ? "caution" : "info", apps.map(a => a.app + ": " + (a.error || a.activation || a.status)).join("\n"));
                    } else if (report.error) {
                        Log.warn("app-themes", report.error);
                    }
                } catch (e) {
                    Log.warn("app-themes", "refresh failed: " + (result.stderr || "invalid JSON response"));
                }
            } else if (!ShellState.surfacesReleased) {
                handled = pending;
                pending = "";
            }
            if (pending && !ShellState.surfacesReleased)
                debounce.restart();
        });
    }

    Connections {
        target: Config
        function onReloaded() { root.observe(); }
        function onDiskTextChanged() { root.observe(); }
    }
    Connections {
        target: ShellState
        function onSurfacesReleasedChanged() {
            if (ShellState.surfacesReleased)
                debounce.stop();
            else if (root.pending && !root.busy)
                debounce.restart();
        }
    }
    Timer {
        id: debounce
        interval: 1500
        onTriggered: root.refresh()
    }
    Component.onCompleted: observe()
}
