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
    readonly property var codes: ({command:"CMD",navigator:"NAV",systems:"SYS",signal:"SIG",routines:"RTN",ai:"AI",settings:"SET",help:"HELP"})
    readonly property var bayNames: ({command:"Command",navigator:"Navigator",systems:"Systems",signal:"Signal",routines:"Routines",ai:"AI",settings:"Settings",help:"Help"})
    readonly property var railEntries: deck.rail.filter(r => r.bay !== "ai" || deck.aiBay !== null).map(r => ({bay:r.bay, key:r.key, label:bayNames[r.bay] || r.bay}))
    readonly property bool compactScreen: width < Theme.du(1500) || height < Theme.du(850)
    readonly property real fieldProgress: Math.max(frameA.progress, frameB.progress)

    // Keep the strip, especially its sharing indicator, visible above the ground.
    Item {
        anchors.fill: parent
        anchors.topMargin: Config.strip.edge === "top" ? Theme.stripHeight : 0
        anchors.bottomMargin: Config.strip.edge === "bottom" ? Theme.stripHeight : 0
        clip: true
        Rectangle { anchors.fill: parent; color: Theme.bg }
        InstrumentField {
            y: Config.strip.edge === "top" ? -Theme.stripHeight : 0
            width: view.width; height: view.height
            instrument: true; progress: view.fieldProgress
        }
    }
    MouseArea { anchors.fill: parent; onClicked: Ui.close() }
    Instrumentation { anchors.fill: parent; instrument: true }


    InstrumentTabs {
        id: railRow
        x: view.width * (view.compactScreen ? .045 : .37)
        y: (Config.strip.edge === "top" ? Theme.stripHeight : 0) + Theme.du(8)
        width: view.width - x - view.width * (view.compactScreen ? .045 : .08)
        height: implicitHeight
        arc: true; shortcuts: true
        compact: view.compactScreen
        entries: view.railEntries
        currentIndex: view.railEntries.map(r => r.bay).indexOf(Ui.activeBay)
        onChosen: index => Ui.open(view.railEntries[index].bay)
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
        x: parent.width * .055; y: parent.height * .84
        visible: !view.compactScreen
        text: "LIMB / " + Theme.variantName.toUpperCase(); textFormat: Text.PlainText
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
                designation: "AI / 06"; title: "AI Bridge"; status: "NOT INSTALLED"; statusColor: Theme.caution
                MouseArea { anchors.fill: parent }
                Column {
                    width: parent.width; spacing: Theme.pad
                    Label { width: parent.width; text: "OPTIONAL MODULE / OFFLINE"; strong: true }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                        color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.fontXl
                        text: "Add a provider when you need one."
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                        color: Theme.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                        text: "The desktop is ready without AI. Configure a provider to ask questions and review proposed actions here."
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText
                        color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontMd
                        text: "aerolith ai configure"
                    }
                }
            }
        }
    }
}
