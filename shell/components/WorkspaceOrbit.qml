import QtQuick
import qs.core
import qs.services

// The annulus is a real route. Its index arm tracks the focused station;
// window occupancy adds teeth, without changing the click targets.
Item {
    id: orbit
    property bool instrument: false
    readonly property int count: Config.strip.workspaceCount
    readonly property bool exposed: visible && Window.window && Window.window.visible
    onExposedChanged: if (!exposed) indexMotion.complete()
    Connections {
        target: Theme
        function onTravelChanged() { if (!Theme.travel) indexMotion.complete(); }
        function onAmbientChanged() { if (!Theme.ambient) indexMotion.complete(); }
    }
    readonly property real radius: height * .29
    readonly property real focusAngle: -.92 + Math.max(0, Math.min(count - 1, Compositor.focusedWorkspaceId - 1)) * 1.84 / Math.max(1, count - 1)
    visible: !instrument

    // Follow the machined annulus in InstrumentField, not the clickable
    // station radius. Only its two lips are shaded; the numeral stays dark.
    Material {
        shader: "annulus"
        readonly property real ringRadius: orbit.height * .34
        x: orbit.width * .27 - width / 2
        y: orbit.height * .55 - height / 2
        width: ringRadius * 2 + Theme.du(8); height: width
        parameters: Qt.vector4d(ringRadius, -1.6 + Compositor.focusedWorkspaceId * .24,
            Compositor.focusedWorkspaceId > 0 ? 1 : 0, 0)
    }

    Item {
        x: orbit.width * .27; y: orbit.height * .55
        width: orbit.radius; height: 1
        rotation: 90 - orbit.focusAngle * 180 / Math.PI
        transformOrigin: Item.Left
        visible: Compositor.focusedWorkspaceId > 0 && Compositor.focusedWorkspaceId <= orbit.count
        Behavior on rotation { enabled: Theme.travel && Theme.ambient && orbit.exposed; RotationAnimator { id: indexMotion; duration: Theme.slow * 2; easing.type: Easing.OutCubic } }
        Rectangle { x: parent.width * .82; width: parent.width * .10; height: Theme.du(2); color: Theme.signal }
        Rectangle { x: parent.width * .77; width: Theme.du(3); height: Theme.du(7); y: -height / 2; color: Theme.signal }
    }
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
            x: orbit.width * .27 + Math.sin(angle) * orbit.radius - width / 2
            y: orbit.height * .55 + Math.cos(angle) * orbit.radius - height / 2
            width: Theme.du(62); height: Theme.du(48)
            Rectangle {
                anchors.fill: parent
                color: station.current ? Theme.signal : hover.containsMouse ? Theme.surface2 : Theme.bg
                border.color: station.current || hover.containsMouse ? Theme.signal : Theme.grid
                border.width: Theme.border
            }
            Rectangle {
                x: -Theme.du(4); y: -Theme.du(4)
                width: Theme.du(12); height: Theme.du(2)
                color: station.current ? Theme.signal : Theme.grid
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: -Theme.du(4)
                anchors.bottom: parent.bottom; anchors.bottomMargin: -Theme.du(4)
                width: Theme.du(12); height: Theme.du(2)
                color: station.current ? Theme.signal : Theme.grid
            }
            Text {
                y: Theme.du(6); anchors.horizontalCenter: parent.horizontalCenter
                text: (station.workspaceId < 10 ? "0" : "") + station.workspaceId
                textFormat: Text.PlainText; color: station.current ? Theme.bg : Theme.text
                font.family: Theme.mono; font.pixelSize: Theme.du(18)
            }
            Row {
                y: Theme.du(32); anchors.horizontalCenter: parent.horizontalCenter; spacing: Theme.du(3)
                Repeater {
                    model: Math.min(9, station.occupancy)
                    Rectangle { width: Theme.du(4); height: Theme.du(3); color: station.current ? Theme.bg : Theme.textDim }
                }
            }
            MouseArea {
                id: hover; hoverEnabled: true
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: Registry.execute("workspace.focus", {workspace: station.workspaceId}, {record: false})
            }
            Accessible.role: Accessible.Button; Accessible.name: "Workspace " + workspaceId + ", " + occupancy + " windows"
            Accessible.onPressAction: Registry.execute("workspace.focus", {workspace: station.workspaceId}, {record: false})
        }
    }
}
