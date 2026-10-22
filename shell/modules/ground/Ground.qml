import QtQuick
import qs.core
import qs.components
import qs.services

// Limb's idle ground: static geometry, refreshed only by workspace and theme.
Rectangle {
    id: ground
    color: Theme.bg
    CircularField { anchors.fill: parent }
    Column {
        x: parent.width * .55; y: parent.height * .67
        width: parent.width * .4
        visible: !Ui.deckOpen
        spacing: Theme.du(12)
        Text {
            text: "A E R O L I T H"; textFormat: Text.PlainText
            color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.du(16); font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            text: "WS " + (Compositor.focusedWorkspaceId > 0 ? Compositor.focusedWorkspaceId : "N/A") + "  /  " + (Compositor.activeClass || "NO FOCUSED APPLICATION").toUpperCase()
            textFormat: Text.PlainText; elide: Text.ElideRight
            color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        Flow {
            width: parent.width; spacing: Theme.du(20)
            Repeater {
                model: [{t:"⌘ COMMAND",b:"command"},{t:"↗ NAVIGATOR",b:"navigator"},{t:"∿ SYSTEMS",b:"systems"}]
                delegate: Text {
                    required property var modelData
                    text: modelData.t; textFormat: Text.PlainText
                    color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open(modelData.b) }
                }
            }
        }
    }
}
