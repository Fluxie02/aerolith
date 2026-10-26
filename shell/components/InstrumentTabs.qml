import QtQuick
import qs.core

// One continuous route with a single moving registration, like the workspace
// arc. The owner retains selection, keys and actions; this view never takes focus.
Item {
    id: route
    required property var entries
    property int currentIndex: 0
    property bool arc: false
    property bool shortcuts: false
    property bool compact: false
    signal chosen(int index)
    readonly property int count: entries.length
    readonly property real stride: width / Math.max(1, count)
    readonly property real stationHeight: Theme.du(shortcuts ? (compact ? 44 : 55) : 36)
    readonly property real depth: arc ? Theme.du(10) : 0
    readonly property real inset: Theme.du(4)
    implicitHeight: stationHeight + depth + Theme.du(13)

    function rise(index) {
        const u = count > 1 ? 2 * index / (count - 1) - 1 : 0;
        return depth * u * u;
    }

    Canvas {
        id: track
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.strokeStyle = Theme.grid; c.lineWidth = Theme.border;
            c.beginPath();
            for (let x = 0; x <= width; x += 2) {
                const u = route.count > 1 ? (x - route.stride / 2) / (width - route.stride) * 2 - 1 : 0;
                const y = route.stationHeight + route.depth * u * u + Theme.du(5);
                if (x === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.stroke();
            c.beginPath();
            for (let i = 0; i < route.count; i++) {
                const x = route.stride * (i + .5);
                const y = route.stationHeight + route.rise(i) + Theme.du(5);
                c.moveTo(x, y); c.lineTo(x, y + Theme.du(5));
                if (Theme.insane && i < route.count - 1) {
                    const mid = x + route.stride / 2;
                    c.moveTo(mid, y); c.lineTo(mid, y + Theme.du(3));
                }
            }
            c.stroke();
        }
        Connections {
            target: route
            function onCountChanged() { track.requestPaint(); }
            function onDepthChanged() { track.requestPaint(); }
            function onStationHeightChanged() { track.requestPaint(); }
        }
        Connections {
            target: Theme
            function onPaletteChanged() { track.requestPaint(); }
            function onInsaneChanged() { track.requestPaint(); }
        }
        Connections {
            target: track.Window.window
            function onVisibleChanged() { if (track.Window.window.visible) track.requestPaint(); }
        }
    }

    Item {
        id: registration
        visible: route.currentIndex >= 0 && route.currentIndex < route.count
        x: Math.max(0, route.currentIndex) * route.stride + route.inset
        y: route.rise(Math.max(0, route.currentIndex))
        width: Math.max(0, route.stride - 2 * route.inset)
        height: route.stationHeight
        Behavior on x { enabled: Theme.travel; XAnimator { id: routeX; duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: Theme.travel; YAnimator { id: routeY; duration: Theme.normal; easing.type: Easing.OutCubic } }
        Connections {
            target: Theme
            function onTravelChanged() { if (!Theme.travel) { routeX.complete(); routeY.complete(); } }
        }
        Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.surface2; border.color: Theme.signal; border.width: Theme.border }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + Theme.du(2)
            width: Theme.du(6); height: width; radius: width / 2; color: Theme.signal
        }
    }

    Repeater {
        model: route.entries
        delegate: Item {
            id: station
            required property var modelData
            required property int index
            readonly property bool selected: route.currentIndex === index
            x: index * route.stride + route.inset
            y: route.rise(index)
            width: Math.max(0, route.stride - 2 * route.inset)
            height: route.stationHeight
            Rectangle {
                anchors.fill: parent
                color: pointer.containsMouse && !station.selected ? Theme.surface : "transparent"
                border.color: pointer.containsMouse && !station.selected ? Theme.grid : "transparent"
                border.width: Theme.border
                radius: Theme.radius
            }
            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.du(10)
                spacing: Theme.du(3)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: station.modelData.label === "AI" ? "AI" : station.modelData.label.charAt(0) + station.modelData.label.slice(1).toLowerCase()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: station.selected ? Theme.signal : pointer.containsMouse ? Theme.text : Theme.textDim
                    font.family: Theme.sans; font.pixelSize: route.shortcuts ? Theme.fontMd : Theme.fontSm
                    font.weight: station.selected ? Font.DemiBold : Font.Normal
                    Behavior on color { enabled: Theme.animate; ColorAnimation { id: colorFade; duration: Theme.fast } }
                    Connections {
                        target: Theme
                        function onAnimateChanged() { if (!Theme.animate) colorFade.complete(); }
                    }
                }
                Text {
                    visible: route.shortcuts
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: station.modelData.key === "F1" ? "F1" : "Ctrl+" + station.modelData.key
                    textFormat: Text.PlainText
                    color: Theme.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
            }
            MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: route.chosen(station.index)
            }
            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.label + (route.shortcuts ? ", " + (modelData.key === "F1" ? "F1" : "Ctrl+" + modelData.key) : "")
            Accessible.selected: selected
            Accessible.onPressAction: route.chosen(index)
        }
    }
}
