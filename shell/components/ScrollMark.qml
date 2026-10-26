import QtQuick
import qs.core

// A passive vertical position register, fixed to the viewport rather than its
// moving content. No timer, animation, focus or interference with wheel input.
Item {
    id: mark
    required property Flickable viewport
    parent: viewport
    x: viewport.width - width
    y: 0
    width: Theme.du(3)
    height: viewport.height
    z: 5
    visible: viewport.contentHeight > viewport.height + 1
    Rectangle { anchors.fill: parent; color: Theme.grid }
    Rectangle {
        width: parent.width
        height: Math.min(mark.height, Math.max(Theme.du(18), mark.height * mark.viewport.visibleArea.heightRatio))
        y: Math.max(0, Math.min(mark.height - height, mark.viewport.visibleArea.yPosition * mark.height))
        radius: width / 2
        color: Theme.textDim
    }
}
