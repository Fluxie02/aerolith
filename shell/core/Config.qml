pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/config.mjs" as ConfigLib

// Loads ~/.config/aerolith/config.json, validates it and exposes the result.
// The file is watched; edits apply live. AEROLITH never rewrites this file
// on its own: settings changed from the shell go through setValue(), which
// writes atomically and keeps unknown keys.
Singleton {
    id: root

    property var raw: ({})
    property var data: ConfigLib.defaultsOf(ConfigLib.SCHEMA)
    property var errors: []
    property var warnings: []
    property bool loaded: false
    property bool fileMissing: false
    property int revision: 0

    // Convenience accessors used across the shell.
    readonly property var display: data.display
    readonly property var theme: data.theme
    readonly property var strip: data.strip
    readonly property var commandCore: data.commandCore
    readonly property var telemetry: data.telemetry
    readonly property var audio: data.audio
    readonly property var navigator: data.navigator
    readonly property var routines: data.routines
    readonly property var notifications: data.notifications

    signal reloaded

    // The file on disk is not valid JSON (a typo, or an editor half-way
    // through saving). The last good settings stay in effect meanwhile.
    property bool fileBroken: false
    property bool hasGood: false

    function apply(text) {
        const r = ConfigLib.validateConfig(text);
        if (r.invalidJson === true && hasGood) {
            fileBroken = true;
            errors = [
                {
                    path: "(file)",
                    message: r.errors[0].message.replace(/; running with defaults$/, "") + "; keeping the previous settings until it is fixed"
                }
            ];
            warnings = [];
            revision++;
            Log.warn("config", errors[0].message);
            return;
        }
        fileBroken = r.invalidJson === true;
        if (!fileBroken)
            hasGood = true;
        data = r.config;
        errors = r.errors;
        warnings = r.warnings;
        try {
            raw = text && String(text).trim().length > 0 ? JSON.parse(text) : {};
        } catch (e) {
            raw = {};
        }
        loaded = true;
        revision++;
        Log.level = data.logging.level;
        for (let i = 0; i < errors.length; i++)
            Log.warn("config", errors[i].path + ": " + errors[i].message);
        for (let i = 0; i < warnings.length; i++)
            Log.info("config", warnings[i].path + ": " + warnings[i].message);
        reloaded();
    }

    // Validate and persist a single setting. Returns "" or an error message.
    function setValue(path, value) {
        // Never write over a file the user is in the middle of editing.
        if (fileBroken)
            return "the configuration file is not valid JSON; fix it before changing settings from the shell";
        if (Object.keys(raw).length === 0 && errors.length > 0)
            return "configuration file has errors; fix it before changing settings from the shell";
        const r = ConfigLib.setPath(raw, path, value);
        if (r.error)
            return r.error;
        file.setText(JSON.stringify(r.raw, null, 2) + "\n");
        return "";
    }

    function reload() {
        file.reload();
    }

    FileView {
        id: file
        path: Paths.configFile
        watchChanges: true
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            root.fileMissing = false;
            root.apply(text());
        }
        onLoadFailed: error => {
            // A missing file is normal: run on defaults.
            root.fileMissing = true;
            root.apply("");
        }
        onSaveFailed: error => Log.error("config", "could not save " + path + ": " + error)
    }
}
