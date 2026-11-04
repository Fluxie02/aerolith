import QtQuick
import qs.core

// Bottom status line of a bay: key hints on the left, a message on the
// right coloured by state (ok/error/caution/busy).
Item {
    id: root
    property var profile: Theme
    property var hints: []        // [{ key, action }]
    property string message: ""
    property string messageState: "" // ok | error | caution | busy | ""
    implicitHeight: Theme.du(10) + hintsFlow.implicitHeight
                    + (message !== "" ? Theme.du(8) + messageText.implicitHeight : 0) + Theme.du(4)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.border
        color: root.profile.grid
    }
    Flow {
        id: hintsFlow
        anchors.left: parent.left
        anchors.right: parent.right
        y: Theme.du(10)
        spacing: Theme.pad
        Repeater {
            model: root.hints
            KeyHint { profile: root.profile;
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
        y: hintsFlow.y + hintsFlow.implicitHeight + Theme.du(8)
        visible: root.message !== ""
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
        text: root.messageState === "busy" ? "◌ " + root.message : root.message
        color: root.messageState === "ok" ? root.profile.signal : root.messageState === "error" ? root.profile.critical : root.messageState === "caution" ? root.profile.caution : root.profile.textDim
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
    }
}
