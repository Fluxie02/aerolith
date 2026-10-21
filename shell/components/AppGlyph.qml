import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core

// Application icon from the icon theme, or a three-letter plate when the
// theme has none. No icon font dependency.
Item {
    id: root
    property string icon: ""
    property string fallback: ""
    property int size: Theme.px(20)
    implicitWidth: size
    implicitHeight: size

    readonly property string resolved: icon !== "" ? Quickshell.iconPath(icon, true) : ""

    IconImage {
        anchors.fill: parent
        visible: root.resolved !== ""
        source: root.resolved
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        visible: root.resolved === ""
        color: "transparent"
        border.color: Theme.grid
        border.width: Theme.border
        radius: Theme.radius
        Text {
            anchors.centerIn: parent
            text: (root.fallback || root.icon || "?").replace(/[^A-Za-z0-9]/g, "").slice(0, 3).toUpperCase()
            color: Theme.textDim
            font.family: Theme.mono
            font.pixelSize: Math.max(7, Math.round(root.size * 0.36))
        }
    }
}
