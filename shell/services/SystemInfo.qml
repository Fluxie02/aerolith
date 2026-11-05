pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Singleton {
    id: root

    // Installation metadata describes the installed version, which may differ
    // from this process after an upgrade. Do not run doctor at startup.
    property var installedVersion: null
    property var hyprlandVersion: null
    readonly property var quickshellVersion: typeof Quickshell.version === "string" && Quickshell.version.trim() ? Quickshell.version : null

    FileView {
        path: Paths.manifestFile
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.installedVersion = null;
            try {
                const m = JSON.parse(text());
                if (m && !Array.isArray(m) && m.version === 1 && typeof m.aerolith_version === "string" && m.aerolith_version.trim())
                    root.installedVersion = m.aerolith_version;
            } catch (e) {} // Missing, corrupt or unsupported metadata is unavailable.
        }
        onLoadFailed: root.installedVersion = null
    }

    Component.onCompleted: {
        if (Compositor.available) {
            // hyprctl connects to the same instance socket as Compositor.
            // Direct argv, no shell, no polling and a bounded one-shot probe.
            Exec.run(["hyprctl", "-j", "version"], { timeoutMs: 3000 }).then(r => {
                try {
                    const v = r.code === 0 ? JSON.parse(r.stdout) : null;
                    if (v && typeof v.version === "string" && v.version.trim())
                        root.hyprlandVersion = v.version;
                } catch (e) {}
            });
        }
    }

    readonly property var version: ({ aerolith: installedVersion, quickshell: quickshellVersion, hyprland: hyprlandVersion })
}
