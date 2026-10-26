import QtQuick
import qs.core

// Horizontal tape gauge with graduations and a caret, after avionics tape
// instruments. value in [min, max]; null/NaN renders as an N/A hatch so an
// unavailable metric is never mistaken for zero.
Item {
    id: root
    property var value: NaN
    property real min: 0
    property real max: 100
    property real caution: NaN
    property real critical: NaN
    property string status: "nominal"
    property bool showCaret: true
    implicitHeight: Theme.px(14)
    implicitWidth: Theme.px(160)

    readonly property bool known: !isNaN(value) && value !== null && isFinite(value)
    readonly property real fraction: known ? Math.max(0, Math.min(1, (value - min) / (max - min))) : 0
    readonly property color fillColor: status === "caution" ? Theme.caution : status === "critical" ? Theme.critical : Theme.signal

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(root.height * 0.55)
        color: Theme.surface2
        border.color: Theme.grid
        border.width: Theme.border

        Rectangle {
            visible: root.known
            x: Theme.border
            y: Theme.border
            height: parent.height - 2 * Theme.border
            width: Math.max(0, (parent.width - 2 * Theme.border) * root.fraction)
            color: Theme.lowEffects ? root.fillColor : Theme.alpha(root.fillColor, 0.75)
            Behavior on width {
                enabled: Theme.travel
                NumberAnimation {
                    duration: Theme.normal
                }
            }
        }

        // N/A hatch
        Row {
            visible: !root.known
            anchors.fill: parent
            anchors.margins: Theme.border
            clip: true
            spacing: Theme.px(5)
            Repeater {
                model: Math.ceil(root.width / Theme.px(6))
                Rectangle {
                    width: Theme.border
                    height: parent.height
                    color: Theme.grid
                }
            }
        }
    }

    // Graduations every 10 %, long ticks at 50 %.
    Repeater {
        model: 11
        delegate: Rectangle {
            required property int index
            x: Math.round(index / 10 * (root.width - Theme.border))
            y: track.height
            width: Theme.border
            height: index % 5 === 0 ? root.height - track.height : Math.round((root.height - track.height) / 2)
            color: Theme.grid
        }
    }

    // Threshold marks
    Rectangle {
        visible: !isNaN(root.caution)
        x: Math.round((root.caution - root.min) / (root.max - root.min) * root.width)
        y: 0
        width: Theme.px(2)
        height: track.height
        color: Theme.caution
    }
    Rectangle {
        visible: !isNaN(root.critical)
        x: Math.round((root.critical - root.min) / (root.max - root.min) * root.width)
        y: 0
        width: Theme.px(2)
        height: track.height
        color: Theme.critical
    }

    // Caret
    Text {
        textFormat: Text.PlainText
        visible: root.showCaret && root.known
        text: "▲"
        color: root.fillColor
        font.pixelSize: Math.max(6, root.height - track.height + 2)
        x: Math.round(root.fraction * root.width - width / 2)
        y: track.height - 2
    }
}
