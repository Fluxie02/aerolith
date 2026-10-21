import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services
import "../command"
import "../navigator"
import "../systems"
import "../signal"
import "../routines"
import "../help"

// The Deck: one overlay surface that hosts whichever bay is open (Command
// Core, Spatial Navigator, Systems Bay, Signal Rack, Routine Console, Help,
// and the optional AI console). Exactly one bay is live at a time; closing
// the Deck unloads it, so hidden bays cost nothing.
//
// While open the Deck takes exclusive keyboard focus. Closing it unmaps the
// surface and Hyprland returns focus to the previously focused window.
PanelWindow {
    id: deck

    property Component aiBay: null

    screen: Ui.screen
    visible: Ui.deckOpen && Ui.screen !== null
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
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var rail: [
        {
            bay: "command",
            code: "CMD",
            key: "1"
        },
        {
            bay: "navigator",
            code: "NAV",
            key: "2"
        },
        {
            bay: "systems",
            code: "SYS",
            key: "3"
        },
        {
            bay: "signal",
            code: "SIG",
            key: "4"
        },
        {
            bay: "routines",
            code: "RTN",
            key: "5"
        },
        {
            bay: "ai",
            code: "AI",
            key: "6"
        },
        {
            bay: "help",
            code: "HELP",
            key: "F1"
        }
    ]

    // Backdrop: dims the desktop; clicking it closes the Deck.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: Theme.backdropOpacity
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.close()
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
            } else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                const target = deck.rail[event.key - Qt.Key_1].bay;
                if (target !== "ai" || deck.aiBay !== null)
                    Ui.open(target);
                event.accepted = true;
            }
        }

        // Bay rail
        Row {
            id: railRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: (Config.strip.edge === "top" ? Theme.stripHeight : 0) + Theme.pad
            spacing: Theme.px(2)
            Repeater {
                model: deck.rail.filter(r => r.bay !== "ai" || deck.aiBay !== null)
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool current: Ui.activeBay === modelData.bay
                    width: tabRow.implicitWidth + Theme.pad * 2
                    height: Math.round(Theme.rowHeight * 0.8)
                    color: current ? Theme.surface : Theme.alpha(Theme.surface, 0.6)
                    border.color: current ? Theme.signal : Theme.grid
                    border.width: Theme.border
                    radius: Theme.radius
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: Theme.px(6)
                        Text {
                            text: modelData.key === "F1" ? "F1" : "^" + modelData.key
                            color: Theme.textDim
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                        }
                        Text {
                            text: modelData.code
                            color: parent.parent.current ? Theme.signal : Theme.text
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.open(modelData.bay)
                    }
                }
            }
        }

        Loader {
            id: bayLoader
            anchors.fill: parent
            anchors.topMargin: railRow.y + railRow.height + Theme.pad
            anchors.bottomMargin: (Config.strip.edge === "bottom" ? Theme.stripHeight : 0) + Theme.pad * 2
            active: deck.visible
            focus: true
            sourceComponent: {
                switch (Ui.activeBay) {
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
                case "ai":
                    return deck.aiBay !== null ? deck.aiBay : missingAiBay;
                }
                return null;
            }
            onLoaded: item.forceActiveFocus()
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
        id: missingAiBay
        FocusScope {
            Bezel {
                anchors.centerIn: parent
                width: Math.min(Theme.px(560), parent.width)
                height: Theme.px(150)
                designation: "AI-00"
                title: "AI Bridge not installed"
                active: false
                MouseArea {
                    anchors.fill: parent
                }
                Text {
                    anchors.fill: parent
                    wrapMode: Text.WordWrap
                    color: Theme.textDim
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    text: "AEROLITH is running without AI integration. Everything else works normally. To add a provider later, run: aerolith ai configure"
                }
            }
        }
    }
}
