import QtQuick
import qs.core

// [KEY] ACTION hint used in status lines.
Row {
    id: root
    property string key: ""
    property string action: ""
    spacing: Theme.px(4)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: keyText.implicitWidth
        height: keyText.implicitHeight + Theme.px(2)
        color: "transparent"
        radius: Theme.radius
        Text {
            textFormat: Text.PlainText
            id: keyText
            anchors.centerIn: parent
            text: root.key
            color: Theme.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
        }
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: root.action
    }
}
