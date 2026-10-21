import QtQuick
import qs.core

// Hairline divider with ruler ticks, the signature AEROLITH separator.
Item {
    id: root
    property int spacing: Theme.px(24)
    property color color: Theme.grid
    implicitHeight: Theme.px(4)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.border
        color: root.color
    }
    Repeater {
        model: Math.max(0, Math.floor(root.width / root.spacing))
        delegate: Rectangle {
            required property int index
            x: (index + 1) * root.spacing
            y: 0
            width: Theme.border
            height: index % 4 === 3 ? root.height : Math.ceil(root.height / 2)
            color: root.color
        }
    }
}
