pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/launch.mjs" as Launch
import "../lib/tour.mjs" as TourLib
import "../lib/welcome.mjs" as WelcomeLib

// Small persistent runtime state (launch frecency, recent actions) in
// ~/.local/state/aerolith/state.json. Writes are debounced and atomic.
// Nothing here is configuration; deleting the file resets rankings and the tour.
Singleton {
    id: root

    property var usage: ({})
    property var recent: []
    property var tour: ({ completed: false, version: 0 })
    readonly property int recentLimit: Config.commandCore.historySize
    property var welcome: WelcomeLib.readRecord(null)
    // Snapshot of the state file BEFORE this shell wrote anything. Read errors
    // other than FileNotFound are upgrades too; never onboard over unreadable state.
    property bool hadState: true
    property bool ready: false

    function usageScore(key) {
        return Launch.usageScore(usage, key, Date.now());
    }

    function recordUse(key) {
        usage = Launch.recordUse(usage, key, Date.now(), 300);
        saveTimer.restart();
    }

    function recordAction(entry) {
        if (recentLimit <= 0)
            return;
        const list = [entry].concat(recent.filter(e => !(e.commandId === entry.commandId && JSON.stringify(e.args) === JSON.stringify(entry.args))));
        recent = list.slice(0, recentLimit);
        saveTimer.restart();
    }

    function clearRecent() {
        recent = [];
        saveTimer.restart();
    }

    function save() {
        file.setText(JSON.stringify({ version: 1, usage: usage, recent: recent, tour: tour, welcome: welcome }) + "\n");
    }

    function saveWelcome(record) {
        if (!ready) return;
        welcome = WelcomeLib.readRecord(record);
        saveTimer.stop();
        save();
    }

    function completeTour(version) {
        if (!ready) return;
        tour = { completed: true, version: version };
        // Completion must survive an immediate shell restart, without waiting
        // for the usage/history debounce. FileView still writes atomically.
        saveTimer.stop();
        save();
    }

    Timer {
        id: saveTimer
        interval: 2000
        onTriggered: root.save()
    }

    FileView {
        id: file
        path: Paths.stateFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.usage = d && typeof d.usage === "object" && d.usage !== null ? d.usage : {};
                root.recent = d && Array.isArray(d.recent) ? d.recent.slice(0, 1000) : [];
                root.tour = TourLib.readRecord(d && d.tour);
                root.welcome = WelcomeLib.readRecord(d && d.welcome);
            } catch (e) {
                Log.warn("state", "ignoring unreadable state file: " + e);
            }
            root.ready = true;
        }
        onLoadFailed: error => {
            root.hadState = error !== FileViewError.FileNotFound;
            root.ready = true;
        }
        onSaveFailed: error => Log.warn("state", "could not save state: " + error)
    }
}
