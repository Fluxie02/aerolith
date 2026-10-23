import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services
import "../notices"

// An exposed airframe carries the retained, left-origin machine planes.
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
    readonly property string shownBay: Ui.activeBay || (deck.slotA.leaving ? deck.slotA.bay : deck.slotB.bay)
    readonly property string shownCode: codes[shownBay] || "—"

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


    // A navigation bus shields names from the instrument engraving beneath.
    // The circular field remains exposed around the retained chord.
    Rectangle {
        x: view.compactScreen ? 0 : railRow.x - Theme.pad
        y: Config.strip.edge === "top" ? Theme.stripHeight : 0
        width: view.compactScreen ? view.width : railRow.width + 2 * Theme.pad
        height: railRow.y - y + railRow.height + Theme.du(4)
        color: Theme.bg
        radius: 0
    }
    Rectangle {
        visible: !view.compactScreen
        x: railRow.x - Theme.du(12); y: railRow.y + Theme.du(10)
        width: Theme.du(3); height: railRow.height - Theme.du(20)
        color: Theme.signal
    }
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

    // A clipped elevation sits beside the command plane, leaving the live
    // controls rectangular. Its label changes only with actual bay state.
    Row {
        visible: !view.compactScreen
        x: parent.width * .055; y: parent.height * .184
        spacing: Theme.du(10)
        Rectangle {
            width: Theme.du(26); height: Theme.du(3)
            anchors.verticalCenter: parent.verticalCenter; color: Theme.signal
        }
        Text {
            text: "CHORD / " + view.shownCode + (Ui.deckOpen ? "   /   ENGAGED" : "   /   RELEASE")
            textFormat: Text.PlainText; color: Theme.signal
            font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1.2
        }
    }
    Item {
        visible: !view.compactScreen && (view.deck.slotA.bay === "command" || view.deck.slotB.bay === "command")
        x: parent.width * .105; y: parent.height * .43
        width: parent.width * .225; height: parent.height * .34
        opacity: .8 + view.fieldProgress * .2
        Canvas {
            id: commandElevation
            x: -Theme.du(18); y: -Theme.du(15)
            width: parent.width + Theme.du(30); height: parent.height + Theme.du(22)
            renderTarget: Canvas.Image
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onAvailableChanged: if (available) requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset();
                var cut = Math.min(width * .3, Theme.du(76));
                c.beginPath(); c.moveTo(0, 0); c.lineTo(width - cut, 0);
                c.lineTo(width, cut); c.lineTo(width, height - Theme.du(30));
                c.lineTo(width - Theme.du(30), height); c.lineTo(0, height); c.closePath();
                c.fillStyle = Theme.bg; c.fill();
                c.strokeStyle = Theme.grid; c.lineWidth = Theme.border; c.stroke();
                c.beginPath(); c.moveTo(0, Theme.du(8)); c.lineTo(0, Theme.du(66));
                c.strokeStyle = Theme.signal; c.lineWidth = Theme.du(3); c.stroke();
            }
            Connections {
                target: Theme
                function onPaletteChanged() { commandElevation.requestPaint(); }
                function onUnitChanged() { commandElevation.requestPaint(); }
            }
            Connections {
                target: commandElevation.Window.window
                function onVisibleChanged() { if (commandElevation.Window.window.visible) commandElevation.requestPaint(); }
            }
        }
        Text {
            text: "01 / COMMAND CORE"; textFormat: Text.PlainText
            color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
        }
        Text {
            y: Theme.du(24); text: "CMD"; textFormat: Text.PlainText
            color: Theme.text; font.family: Theme.displaySans
            font.pixelSize: Math.min(Theme.du(98), parent.width * .34)
            font.weight: Font.Light; font.letterSpacing: -Theme.du(4)
        }
        Rectangle {
            x: Theme.du(2); y: Theme.du(138)
            width: parent.width * .64; height: Theme.du(3); color: Theme.signal
        }
        Text {
            x: Theme.du(2); y: Theme.du(158); width: parent.width - Theme.du(20)
            text: "KEYBOARD / FIRST\n>  COMMANDS\n@  WINDOWS\n!  ROUTINES\n?  AI IF INSTALLED"
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; lineHeight: 1.6
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
