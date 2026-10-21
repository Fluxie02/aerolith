pragma Singleton

import QtQuick
import Quickshell

// Shell-wide UI state: which bay is open, which display AEROLITH runs on,
// and transient notices.
//
// Single-display policy: AEROLITH creates its surfaces on exactly one
// output. With several outputs connected it picks one (config, else the
// first output Hyprland reports, else the first Qt screen), shows a caution
// annunciator and never duplicates itself onto other outputs.
Singleton {
    id: root

    // "" when closed, otherwise one of bays.
    property string activeBay: ""
    readonly property var bays: ["command", "navigator", "systems", "signal", "routines", "help", "ai"]
    readonly property bool deckOpen: activeBay !== ""
    // Text to pre-fill when opening the Command Core.
    property string pendingQuery: ""
    // Routine shown by the Routine Console.
    property string selectedRoutine: ""

    readonly property var screens: Quickshell.screens
    readonly property int screenCount: screens.length
    readonly property bool multipleDisplays: screenCount > 1
    readonly property var screen: pickScreen(screens, Config.display.output)
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool configuredOutputMissing: Config.display.output !== "" && screen !== null && screen.name !== Config.display.output

    function pickScreen(list, wanted) {
        if (!list || list.length === 0)
            return null;
        if (wanted)
            for (let i = 0; i < list.length; i++)
                if (list[i].name === wanted)
                    return list[i];
        // Hyprland's monitor list is ordered by id; prefer the lowest id.
        const order = outputOrder;
        for (let k = 0; k < order.length; k++)
            for (let i = 0; i < list.length; i++)
                if (list[i].name === order[k])
                    return list[i];
        return list[0];
    }

    // Filled by the Compositor service with Hyprland monitor names by id.
    property var outputOrder: []

    function open(bay) {
        if (bays.indexOf(bay) === -1)
            return false;
        activeBay = bay;
        return true;
    }

    function toggle(bay) {
        if (activeBay === bay)
            close();
        else
            open(bay);
    }

    function close() {
        activeBay = "";
        pendingQuery = "";
    }

    function openCommand(query) {
        pendingQuery = query || "";
        activeBay = "command";
    }

    // Transient notices shown in the toast column.
    property var notices: []
    property int noticeSeq: 0

    function notify(message, severity, detail) {
        const n = {
            id: ++noticeSeq,
            message: String(message),
            detail: detail ? String(detail) : "",
            severity: severity || "info",
            at: Date.now()
        };
        notices = notices.concat([n]).slice(-5);
        return n.id;
    }

    function dismiss(id) {
        notices = notices.filter(n => n.id !== id);
    }

    function report(result) {
        if (!result)
            return;
        notify(result.message, result.ok ? "ok" : "error", result.detail);
    }
}
