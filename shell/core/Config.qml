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

    // Installation-only metadata: never watched, written by setValue(), or
    // included in the schema that generates Settings. Read before first use.
    property bool installationMissing: false
    readonly property string applicationDirection: {
        const text = installation.text();
        return installationMissing ? "piyti" : readDirection(text);
    }

    function readDirection(text) {
        try {
            const data = JSON.parse(text);
            if (data && typeof data === "object" && !Array.isArray(data)) {
                if (data.direction === undefined)
                    return "piyti";
                if (data.direction === "piyti" || data.direction === "thears")
                    return data.direction;
            }
        } catch (e) {}
        Log.warn("config", "invalid installation direction in " + Paths.installationFile + "; using piyti");
        return "piyti";
    }

    FileView {
        id: installation
        path: Paths.installationFile
        watchChanges: false
        blockLoading: true
        printErrors: false
        onLoadFailed: root.installationMissing = true
    }

    // Convenience accessors used across the shell.
    readonly property var display: data.display
    readonly property var theme: data.theme
    readonly property var strip: data.strip
    readonly property var ground: data.ground
    readonly property var commandCore: data.commandCore
    readonly property var telemetry: data.telemetry
    readonly property var audio: data.audio
    readonly property var navigator: data.navigator
    readonly property var lock: data.lock
    readonly property var routines: data.routines
    readonly property var notifications: data.notifications

    signal reloaded
    signal saveFailed(string message)

    // The file on disk is not valid JSON (a typo, or an editor half-way
    // through saving). The last good settings stay in effect meanwhile.
    property bool fileBroken: false
    property bool hasGood: false
    // The text known to be on disk (last loaded or last saved), to go back
    // to when a save fails.
    property string diskText: ""

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

    // Serialize read -> rebase -> atomic write. reload() is asynchronous: only
    // the fresh reader's completion may produce the replacement text.
    property var saves: []
    property string savePhase: ""
    property string writeText: ""
    property bool reloadPending: false
    property bool freshStarted: false

    // Returns an immediate validation error, or accepts a queued save. Disk
    // conflicts/read/write failures are reported through saveFailed.
    function setValue(path, value) {
        let projected = raw;
        for (const pending of saves) {
            const prior = ConfigLib.setPath(projected, pending.path, pending.value);
            if (!prior.error) projected = prior.raw;
        }
        const r = ConfigLib.setPath(projected, path, value);
        if (r.error) return r.error;
        saves = saves.concat([{ path: path, value: value,
            expected: ConfigLib.getPath(projected, path) }]);
        Qt.callLater(root.saveNext);
        return "";
    }

    function saveNext() {
        if (savePhase || !saves.length) return;
        savePhase = "reading";
        if (!freshStarted) {
            // Start the first load only after a request, so no startup read
            // can be mistaken for the requested fresh read.
            freshStarted = true;
            fresh.preload = true;
        } else fresh.reload();
    }

    function readForSave(text) {
        if (savePhase !== "reading") return;
        const request = saves[0];
        const r = ConfigLib.mergeChange(text, request.path, request.value, request.expected);
        // Adopt external edits even when this request conflicts or is invalid.
        diskText = text;
        apply(text);
        if (r.error) { finishSave(r.error); return; }
        writeText = JSON.stringify(r.raw, null, 2) + "\n";
        if (writeText === text) { finishSave(""); return; }
        savePhase = "writing";
        // Leave FileView's load-completion handler before starting its write.
        Qt.callLater(root.writeSave);
    }

    function writeSave() {
        fresh.setText(writeText);
    }

    function finishSave(message) {
        saves = saves.slice(1);
        savePhase = "";
        if (message) {
            Log.warn("config", message);
            saveFailed(message);
        }
        if (saves.length) Qt.callLater(root.saveNext);
        else if (reloadPending) { reloadPending = false; file.reload(); }
    }

    FileView {
        id: fresh
        path: Paths.configFile
        preload: false
        blockLoading: false
        printErrors: false
        atomicWrites: true
        // Only successful commits update effective settings and diskText.
        onSaveFailed: error => {
            Log.error("config", "could not save " + path + ": " + error);
            root.reloadPending = true;
            root.finishSave("Could not write " + path + " (" + error + "); settings were not saved.");
        }
        onSaved: {
            root.fileMissing = false;
            root.diskText = root.writeText;
            root.apply(root.diskText);
            root.finishSave("");
        }
        onLoaded: root.readForSave(text())
        onLoadFailed: error => {
            if (root.savePhase !== "reading") return;
            if (error === FileViewError.FileNotFound) root.readForSave("");
            else root.finishSave("Could not read " + path + " (" + FileViewError.toString(error) + "); settings were not saved.");
        }
    }

    function reload() {
        if (savePhase) reloadPending = true;
        else file.reload();
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
            if (root.savePhase) { root.reloadPending = true; return; }
            root.fileMissing = false;
            root.diskText = text();
            root.apply(root.diskText);
        }
        onLoadFailed: error => {
            if (root.savePhase) { root.reloadPending = true; return; }
            if (error !== FileViewError.FileNotFound) {
                root.saveFailed("Could not read " + path + " (" + FileViewError.toString(error) + ")");
                return;
            }
            // A missing file is normal: run on defaults.
            root.fileMissing = true;
            root.diskText = "";
            root.apply("");
        }
    }
}
