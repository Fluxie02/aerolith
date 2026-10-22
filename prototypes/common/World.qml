import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services
import qs.modules.systems
import qs.modules.routines
import qs.modules.help

Scope {
    id: world
    property int concept: 0
    Style { id: visualStyle; concept: world.concept }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Illustrative background only. Production lifecycle is requested from Claude.
    PanelWindow {
        id: ground
        screen: Ui.screen
        visible: Ui.screen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        color: visualStyle.bg
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "aerolith-prototype-ground"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Canvas {
            visible: visualStyle.observatory
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset();
                c.strokeStyle = visualStyle.line; c.lineWidth = 1;
                var x = width * 0.7, y = height * 0.48, r = height * 0.32;
                c.beginPath(); c.arc(x, y, r, 0.15, 5.6); c.stroke();
                c.beginPath(); c.arc(x, y, r + 18, 3.3, 5.1); c.stroke();
                c.strokeStyle = visualStyle.accent;
                c.beginPath(); c.moveTo(x-r-24,y); c.lineTo(x-r+24,y); c.stroke();
                c.beginPath(); c.moveTo(x,y+r-24); c.lineTo(x,y+r+24); c.stroke();
            }
        }
        Rectangle {
            visible: visualStyle.architecture
            x: parent.width * 0.39; y: parent.height * 0.18
            width: parent.width * 0.48; height: parent.height * 0.82
            color: visualStyle.surface
            Rectangle { x: -32; y: 48; width: 32; height: parent.height - 48; color: visualStyle.inset }
            Rectangle { x: parent.width; y: 120; width: 10; height: parent.height - 120; color: visualStyle.accent }
        }
        Rectangle {
            visible: visualStyle.index
            x: parent.width * 0.74; width: parent.width - x; height: parent.height
            color: visualStyle.margin
            Rectangle { x: -8; y: parent.height * 0.27; width: 8; height: visualStyle.px(108); color: visualStyle.accent }
            Ink { s: visualStyle; x: 48; y: parent.height - 110; text: "A E R O L I T H"; color: visualStyle.inverseDim; font.pixelSize: visualStyle.small }
        }
        Column {
            x: visualStyle.px(visualStyle.index ? 120 : 100)
            y: parent.height * (visualStyle.observatory ? 0.57 : 0.34)
            spacing: visualStyle.px(12)
            Ink { s: visualStyle; mono: true; text: "WORKSPACE"; color: visualStyle.dim; font.pixelSize: visualStyle.small; font.letterSpacing: 3 }
            Ink {
                s: visualStyle
                text: Compositor.focusedWorkspaceId > 0 ? (Compositor.focusedWorkspaceId < 10 ? "0" : "") + Compositor.focusedWorkspaceId + (visualStyle.index ? "/" : "") : "—"
                font.pixelSize: visualStyle.px(visualStyle.index ? 220 : visualStyle.architecture ? 152 : 112)
                font.weight: Font.Light
                font.letterSpacing: visualStyle.index ? -14 : -6
                lineHeight: 0.9
            }
            Rectangle { width: visualStyle.px(visualStyle.index ? 420 : 200); height: visualStyle.index ? 4 : 1; color: visualStyle.accent }
        }
        Ink {
            s: visualStyle; visible: !visualStyle.index; x: visualStyle.px(100); y: parent.height - visualStyle.px(64)
            text: visualStyle.observatory ? "AEROLITH  /  PARALLAX" : visualStyle.architecture ? "AEROLITH  /  CUT" : "Open     /     Workspaces     /     Sound"
            font.pixelSize: visualStyle.small; color: visualStyle.dim
        }
    }

    PanelWindow {
        id: strip
        screen: Ui.screen
        visible: Config.strip.visible && Ui.screen !== null
        anchors { left: true; right: true; top: Config.strip.edge === "top"; bottom: Config.strip.edge === "bottom" }
        implicitHeight: Theme.stripHeight
        exclusiveZone: Theme.stripHeight
        color: visualStyle.index ? visualStyle.margin : visualStyle.surface
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "aerolith-strip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Row {
            x: visualStyle.px(24); height: parent.height; spacing: visualStyle.px(28)
            Repeater {
                model: [{label:"↗ Open", bay:"command"}, {label:"Workspaces", bay:"navigator"}, {label:"Sound", bay:"signal"}]
                delegate: Item {
                    required property var modelData
                    width: label.implicitWidth; height: strip.height
                    Ink { id: label; s: visualStyle; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: visualStyle.index ? visualStyle.inverse : visualStyle.ink; font.pixelSize: visualStyle.small }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggle(modelData.bay) }
                }
            }
            Ink { s: visualStyle; anchors.verticalCenter: parent.verticalCenter; text: " / " + (Compositor.focusedWorkspaceId > 0 ? Compositor.focusedWorkspaceId : "N/A") + "    " + (Config.strip.showWindowTitle ? Compositor.activeTitle : ""); width: visualStyle.px(480); color: visualStyle.index ? visualStyle.inverseDim : visualStyle.dim; font.pixelSize: visualStyle.small }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: visualStyle.px(24); height: parent.height; spacing: visualStyle.px(24)
            Ink { s: visualStyle; visible: Compositor.screencastActive; anchors.verticalCenter: parent.verticalCenter; text: "● SHARING  " + Compositor.screencastOwner; color: visualStyle.index ? "#ffa6a0" : visualStyle.error; font.pixelSize: visualStyle.small }
            Ink { s: visualStyle; visible: Ui.multipleDisplays && Config.display.warnOnMultipleDisplays; anchors.verticalCenter: parent.verticalCenter; text: "DISPLAY  1/" + Ui.screenCount; color: visualStyle.index ? "#f6d085" : visualStyle.warning; font.pixelSize: visualStyle.small }
            Ink { s: visualStyle; visible: Config.errors.length > 0 || Routines.errors.length > 0; anchors.verticalCenter: parent.verticalCenter; text: "CONFIG  " + (Config.errors.length + Routines.errors.length); color: visualStyle.index ? "#f6d085" : visualStyle.warning; font.pixelSize: visualStyle.small }
            Ink { s: visualStyle; visible: Audio.ready; anchors.verticalCenter: parent.verticalCenter; text: "Sound  " + (Audio.sinkReady ? (Audio.muted ? "Muted" : Audio.volumePercent + "%") : "N/A"); color: visualStyle.index ? visualStyle.inverseDim : visualStyle.dim; font.pixelSize: visualStyle.small }
            Ink { s: visualStyle; mono: true; anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(clock.date, "ddd  dd MMM   hh:mm"); color: visualStyle.index ? visualStyle.inverse : visualStyle.ink; font.pixelSize: visualStyle.small }
        }
    }

    PanelWindow {
        id: deck
        screen: Ui.screen
        visible: Ui.deckOpen && Ui.screen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerolith-deck"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property var rail: [
            {bay:"command", label:"Open", key:"1"}, {bay:"navigator", label:"Workspaces", key:"2"},
            {bay:"systems", label:"System", key:"3"}, {bay:"signal", label:"Sound", key:"4"},
            {bay:"routines", label:"Routines", key:"5"}, {bay:"ai", label:"AI", key:"6"}, {bay:"help", label:"Help", key:"F1"}]
        readonly property bool sideIndex: visualStyle.index && width / visualStyle.unit >= 1200 && height / visualStyle.unit >= 800
        Rectangle { anchors.fill: parent; color: visualStyle.bg; opacity: Theme.lowEffects || !visualStyle.observatory ? 1 : 0.94 }
        MouseArea { anchors.fill: parent; onClicked: Ui.close() }
        Ink {
            s: visualStyle; visible: Compositor.screencastActive
            anchors.right: parent.right; anchors.rightMargin: visualStyle.px(32); y: visualStyle.px(24)
            text: "● SHARING  " + Compositor.screencastOwner
            color: visualStyle.error; font.pixelSize: visualStyle.small
        }
        Rectangle {
            visible: deck.sideIndex; width: Math.min(visualStyle.px(340), deck.width * 0.24); height: parent.height
            color: visualStyle.margin
        }
        Ink {
            s: visualStyle; visible: visualStyle.architecture
            x: visualStyle.px(64); y: visualStyle.px(160); width: deck.width * 0.25
            text: "A place\nfor each\ntask."; font.pixelSize: visualStyle.px(52); font.weight: Font.Light
            wrapMode: Text.WordWrap
        }
        FocusScope {
            id: focusScope
            anchors.fill: parent; focus: true
            Keys.priority: Keys.AfterItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { Ui.close(); event.accepted = true; }
                else if (event.key === Qt.Key_F1) { Ui.toggle("help"); event.accepted = true; }
                else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                    Ui.open(deck.rail[event.key-Qt.Key_1].bay); event.accepted = true;
                }
            }
            Column {
                visible: deck.sideIndex
                x: visualStyle.px(48); y: visualStyle.px(120); spacing: visualStyle.px(14)
                Ink { s: visualStyle; text: "AEROLITH"; color: visualStyle.inverseDim; font.pixelSize: visualStyle.small; font.letterSpacing: 3 }
                Item { width: 1; height: visualStyle.px(64) }
                Repeater {
                    model: deck.rail
                    delegate: Item {
                        required property var modelData
                        width: visualStyle.px(240); height: visualStyle.row
                        Rectangle { visible: Ui.activeBay === modelData.bay; x: -visualStyle.px(48); width: visualStyle.px(6); height: parent.height; color: visualStyle.inverse }
                        Ink { s: visualStyle; mono: true; y: 5; text: modelData.key === "F1" ? "F1" : "0"+modelData.key; color: visualStyle.inverseDim; font.pixelSize: visualStyle.small }
                        Ink { s: visualStyle; x: visualStyle.px(40); text: modelData.label; color: visualStyle.inverse; font.pixelSize: visualStyle.px(22); opacity: Ui.activeBay === modelData.bay ? 1 : 0.72 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open(modelData.bay) }
                    }
                }
                Ink { s: visualStyle; text: "Ctrl + number\nEsc  close"; color: visualStyle.inverseDim; font.pixelSize: visualStyle.small; lineHeight: 1.8 }
            }
            Row {
                visible: !deck.sideIndex
                x: visualStyle.architecture ? deck.width * 0.35 : visualStyle.px(visualStyle.index ? 32 : 100)
                y: Theme.stripHeight + visualStyle.px(36); spacing: visualStyle.px(24)
                Repeater {
                    model: deck.rail
                    delegate: Item {
                        required property var modelData
                        width: railLabel.implicitWidth; height: visualStyle.px(32)
                        Ink { id: railLabel; s: visualStyle; text: modelData.label; color: Ui.activeBay === modelData.bay ? visualStyle.accent : visualStyle.dim; font.pixelSize: visualStyle.small }
                        Rectangle { visible: Ui.activeBay === modelData.bay; y: visualStyle.px(24); width: parent.width; height: 2; color: visualStyle.accent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open(modelData.bay) }
                    }
                }
            }
            Item {
                id: page
                x: deck.sideIndex ? Math.min(visualStyle.px(400), deck.width * 0.28) : visualStyle.architecture ? deck.width * 0.35 : visualStyle.px(visualStyle.index ? 32 : 100)
                y: visualStyle.px(visualStyle.index && !deck.sideIndex ? 112 : 140)
                width: deck.width - x - visualStyle.px(visualStyle.index && !deck.sideIndex ? 32 : visualStyle.index ? 100 : 80)
                height: deck.height - y - visualStyle.px(70) - (Config.strip.edge === "bottom" ? Theme.stripHeight : 0)
                Rectangle {
                    visible: visualStyle.architecture; anchors.fill: parent; anchors.margins: -visualStyle.px(32); color: visualStyle.surface
                    Rectangle { x: -visualStyle.px(12); width: visualStyle.px(12); height: parent.height; color: visualStyle.accent }
                }
                Ink {
                    id: title; s: visualStyle; text: Ui.activeBay === "command" ? "Open" : Ui.activeBay === "navigator" ? "Workspaces" : Ui.activeBay === "signal" ? "Sound" : Ui.activeBay === "systems" ? "System" : Ui.activeBay === "routines" ? "Routines" : Ui.activeBay === "help" ? "Help" : "AI"
                    font.pixelSize: visualStyle.title; font.weight: Font.Light; font.letterSpacing: -1.5
                }
                Ink {
                    s: visualStyle; anchors.right: parent.right; y: visualStyle.px(20); text: "Esc  close"; font.pixelSize: visualStyle.small; color: visualStyle.dim
                    MouseArea { anchors.fill: parent; onClicked: Ui.close() }
                }
                Rectangle { y: visualStyle.px(80); width: parent.width; height: 1; color: visualStyle.line }
                Loader {
                    id: loader
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: visualStyle.px(110) }
                    active: deck.visible
                    focus: true
                    sourceComponent: Ui.activeBay === "command" ? command : Ui.activeBay === "navigator" ? navigator : Ui.activeBay === "signal" ? signal : Ui.activeBay === "systems" ? systems : Ui.activeBay === "routines" ? routines : Ui.activeBay === "help" ? help : missingAi
                    onLoaded: item.forceActiveFocus()
                }
            }
        }
        Component { id: command; Command { s: visualStyle } }
        Component { id: navigator; Navigator { s: visualStyle } }
        Component { id: signal; Signal { s: visualStyle } }
        // Unexplored bays deliberately retain existing presentation and behavior.
        Component { id: systems; SystemsBay {} }
        Component { id: routines; RoutineConsole {} }
        Component { id: help; HelpBay {} }
        Component { id: missingAi; FocusScope { Ink { s: visualStyle; text: "AI Bridge is not installed in these visual prototypes." } } }
    }
    Notices { s: visualStyle }
}
