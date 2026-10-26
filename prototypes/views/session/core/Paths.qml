pragma Singleton

import QtQuick
import Quickshell

// Filesystem locations. AEROLITH uses the XDG base directories directly
// (not Quickshell's per-shell-id folders) so the installer's ownership
// manifest can name every file it created.
Singleton {
    id: root

    function envOr(name, fallback) {
        const v = Quickshell.env(name);
        return v && String(v).length > 0 ? String(v) : fallback;
    }

    readonly property string home: envOr("HOME", "/tmp")
    readonly property string configHome: envOr("XDG_CONFIG_HOME", home + "/.config")
    readonly property string stateHome: envOr("XDG_STATE_HOME", home + "/.local/state")
    readonly property string runtimeDir: envOr("XDG_RUNTIME_DIR", "/tmp")

    // AEROLITH_CONFIG_DIR / AEROLITH_STATE_DIR let tests and the safe
    // development mode run against throwaway directories.
    readonly property string configDir: envOr("AEROLITH_CONFIG_DIR", configHome + "/aerolith")
    readonly property string stateDir: envOr("AEROLITH_STATE_DIR", stateHome + "/aerolith")

    readonly property string configFile: configDir + "/config.json"
    readonly property string routinesFile: configDir + "/routines.json"
    readonly property string aiConfigFile: configDir + "/ai.json"
    readonly property string stateFile: stateDir + "/state.json"

    readonly property string shellDir: Quickshell.shellDir
    // The optional AI Bridge installs its QML here. The core never imports
    // it statically; see modules/AiLoader.qml.
    readonly property string aiModuleEntry: shellDir + "/modules/ai/AiModule.qml"

    readonly property bool devMode: envOr("AEROLITH_DEV", "") === "1"
}
