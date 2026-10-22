import QtQuick
import qs.core

// Bottom status line of a bay: key hints on the left, a message on the
// right coloured by state (ok/error/caution/busy).
Item {
    id: root
    property var hints: []        // [{ key, action }]
    property string message: ""
    property string messageState: "" // ok | error | caution | busy | ""
    implicitHeight: hintsFlow.implicitHeight + messageText.implicitHeight + Theme.du(22)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.border
        color: Theme.grid
    }
    Flow {
        id: hintsFlow
        anchors.left: parent.left
        anchors.right: parent.right
        y: Theme.du(10)
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
        id: messageText
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        elide: Text.ElideRight
        text: root.messageState === "busy" ? "◌ " + root.message : root.message
        color: root.messageState === "ok" ? Theme.signal : root.messageState === "error" ? Theme.critical : root.messageState === "caution" ? Theme.caution : Theme.textDim
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
    }
}
