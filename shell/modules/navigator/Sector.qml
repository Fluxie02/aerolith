import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components

// One workspace sector of the Spatial Navigator: a scaled map of the
// display with each window drawn at its position.
Item {
    id: sector
    property var sector: ({
            id: 0,
            windows: [],
            focused: false
        })
    property var monitor: null
    property int headerHeight: Theme.rowHeight
    property bool selected: false
    property string selectedWindow: ""
    property string closeArmed: ""
    property var filterFn: w => true
    signal sectorClicked
    signal windowClicked(var w)

    readonly property real mapW: width
    readonly property real mapH: height - headerHeight
    readonly property bool hasGeometry: monitor !== null && monitor.width > 0

    // Header
    Row {
        id: head
        height: sector.headerHeight
        spacing: Theme.gap
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "WS " + sector.sector.id
            color: sector.sector.focused ? Theme.signal : sector.selected ? Theme.text : Theme.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
            font.weight: Font.DemiBold
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: sector.sector.windows.length + (sector.sector.windows.length === 1 ? " window" : " windows") + (sector.sector.focused ? " · current" : "")
        }
    }

    Rectangle {
        id: map
        y: sector.headerHeight
        width: sector.mapW
        height: sector.mapH
        color: Theme.bg
        border.color: sector.selected ? Theme.signal : Theme.grid
        border.width: sector.selected ? Theme.px(2) : Theme.border
        radius: Theme.radius
        clip: true

        // Map grid
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: Math.round(map.width * (index + 1) / 4)
                width: Theme.border
                height: map.height
                color: Theme.alpha(Theme.grid, Theme.gridMinorOpacity)
            }
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                y: Math.round(map.height * (index + 1) / 4)
                height: Theme.border
                width: map.width
                color: Theme.alpha(Theme.grid, Theme.gridMinorOpacity)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sector.sectorClicked()
        }

        Repeater {
            model: sector.sector.windows
            delegate: Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool placed: sector.hasGeometry && modelData.at !== null && modelData.size !== null
                readonly property real sx: map.width / (sector.hasGeometry ? sector.monitor.width : 1)
                readonly property real sy: map.height / (sector.hasGeometry ? sector.monitor.height : 1)
                readonly property bool isSelected: modelData.address === sector.selectedWindow
                readonly property bool matchesFilter: sector.filterFn(modelData)
                readonly property bool armed: modelData.address === sector.closeArmed

                // Without geometry, stack tiles as a list.
                x: placed ? Math.round((modelData.at[0] - sector.monitor.x) * sx) + 2 : Theme.px(4)
                y: placed ? Math.round((modelData.at[1] - sector.monitor.y) * sy) + 2 : Theme.px(4) + index * (Theme.rowHeight + Theme.px(4))
                width: placed ? Math.max(Theme.px(24), Math.round(modelData.size[0] * sx) - 4) : map.width - Theme.px(8)
                height: placed ? Math.max(Theme.px(18), Math.round(modelData.size[1] * sy) - 4) : Theme.rowHeight
                z: modelData.floating ? 2 : 1
                color: armed ? Theme.alpha(Theme.critical, 0.2) : isSelected ? Theme.alpha(Theme.signal, 0.12) : Theme.surface2
                border.color: armed ? Theme.critical : isSelected ? Theme.signal : modelData.active ? Theme.text : Theme.grid
                border.width: isSelected || armed ? Theme.px(2) : Theme.border
                opacity: matchesFilter ? 1 : 0.25
                radius: Theme.radius
                clip: true

                Loader {
                    anchors.fill: parent
                    anchors.margins: Theme.border
                    active: Config.navigator.thumbnails && tile.modelData.toplevel && tile.modelData.toplevel.wayland !== null
                    sourceComponent: ScreencopyView {
                        captureSource: tile.modelData.toplevel.wayland
                        live: false
                        Component.onCompleted: captureFrame()
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.px(4)
                    spacing: Theme.px(1)
                    Row {
                        spacing: Theme.px(4)
                        width: parent.width
                        AppGlyph {
                            size: Math.min(Theme.px(16), tile.height - Theme.px(8))
                            icon: tile.modelData.appId
                            fallback: tile.modelData.appId
                            visible: tile.height > Theme.px(20)
                        }
                        Text {
                            text: (tile.modelData.active ? "● " : "") + tile.modelData.appId.toUpperCase()
                            color: tile.modelData.active ? Theme.signal : Theme.textDim
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                            width: parent.width - x
                        }
                    }
                    Text {
                        visible: tile.height > Theme.px(34)
                        width: parent.width
                        text: tile.modelData.title
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXs
                        wrapMode: Text.Wrap
                        maximumLineCount: Math.max(1, Math.floor((tile.height - Theme.px(24)) / (Theme.fontXs + 4)))
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sector.windowClicked(tile.modelData)
                }
            }
        }

        Label {
            visible: sector.sector.windows.length === 0
            anchors.centerIn: parent
            text: "EMPTY"
        }
    }
}
