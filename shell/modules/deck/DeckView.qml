import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services
import "../notices"

// Limb's circular field intersected by the retained, left-origin chord.
// Surface, focus, input lifetime and all bay demand belong to Deck.qml.
Item {
    id: view
    required property var deck
    readonly property alias frameA: frameA
    readonly property alias frameB: frameB
    readonly property alias missingAiBay: missingAiBay
    readonly property var codes: ({command:"CMD",navigator:"NAV",systems:"SYS",signal:"SIG",routines:"RTN",ai:"AI",help:"HELP"})
    readonly property bool compactScreen: width < Theme.du(1500) || height < Theme.du(850)
    readonly property real fieldProgress: Math.max(frameA.progress, frameB.progress)

    // Keep the strip, especially its sharing indicator, visible above the ground.
    Item {
        anchors.fill: parent
        anchors.topMargin: Config.strip.edge === "top" ? Theme.stripHeight : 0
        anchors.bottomMargin: Config.strip.edge === "bottom" ? Theme.stripHeight : 0
        clip: true
        Rectangle { anchors.fill: parent; color: Theme.bg }
        CircularField {
            y: Config.strip.edge === "top" ? -Theme.stripHeight : 0
            width: view.width; height: view.height
            instrument: true; progress: view.fieldProgress
        }
    }
    MouseArea { anchors.fill: parent; onClicked: Ui.close() }

    Row {
        id: railRow
        x: view.compactScreen ? view.width * .045 : view.width * .37
        y: (Config.strip.edge === "top" ? Theme.stripHeight : 0) + Theme.du(view.compactScreen ? 24 : 42)
        spacing: Theme.du(view.compactScreen ? 18 : 25)
        Repeater {
            model: view.deck.rail.filter(r => r.bay !== "ai" || view.deck.aiBay !== null)
            delegate: Item {
                required property var modelData
                readonly property bool current: Ui.activeBay === modelData.bay
                width: Theme.du(modelData.bay === "help" ? 88 : 74)
                height: Theme.du(34)
                Text {
                    text: (modelData.key === "F1" ? "F1" : "^" + modelData.key) + " " + view.codes[modelData.bay]
                    textFormat: Text.PlainText
                    color: parent.current ? Theme.signal : Theme.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontSm
                }
                Rectangle {
                    y: Theme.du(25); width: parent.current ? parent.width : Theme.du(8)
                    height: parent.current ? Theme.px(2) : Theme.border
                    color: parent.current ? Theme.signal : Theme.grid
                    Behavior on width { enabled: Theme.animate; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open(modelData.bay) }
            }
        }
    }
    ChordSlot { id: frameA; slot: view.deck.slotA }
    ChordSlot { id: frameB; slot: view.deck.slotB }

    Column {
        visible: !view.compactScreen && (view.deck.slotA.bay === "command" || view.deck.slotB.bay === "command")
        x: parent.width * .105; y: parent.height * .43
        opacity: view.fieldProgress
        spacing: Theme.du(16)
        Text { text: "COMMAND"; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(34); font.weight: Font.Medium; font.letterSpacing: 1 }
        Text { text: "C O R E"; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(34); font.weight: Font.Medium; font.letterSpacing: 3 }
        Rectangle { width: Theme.du(92); height: Theme.px(2); color: Theme.signal }
        Text {
            text: "KEYBOARD / FIRST\n>  COMMANDS\n@  WINDOWS\n!  ROUTINES\n?  AI IF INSTALLED"
            textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm; lineHeight: 1.7
        }
    }
    Text {
        x: parent.width * .08; y: parent.height - Theme.du(50)
        visible: !view.compactScreen
        text: "AEROLITH   /   LIMB"; textFormat: Text.PlainText
        color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
    }
    NoticeStack {
        z: 10
        anchors.right: parent.right
        anchors.top: Config.strip.edge === "top" ? parent.top : undefined
        anchors.bottom: Config.strip.edge === "bottom" ? parent.bottom : undefined
        anchors.margins: Theme.pad
        anchors.topMargin: (Config.strip.edge === "top" ? Theme.stripHeight : 0) + Theme.pad
        anchors.bottomMargin: (Config.strip.edge === "bottom" ? Theme.stripHeight : 0) + Theme.pad
        width: Math.min(implicitWidth, view.width - 2 * Theme.pad)
        visible: hasContent
    }
    Component {
        id: missingAiBay
        FocusScope {
            Bezel {
                anchors.fill: parent
                designation: "AI / 06"; title: "AI Bridge not installed"; active: false
                MouseArea { anchors.fill: parent }
                Text {
                    anchors.fill: parent; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                    color: Theme.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontMd
                    text: "AEROLITH is running without AI integration. Everything else works normally. To add a provider later, run: aerolith ai configure"
                }
            }
        }
    }
}
