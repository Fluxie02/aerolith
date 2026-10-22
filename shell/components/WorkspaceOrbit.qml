import QtQuick
import qs.core
import qs.services

// The shallow workspace arc remains a route, not an ornamental dial.
Item {
    id: orbit
    property bool instrument: false
    readonly property int count: Config.strip.workspaceCount
    Repeater {
        model: orbit.count
        delegate: Item {
            id: station
            required property int index
            readonly property int workspaceId: index + 1
            readonly property bool current: Compositor.focusedWorkspaceId === workspaceId
            readonly property var entry: Compositor.workspaces.filter(w => w.id === workspaceId)
            readonly property int occupancy: entry.length ? entry[0].windows : 0
            readonly property real angle: -.92 + index * 1.84 / Math.max(1, orbit.count - 1)
            x: orbit.width * .27 + Math.sin(angle) * orbit.height * .29 - width / 2
            y: orbit.height * .55 + Math.cos(angle) * orbit.height * .29 - height / 2
            width: Theme.du(62); height: Theme.du(48)
            visible: !orbit.instrument
            Rectangle {
                anchors.fill: parent; radius: Theme.radius
                color: station.current ? Theme.surface2 : hover.containsMouse ? Theme.surface : "transparent"
                border.color: station.current ? Theme.signal : hover.containsMouse ? Theme.grid : "transparent"
                border.width: Theme.border
            }
            Text {
                y: Theme.du(6); anchors.horizontalCenter: parent.horizontalCenter
                text: (station.workspaceId < 10 ? "0" : "") + station.workspaceId
                textFormat: Text.PlainText; color: station.current ? Theme.signal : Theme.text
                font.family: Theme.mono; font.pixelSize: Theme.du(18)
            }
            Row {
                y: Theme.du(32); anchors.horizontalCenter: parent.horizontalCenter; spacing: Theme.du(3)
                Repeater {
                    model: Math.min(9, station.occupancy)
                    Rectangle { width: Theme.du(4); height: Theme.du(3); color: station.current ? Theme.signal : Theme.textDim }
                }
            }
            MouseArea {
                id: hover
                hoverEnabled: true
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: Registry.execute("workspace.focus", {workspace: station.workspaceId}, {record: false})
            }
        }
    }
}
