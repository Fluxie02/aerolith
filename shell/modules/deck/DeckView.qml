import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services
import "../notices"

// Visual layer of the Deck: backdrop, bay rail and the frames the open bay
// is shown in. The Deck (Deck.qml) owns the surface, keyboard handling and
// bay lifetimes and places each bay's Loader inside frameA or frameB.
//
// Contracts (see ARCHITECTURE.md): rail order and ids come from deck.rail;
// clicking the backdrop closes the Deck; a slot (deck.slotA/slotB, the
// parent of whatever is in frameA/frameB) is `current` while its bay is
// requested and `leaving` for at most deck.exitMs after it was closed or
// replaced; deck.exiting is true while a closed Deck finishes its exit.
// While the Deck is mapped it must show the NoticeStack, because the notice
// column surface hides then.
Item {
    id: view

    required property var deck
    readonly property alias frameA: frameA
    readonly property alias frameB: frameB
    readonly property alias missingAiBay: missingAiBay

    readonly property var codes: ({
            command: "CMD",
            navigator: "NAV",
            systems: "SYS",
            signal: "SIG",
            routines: "RTN",
            ai: "AI",
            help: "HELP"
        })

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

    // Bay rail
    Row {
        id: railRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Config.strip.edge === "top" ? Theme.stripHeight : 0) + Theme.pad
        spacing: Theme.px(2)
        Repeater {
            model: view.deck.rail.filter(r => r.bay !== "ai" || view.deck.aiBay !== null)
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
                        text: view.codes[modelData.bay]
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

    // Bay frames: the Deck parents its two bay slots here.
    Item {
        id: frameA
        anchors.fill: parent
        anchors.topMargin: railRow.y + railRow.height + Theme.pad
        anchors.bottomMargin: (Config.strip.edge === "bottom" ? Theme.stripHeight : 0) + Theme.pad * 2
    }
    Item {
        id: frameB
        anchors.fill: frameA
    }

    NoticeStack {
        anchors.right: parent.right
        anchors.top: Config.strip.edge === "top" ? parent.top : undefined
        anchors.bottom: Config.strip.edge === "bottom" ? parent.bottom : undefined
        anchors.margins: Theme.pad
        anchors.topMargin: (Config.strip.edge === "top" ? Theme.stripHeight : 0) + Theme.pad
        anchors.bottomMargin: (Config.strip.edge === "bottom" ? Theme.stripHeight : 0) + Theme.pad
        width: implicitWidth
        visible: hasContent
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
