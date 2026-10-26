import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Loads the optional AI Bridge module if, and only if, it is installed.
//
// The core shell has no static reference to any AI code. The installer puts
// the module at <shell>/modules/ai/ only when the user picks Claude, Codex or
// Custom; with "None" the directory does not exist and nothing here does
// anything beyond one failed file probe at startup. Removing the AI
// integration deletes that directory; this loader then unloads the module
// and the registry drops every command it registered (source "ai").
Scope {
    id: root

    property bool installed: false
    readonly property Component bayComponent: loader.item && loader.item.bayComponent ? loader.item.bayComponent : null

    FileView {
        id: probe
        path: Paths.aiModuleEntry
        watchChanges: true
        printErrors: false
        preload: true
        onLoaded: root.installed = true
        onLoadFailed: root.installed = false
        onFileChanged: reload()
    }

    Loader {
        id: loader
        active: root.installed
        source: root.installed ? Paths.aiModuleEntry : ""
        onStatusChanged: {
            if (status === Loader.Error)
                Log.error("ai", "AI module failed to load; core shell unaffected");
            else if (status === Loader.Ready)
                Log.info("ai", "AI module loaded");
        }
    }

    onInstalledChanged: if (!installed) {
        const n = Registry.unregisterSource("ai");
        if (n > 0)
            Log.info("ai", "AI module removed; unregistered " + n + " commands");
    }
}
