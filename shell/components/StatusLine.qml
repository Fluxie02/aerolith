import QtQuick
import qs.core

// Bottom status line of a bay: key hints on the left, a message on the
// right coloured by state (ok/error/caution/busy).
Item {
    id: root
    property var hints: []        // [{ key, action }]
    property string message: ""
    property string messageState: "" // ok | error | caution | busy | ""
    implicitHeight: Theme.rowHeight * 0.8

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.border
        color: Theme.grid
    }
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Theme.px(2)
        spacing: Theme.pad
        Repeater {
            model: root.hints
            KeyHint {
                required property var modelData
                key: modelData.key
                action: modelData.action
            }
        }
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Theme.px(2)
        width: Math.min(implicitWidth, root.width * 0.55)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: root.messageState === "busy" ? "◌ " + root.message : root.message
        color: root.messageState === "ok" ? Theme.signal : root.messageState === "error" ? Theme.critical : root.messageState === "caution" ? Theme.caution : Theme.textDim
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
    }
}
