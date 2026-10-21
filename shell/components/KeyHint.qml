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
        width: keyText.implicitWidth + Theme.px(8)
        height: keyText.implicitHeight + Theme.px(2)
        color: "transparent"
        border.color: Theme.grid
        border.width: Theme.border
        radius: Theme.radius
        Text {
            id: keyText
            anchors.centerIn: parent
            text: root.key
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
        }
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: root.action
    }
}
