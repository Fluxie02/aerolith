import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// Application playback stream: name, what it plays, volume, current route.
Rectangle {
    id: row
    property var node: null
    property bool selected: false
    signal picked
    signal reroute

    readonly property bool bound: node && node.audio && node.ready
    readonly property real pct: bound ? node.audio.volume * 100 : NaN
    readonly property var targets: Audio.streamTargets(node)
    readonly property string mediaName: node && node.properties ? (node.properties["media.name"] || "") : ""

    implicitHeight: Math.round(Theme.rowHeight * 1.9)
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
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.px(8)
        spacing: Theme.px(4)
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: Audio.streamLabel(row.node)
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.displaySans
                font.pixelSize: Theme.fontSm
                elide: Text.ElideRight
            }
            Text {
                text: row.bound && row.node.audio.muted ? "MUTE" : isNaN(row.pct) ? "N/A" : Math.round(row.pct) + "%"
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
        }
        Text {
            visible: row.mediaName !== ""
            Layout.fillWidth: true
            text: row.mediaName
            textFormat: Text.PlainText
            color: Theme.textDim
            font.family: Theme.sans
            font.pixelSize: Theme.fontXs
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            TapeGauge {
                Layout.fillWidth: true
                implicitHeight: Theme.px(10)
                value: row.pct
                max: Config.audio.maxVolume
                showCaret: false
            }
            Text {
                Layout.maximumWidth: row.width * 0.52
                text: "→ " + (row.targets.length ? row.targets.map(t => Audio.label(t)).join(", ") : "unlinked")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.signal
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.reroute()
                }
            }
        }
    }
}
