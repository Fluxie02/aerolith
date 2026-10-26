import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components

// A workspace registered along Limb's shallow arc. The small map retains
// real geometry; application titles are always horizontal and readable.
Item {
    id: sector
    property var sector: ({id:0, windows:[], focused:false})
    property var monitor: null
    property int headerHeight: Theme.rowHeight
    property bool selected: false
    property string selectedWindow: ""
    property string closeArmed: ""
    property var filterFn: w => true
    signal sectorClicked
    signal windowClicked(var w)
    Bezel { anchors.fill: parent; showHeader: false; active: sector.selected }
    Rectangle { width: parent.width; height: Theme.px(3); color: sector.sector.focused ? Theme.signal : Theme.grid }
    Text {
        x: Theme.du(12); y: Theme.du(15)
        text: "WS " + sector.sector.id; textFormat: Text.PlainText
        color: sector.selected ? Theme.signal : Theme.text
        font.family: Theme.mono; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: Theme.du(12); y: Theme.du(17)
        text: sector.sector.focused ? "ACTIVE" : sector.sector.windows.length + " WIN"
        textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
    }
    MouseArea { anchors.fill: parent; onClicked: sector.sectorClicked() }
    Rectangle {
        id: map
        x: Theme.du(12); y: Theme.du(47); width: parent.width - 2*x
        height: Math.max(0, Math.min(width * .62, sector.height * (sector.height < Theme.du(260) ? .24 : .34)))
        color: Theme.bg; border.color: Theme.grid; clip: true
        Repeater {
            model: sector.sector.windows
            delegate: Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool placed: sector.monitor !== null && sector.monitor.width > 0 && modelData.at !== null && modelData.size !== null
                x: placed ? (modelData.at[0] - sector.monitor.x) * map.width / sector.monitor.width + 2 : 4
                y: placed ? (modelData.at[1] - sector.monitor.y) * map.height / sector.monitor.height + 2 : 6 + index * map.height / Math.max(1, sector.sector.windows.length)
                width: placed ? Math.max(12, modelData.size[0] * map.width / sector.monitor.width - 4) : map.width - 12
                height: placed ? Math.max(12, modelData.size[1] * map.height / sector.monitor.height - 4) : map.height / Math.max(1, sector.sector.windows.length) - 12
                color: modelData.address === sector.selectedWindow ? (Theme.lowEffects ? Theme.surface2 : Theme.alpha(Theme.signal, .15)) : Theme.surface2
                border.color: modelData.address === sector.closeArmed ? Theme.critical : modelData.address === sector.selectedWindow ? Theme.signal : Theme.grid
                opacity: sector.filterFn(modelData) ? 1 : Theme.disabledOpacity
                z: modelData.floating ? 2 : 1
                clip: true
                Loader {
                    anchors.fill: parent
                    active: Config.navigator.thumbnails && tile.modelData.toplevel && tile.modelData.toplevel.wayland !== null
                    sourceComponent: ScreencopyView {
                        captureSource: tile.modelData.toplevel.wayland
                        live: false
                        Component.onCompleted: captureFrame()
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: sector.windowClicked(tile.modelData) }
            }
        }
        Text {
            anchors.centerIn: parent; visible: sector.sector.windows.length === 0
            text: "—"; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
    }
    ListView {
        id: names
        x: map.x; y: map.y + map.height + Theme.du(22); width: map.width
        height: Math.max(0, sector.height - y - Theme.du(12))
        model: sector.sector.windows
        clip: true; spacing: Theme.du(18)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: {
            for (var i = 0; i < sector.sector.windows.length; i++)
                if (sector.sector.windows[i].address === sector.selectedWindow) return i;
            return -1;
        }
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Item {
            id: entry
            required property var modelData
            width: names.width; height: body.implicitHeight + Theme.du(12)
            opacity: sector.filterFn(modelData) ? 1 : Theme.disabledOpacity
            Rectangle { width: Theme.border; height: parent.height; visible: entry.modelData.address === sector.selectedWindow; color: entry.modelData.address === sector.closeArmed ? Theme.critical : Theme.signal }
            Column {
                id: body; x: Theme.px(4); width: parent.width - x; spacing: Theme.du(8)
                Text {
                    width: parent.width; text: entry.modelData.appId.toUpperCase(); textFormat: Text.PlainText
                    color: entry.modelData.address === sector.selectedWindow ? Theme.signal : Theme.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs; elide: Text.ElideRight
                }
                Text {
                    width: parent.width; text: entry.modelData.title; textFormat: Text.PlainText
                    color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.fontMd + Theme.px(1)
                    wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
                }
            }
            MouseArea { anchors.fill: parent; onClicked: sector.windowClicked(entry.modelData) }
        }
        Text {
            visible: names.count === 0; text: "UNASSIGNED"; textFormat: Text.PlainText
            color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
        }
    }
}
