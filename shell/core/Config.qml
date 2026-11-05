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
    // raw is committed only. Queued immediate edits have a separate projection
    // for stepping controls; only the explicit appearance draft reaches data.
    readonly property var committedData: ConfigLib.previewData(raw, null)
    readonly property var data: ConfigLib.previewData(raw, preview)
    readonly property var projectedData: ConfigLib.previewData(projectedRaw(), preview)
    property var preview: null
    readonly property bool previewActive: preview !== null
    readonly property bool previewDirty: previewActive && preview.changes.length > 0
    readonly property var previewConflicts: previewActive ? ConfigLib.conflictsFor(raw, preview.changes) : []
    property string previewError: ""
    property bool previewApplying: false
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

    signal committedChanged
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
        const previousRaw = JSON.stringify(raw);
        errors = r.errors;
        warnings = r.warnings;
        try {
            raw = text && String(text).trim().length > 0 ? JSON.parse(text) : {};
        } catch (e) {
            raw = {};
        }
        loaded = true;
        revision++;
        Log.level = committedData.logging.level;
        for (let i = 0; i < errors.length; i++)
            Log.warn("config", errors[i].path + ": " + errors[i].message);
        for (let i = 0; i < warnings.length; i++)
            Log.info("config", warnings[i].path + ": " + warnings[i].message);
        if (JSON.stringify(raw) !== previousRaw || revision === 1)
            committedChanged();
        reloaded();
    }

    // Serialize read -> rebase -> atomic write. reload() is asynchronous: only
    // the fresh reader's completion may produce the replacement text.
    property var saves: []
    property string savePhase: ""
    property string writeText: ""
    property bool reloadPending: false
    property bool freshStarted: false

    function projectedRaw() {
        let projected = raw;
        for (const pending of saves) {
            if (!pending.cancelled)
                projected = ConfigLib.overlay(projected, pending.changes);
        }
        return projected;
    }

    // Returns a validation error, or accepts ONE batch in the serialized queue.
    // Async conflicts/read/write failures are reported through saveFailed.
    function setValues(values) {
        if (previewActive || previewApplying) return "Apply or cancel the preview before saving settings";
        const r = ConfigLib.prepareBatch(projectedRaw(), values);
        if (r.error) return r.error;
        if (!r.changes.length) return "";
        saves = saves.concat([{ changes: r.changes, isPreview: false, cancelled: false }]);
        Qt.callLater(root.saveNext);
        return "";
    }

    function setValue(path, value) {
        return setValues([{path: path, value: value}]);
    }

    function beginPreview() {
        if (previewActive) return "A preview is already active";
        if (!loaded) return "Wait for configuration to load";
        if (saves.length || savePhase) return "Wait for pending settings to finish saving";
        if (fileBroken) return "Fix the configuration file before previewing settings";
        previewError = "";
        preview = ConfigLib.beginPreview(raw);
        return "";
    }

    function setPreviewValues(values) {
        if (previewApplying) return "Wait for Apply to finish";
        const r = ConfigLib.setPreviewValues(preview, values);
        previewError = r.error || "";
        if (r.error) return r.error;
        preview = r.preview;
        return "";
    }

    function applyPreview() {
        if (!previewActive) return "No preview is active";
        if (previewApplying) return "Wait for Apply to finish";
        if (!previewDirty) { cancelPreview(); return ""; }
        previewError = "";
        previewApplying = true;
        saves = saves.concat([{changes: preview.changes, isPreview: true, cancelled: false}]);
        Qt.callLater(root.saveNext);
        return "";
    }

    function cancelPreview() {
        // Invalidate even an Apply waiting for its fresh read/write callback.
        // Once setText has submitted an authorized atomic commit it may finish.
        for (const request of saves) {
            if (request.isPreview) request.cancelled = true;
        }
        preview = null;
        previewError = "";
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
        if (request.cancelled) { finishSave(""); return; }
        const r = ConfigLib.mergeChanges(text, request.changes);
        // Adopt external edits even when this request conflicts or is invalid.
        diskText = text;
        apply(text);
        if (r.error) { finishSave(r.error); return; }
        writeText = JSON.stringify(r.raw, null, 2) + "\n";
        if (writeText === text) {
            if (request.isPreview) preview = null;
            finishSave("");
            return;
        }
        savePhase = "writing";
        // Leave FileView's load-completion handler before starting its write.
        Qt.callLater(root.writeSave);
    }

    function writeSave() {
        if (saves[0].cancelled) { finishSave(""); return; }
        fresh.setText(writeText);
    }

    function finishSave(message) {
        if (saves.length && saves[0].isPreview) {
            previewApplying = false;
            if (previewActive) previewError = message;
        }
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
            if (root.saves[0].isPreview) root.preview = null;
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
