// UI-007 / passive visual OSD; no audio/backlight calls, focus, or expiry timer.
// Inputs: kind: volume | brightness | mic; value: normalized real (NaN = N/A);
// muted: bool; maxValue: finite positive real (e.g. 1.5); label: plain device name.
// presentationOpen: host's requested visibility (default true). Keep this item
// mapped until settled() after setting false; reuse it by setting true again.
// Outputs: settled() after exit; readonly exitMs and presenting for host lifecycle.
import QtQuick
import qs.core
import qs.components

Item {
    id: root
    property string kind: "volume"
    property real value: NaN
    property bool muted: false
    property real maxValue: 1
    property string label: ""
    property bool presentationOpen: true
    readonly property int exitMs: Theme.animate && !Theme.lowEffects ? Theme.fast : 0
    readonly property bool presenting: presentationOpen || face.opacity > 0
    readonly property bool known: isFinite(value)
    readonly property real ceiling: isFinite(maxValue) && maxValue > 0 ? maxValue : 1
    readonly property real bounded: known ? Math.max(0, Math.min(ceiling, value)) : 0
    readonly property color accent: muted ? Theme.caution : known && value > 1 ? Theme.caution : Theme.signal
    signal settled()
    implicitWidth: Theme.du(408)
    implicitHeight: Theme.du(158)
    property bool exitPending: false
    function finishExit() {
        if (exitPending && !presentationOpen && face.opacity <= 0) { exitPending = false; settled(); }
    }
    property bool ready: false
    Component.onCompleted: { ready = true; if (!presentationOpen) settled(); }
    onPresentationOpenChanged: { exitPending = !presentationOpen; if (exitPending) Qt.callLater(finishExit); }

    Bezel {
        id: face; anchors.fill: parent
        opacity: root.ready && root.presentationOpen ? 1 : 0
        onOpacityChanged: if (opacity <= 0) Qt.callLater(root.finishExit)
        transform: Translate { y: Theme.travel && !Theme.lowEffects && (!root.ready || !root.presentationOpen) ? Theme.du(8) : 0
            Behavior on y { enabled: Theme.animate && !Theme.lowEffects; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity {
            enabled: Theme.animate && !Theme.lowEffects
            NumberAnimation {
                duration: Theme.fast; easing.type: Easing.OutCubic
            }
        }
        designation: root.kind === "brightness" ? "☀" : root.kind === "mic" ? "MIC" : "VOL"
        title: root.kind === "brightness" ? "Brightness" : root.kind === "mic" ? "Microphone" : "Volume"
        status: root.muted ? "MUTED" : !root.known ? "N/A" : Math.round(root.bounded*100) + "%"
        statusColor: root.accent; accent: root.accent
        contentPadding: Theme.du(20); titleHeight: Theme.du(48)
        Column {
            anchors.fill: parent; spacing: Theme.du(12)
            Text {
                width: parent.width; text: root.label || "Device not reported"
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Theme.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd
            }
            Item {
                width: parent.width; height: Theme.du(14)
                Rectangle { anchors.fill: parent; color: Theme.bg; border.color: Theme.grid; border.width: Theme.border }
                Rectangle {
                    x: 1; y: 1; height: parent.height-2
                    width: Math.max(0,(parent.width-2)*root.bounded/root.ceiling)
                    visible: root.known && !root.muted; color: root.accent
                }
                Repeater {
                    model: Theme.insane ? 32 : 16
                    Rectangle {
                        required property int index
                        x: (index+1)*parent.width/((Theme.insane ? 32 : 16)+1)
                        width: 1; height: parent.height; color: Theme.surface
                    }
                }
                Rectangle {
                    visible: root.ceiling > 1
                    x: parent.width/root.ceiling; width: Theme.border; height: parent.height+Theme.du(5); color: Theme.text
                }
                Text {
                    anchors.centerIn: parent; visible: !root.known || root.muted
                    text: !root.known ? "—  N/A  —" : "—  MUTED  —"
                    textFormat: Text.PlainText; color: root.accent; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
            }
            Item {
                width: parent.width; height: Theme.fontXs + Theme.du(2)
                Text { text: "0"; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
                Text {
                    visible: root.ceiling > 1
                    x: parent.width/root.ceiling-width/2
                    text: "100%"; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                Text {
                    anchors.right: parent.right
                    text: root.ceiling > 1 ? "MAX " + Math.round(root.ceiling*100) + "%" : "100%"
                    color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
            }
        }
    }
}
