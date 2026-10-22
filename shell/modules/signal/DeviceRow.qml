import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// Audio device row: default marker, name, volume tape, mute state.
Rectangle {
    id: row
    property var node: null
    property bool isDefault: false
    property bool preferred: false
    property bool selected: false
    signal picked
    signal makeDefault
    signal muteToggled

    readonly property bool bound: node && node.audio && node.ready
    readonly property real pct: bound ? node.audio.volume * 100 : NaN
    readonly property bool muted: bound ? node.audio.muted : false

    implicitHeight: Math.round(Theme.rowHeight * 1.7)
    color: selected ? Theme.surface2 : "transparent"
    border.color: selected ? Theme.signal : "transparent"
    border.width: Theme.border
    radius: Theme.radius

    Rectangle {
        width: Theme.px(2)
        height: parent.height - Theme.px(12)
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        visible: row.selected
        color: Theme.signal
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.picked()
        onDoubleClicked: row.makeDefault()
        onWheel: w => {
            if (!row.bound)
                return;
            const step = Config.audio.volumeStep * (w.angleDelta.y > 0 ? 1 : -1);
            row.node.audio.volume = Math.max(0, Math.min(Config.audio.maxVolume, Math.round(row.pct) + step)) / 100;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.px(8)
        spacing: Theme.px(5)
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Text {
                text: row.isDefault ? "◉" : "○"
                color: row.isDefault ? Theme.signal : Theme.textDim
                font.pixelSize: Theme.fontSm
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.makeDefault()
                }
            }
            Text {
                Layout.fillWidth: true
                text: Audio.label(row.node)
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.displaySans
                font.pixelSize: Theme.fontSm
                font.weight: row.isDefault ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                visible: row.preferred && !row.isDefault
                text: "PREFERRED"
                color: Theme.caution
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
            Text {
                text: row.muted ? "MUTE" : isNaN(row.pct) ? "N/A" : Math.round(row.pct) + "%"
                color: row.muted ? Theme.caution : Theme.text
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.muteToggled()
                }
            }
        }
        TapeGauge {
            Layout.fillWidth: true
            implicitHeight: Theme.px(10)
            value: row.muted ? NaN : row.pct
            max: Config.audio.maxVolume
            caution: Config.audio.maxVolume > 100 ? 100 : NaN
            status: row.pct > 100 ? "caution" : "nominal"
            showCaret: false
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    if (row.bound)
                        row.node.audio.volume = Math.round(m.x / width * Config.audio.maxVolume) / 100;
                }
            }
        }
    }
}
