import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services
import "../command"
import "../navigator"
import "../systems"
import "../signal"
import "../routines"
import "../help"
import "../settings"

// The Deck: one overlay surface that hosts whichever bay is open (Command
// Core, Spatial Navigator, Systems Bay, Signal Rack, Routine Console, Help,
// and the optional AI console). DeckView draws it; this file owns the
// surface, keyboard handling and bay lifetimes.
//
// Ui.activeBay is the requested bay. Exactly one bay is live at a time, but
// a bay that is closed or replaced keeps its pixels for at most `exitMs` so
// DeckView can animate it out. Everything else ends the moment a bay stops
// being requested: its `active` property goes false (bays release telemetry
// and audio demand on that), it loses keyboard focus, and a closed Deck lets
// pointer input through and gives up keyboard focus, so Hyprland returns
// focus to the previously focused window at once. Bays are created fresh on
// every open.
PanelWindow {
    id: deck

    property Component aiBay: null

    // How long an outgoing bay may stay on screen; 0 when motion is off or
    // effects are reduced, which unmaps and destroys at once.
    readonly property int exitMs: Theme.animate && !Theme.lowEffects ? Theme.normal : 0
    // True while a closed Deck still shows an outgoing bay. (Slot state
    // first, so the binding always depends on it.)
    readonly property bool exiting: (slotA.leaving || slotB.leaving) && !Ui.deckOpen
    // Whether the surface stays mapped. Written only at the end of sync()
    // and release(), never by a binding: a binding could see the request
    // gone before the outgoing slot is marked leaving, unmap for one turn
    // and remap, and a remap is a new layer surface (compositor close and
    // open animations).
    property bool holdSurface: false
    readonly property alias slotA: slotA
    readonly property alias slotB: slotB

    // Rail order doubles as the Ctrl+1..6 key map.
    readonly property var rail: [
        {
            bay: "command",
            key: "1"
        },
        {
            bay: "navigator",
            key: "2"
        },
        {
            bay: "systems",
            key: "3"
        },
        {
            bay: "signal",
            key: "4"
        },
        {
            bay: "routines",
            key: "5"
        },
        {
            bay: "ai",
            key: "6"
        },
        {
            bay: "help",
            key: "F1"
        },
        {
            bay: "settings",
            key: "7"
        }
    ]

    readonly property string wanted: Ui.deckOpen && Ui.screen !== null ? Ui.activeBay : ""

    screen: Ui.screen
    visible: holdSurface && Ui.screen !== null
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aerolith-deck"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Ui.deckOpen && visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // An exiting Deck must not catch clicks meant for the windows below.
    mask: Ui.deckOpen ? null : noInput

    Region {
        id: noInput
    }

    onVisibleChanged: {
        Ui.deckMapped = visible;
        if (visible)
            Ui.deckMaps++;
    }
    // shell.qml unloads the Deck while a fullscreen window owns the output;
    // a destroyed Deck is not mapped.
    Component.onDestruction: Ui.deckMapped = false
    // The compositor closed the surface (e.g. its output went away): treat
    // it as closed, so no bay keeps its demand without being seen.
    onClosed: Ui.close()
    onWantedChanged: sync()
    onAiBayChanged: sync()
    Component.onCompleted: sync()

    function componentFor(bay) {
        switch (bay) {
        case "command":
            return commandBay;
        case "navigator":
            return navigatorBay;
        case "systems":
            return systemsBay;
        case "signal":
            return signalBay;
        case "routines":
            return routinesBay;
        case "help":
            return helpBay;
        case "settings":
            return settingsBay;
        case "ai":
            return aiBay !== null ? aiBay : view.missingAiBay;
        }
        return null;
    }

    // Bring the slots in line with the requested bay. Two slots alternate so
    // an outgoing bay can finish its exit while the incoming one is live; a
    // third change during that time cuts the oldest exit short.
    function updateHold() {
        holdSurface = wanted !== "" || slotA.leaving || slotB.leaving;
    }

    function sync() {
        syncSlots();
        updateHold();
    }

    function syncSlots() {
        const comp = wanted !== "" ? componentFor(wanted) : null;
        const cur = slotA.current ? slotA : slotB.current ? slotB : null;
        if (cur && cur.bay === wanted && cur.sourceComponent === comp)
            return;
        if (cur)
            cur.retire();
        if (comp === null)
            return;
        let free = slotA.bay === "" ? slotA : slotB.bay === "" ? slotB : null;
        if (free === null) {
            free = slotA.retiredAt <= slotB.retiredAt ? slotA : slotB;
            free.release();
        }
        free.present(wanted, comp);
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.AfterItem
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Ui.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_F1) {
                Ui.toggle("help");
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_7) {
                const n = event.key - Qt.Key_1;
                // Rail entries 0-5 are Ctrl+1..6; Help (F1) sits between them and Settings (Ctrl+7).
                const target = n < 6 ? deck.rail[n].bay : "settings";
                if (target !== "ai" || deck.aiBay !== null)
                    Ui.open(target);
                event.accepted = true;
            }
        }

        DeckView {
            id: view
            anchors.fill: parent
            deck: deck
        }

        BaySlot {
            id: slotA
            parent: view.frameA
        }
        BaySlot {
            id: slotB
            parent: view.frameB
        }
    }

    component BaySlot: Loader {
        id: slot

        // Bay id shown by this slot; "" when empty.
        property string bay: ""
        // True while this slot shows the requested bay.
        property bool current: false
        // True while an outgoing bay finishes its exit.
        property bool leaving: false
        property real retiredAt: 0

        anchors.fill: parent
        active: bay !== ""
        visible: active
        // An outgoing bay may sit above the incoming one during a switch;
        // it must not take pointer input or focus meanwhile.
        enabled: current

        function present(name, comp) {
            exitTimer.stop();
            leaving = false;
            current = true;
            sourceComponent = comp;
            bay = name;
        }

        // Stop being the requested bay: demand and focus go now, pixels
        // stay for at most exitMs.
        function retire() {
            current = false;
            if (item) {
                if (item.active !== undefined)
                    item.active = false;
                item.focus = false;
            }
            if (deck.exitMs > 0 && item) {
                leaving = true;
                retiredAt = Date.now();
                exitTimer.interval = deck.exitMs;
                exitTimer.restart();
            } else {
                release();
            }
        }

        function release() {
            exitTimer.stop();
            leaving = false;
            current = false;
            bay = "";
            sourceComponent = null;
            deck.updateHold();
        }

        onLoaded: {
            if (current)
                item.forceActiveFocus();
        }

        Timer {
            id: exitTimer
            onTriggered: slot.release()
        }
    }

    Component {
        id: commandBay
        CommandCore {}
    }
    Component {
        id: navigatorBay
        SpatialNavigator {}
    }
    Component {
        id: systemsBay
        SystemsBay {}
    }
    Component {
        id: signalBay
        SignalRack {}
    }
    Component {
        id: routinesBay
        RoutineConsole {}
    }
    Component {
        id: helpBay
        HelpBay {}
    }
    Component {
        id: settingsBay
        SettingsBay {}
    }
}
