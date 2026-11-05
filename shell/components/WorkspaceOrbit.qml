import QtQuick
import qs.core
import qs.services
import "../lib/geometry.mjs" as Geometry

// The annulus is a real route. Its index arm tracks the focused station;
// window occupancy adds teeth, without changing the click targets.
Item {
    id: orbit
    property var profile: Theme
    readonly property string outputName: Screen.name
    readonly property bool ambient: !(profile.idleDimmed || profile.idleAnimationHeld) && Theme.ambientFor(outputName)
    property bool instrument: false
    objectName: "workspaceOrbit"
    readonly property var geometry: Theme.groundGeometry(width, height, Screen.name)
    readonly property var cells: Compositor.workspaceCells
    readonly property var stations: Geometry.orbitStations(cells, Config.strip.workspaceCount, geometry)
    readonly property int count: stations.length
    readonly property bool compact: geometry.compact
    function stationX(index) { return stations[index].x; }
    function stationY(index) { return stations[index].y; }
    property int stationRevision: 0
    readonly property var stationBounds: {
        const revision = stationRevision;
        const rects = [];
        for (let i = 0; i < stationRepeater.count; i++) {
            const item = stationRepeater.itemAt(i);
            if (item) rects.push({ x: item.x, y: item.y, width: item.width, height: item.height });
        }
        return Geometry.bounds(rects);
    }
    AnchorTarget {
        name: "ring"; active: !orbit.instrument
        x: orbit.stationBounds.x; y: orbit.stationBounds.y
        width: orbit.stationBounds.width; height: orbit.stationBounds.height
    }
    readonly property bool exposed: visible && Window.window && Window.window.visible
    onAmbientChanged: if (!ambient) indexMotion.complete()
    onExposedChanged: if (!exposed) indexMotion.complete()
    Connections {
        target: Theme
        function onTravelChanged() { if (!Theme.travel) indexMotion.complete(); }
    }
    readonly property real radius: geometry.stationRadius
    readonly property int focusIndex: Math.max(0, stations.findIndex(s => s.id === Compositor.focusedWorkspaceId || s.overflow.indexOf(Compositor.focusedWorkspaceId) >= 0))
    readonly property real focusAngle: Math.atan2(stationX(focusIndex) - geometry.cx, stationY(focusIndex) - geometry.cy)
    visible: !instrument

    // Follow the machined annulus in InstrumentField, not the clickable
    // station radius. Only its two lips are shaded; the numeral stays dark.
    Material { profile: orbit.profile;
        shader: "annulus"
        visible: !orbit.compact
        readonly property real ringRadius: orbit.geometry.ringRadius
        x: orbit.geometry.cx - width / 2
        y: orbit.geometry.cy - height / 2
        width: ringRadius * 2 + Theme.du(8); height: width
        parameters: Qt.vector4d(ringRadius, Math.PI / 2 - orbit.focusAngle,
            Compositor.focusedWorkspaceId > 0 ? 1 : 0, 0)
    }

    Item {
        x: orbit.geometry.cx; y: orbit.geometry.cy
        width: orbit.radius; height: 1
        rotation: 90 - orbit.focusAngle * 180 / Math.PI
        transformOrigin: Item.Left
        visible: !orbit.compact && Compositor.focusedWorkspaceId > 0 && orbit.cells.some(w => w.id === Compositor.focusedWorkspaceId)
        Behavior on rotation { enabled: Theme.travel && orbit.ambient && orbit.exposed; RotationAnimator { id: indexMotion; duration: Theme.slow * 2; easing.type: Easing.OutCubic } }
        Rectangle { x: parent.width * .82; width: parent.width * .10; height: Theme.du(2); color: orbit.profile.signal }
        Rectangle { x: parent.width * .77; width: Theme.du(3); height: Theme.du(7); y: -height / 2; color: orbit.profile.signal }
    }
    Repeater {
        id: stationRepeater
        onItemAdded: orbit.stationRevision++
        onItemRemoved: orbit.stationRevision++
        // Keep delegates alive across focus/occupancy updates.
        model: orbit.count
        delegate: Item {
            id: station
            required property int index
            readonly property var modelData: orbit.stations[index] || ({ id: 0, x: 0, y: 0, width: 0, height: 0, overflow: [] })
            objectName: modelData.overflow.length ? "workspaceOverflow" : "workspaceStation-" + workspaceId
            readonly property int workspaceId: modelData.id
            readonly property bool overflow: modelData.overflow.length > 0
            readonly property bool current: overflow ? modelData.overflow.indexOf(Compositor.focusedWorkspaceId) >= 0 : Compositor.focusedWorkspaceId === workspaceId
            readonly property var entry: Compositor.workspaces.filter(w => w.id === workspaceId)
            readonly property int occupancy: overflow ? orbit.cells.filter(w => modelData.overflow.indexOf(w.id) >= 0).reduce((n, w) => n + w.windows, 0) : entry.length ? entry[0].windows : 0
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            width: modelData.width; height: modelData.height
            activeFocusOnTab: true
            Keys.onReturnPressed: choose()
            Keys.onSpacePressed: choose()
            function choose() {
                if (overflow) Ui.open("navigator");
                else Registry.execute("workspace.focus", {workspace: workspaceId}, {record: false});
            }
            Rectangle {
                anchors.fill: parent
                color: station.current ? orbit.profile.signal : hover.containsMouse ? orbit.profile.surface2 : orbit.profile.bg
                border.color: station.current || hover.containsMouse || station.activeFocus ? orbit.profile.signal : station.occupancy > 0 ? orbit.profile.textDim : orbit.profile.grid
                border.width: station.activeFocus ? Theme.du(2) : Theme.border
            }
            Rectangle {
                x: -Theme.du(4); y: -Theme.du(4)
                width: Theme.du(12); height: Theme.du(2)
                color: station.current ? orbit.profile.signal : orbit.profile.grid
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: -Theme.du(4)
                anchors.bottom: parent.bottom; anchors.bottomMargin: -Theme.du(4)
                width: Theme.du(12); height: Theme.du(2)
                color: station.current ? orbit.profile.signal : orbit.profile.grid
            }
            Text {
                y: Theme.du(6); anchors.horizontalCenter: parent.horizontalCenter
                text: station.overflow ? "+" + station.modelData.overflow.length : (station.workspaceId < 10 ? "0" : "") + station.workspaceId
                textFormat: Text.PlainText; color: station.current ? orbit.profile.bg : orbit.profile.text
                font.family: Theme.mono; font.pixelSize: Theme.du(18)
            }
            Text {
                y: Theme.du(34); width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: station.occupancy > 0 ? station.occupancy + " OPEN" : "EMPTY"
                textFormat: Text.PlainText
                color: station.current ? orbit.profile.bg : station.occupancy > 0 ? orbit.profile.text : orbit.profile.textDim
                font.family: Theme.mono; font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }
            MouseArea {
                id: hover; hoverEnabled: true
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: station.choose()
            }
            Accessible.role: Accessible.Button; Accessible.name: overflow ? "More workspaces, " + modelData.overflow.length + ", open Windows" : "Workspace " + workspaceId + ", " + occupancy + " windows"
            Accessible.selected: current
            Accessible.onPressAction: choose()
        }
    }
}
