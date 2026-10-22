import QtQuick
import qs.core

// Per-core utilisation as a bus of vertical bars with a caution line.
// Unknown cores (no delta yet) are drawn as hollow frames.
Item {
    id: bus
    property var cores: []
    property real caution: 85

    readonly property int n: Math.max(1, cores.length)
    readonly property real barW: Math.max(Theme.px(3), (width - (n - 1) * Theme.px(2)) / n)

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.grid
        border.width: Theme.border
    }
    Rectangle {
        y: Math.round(bus.height * (1 - bus.caution / 100))
        width: bus.width
        height: Theme.border
        color: Theme.caution
    }
    Row {
        anchors.fill: parent
        anchors.margins: Theme.px(2)
        spacing: Theme.px(2)
        Repeater {
            model: bus.cores
            delegate: Item {
                required property var modelData
                width: Math.floor(bus.barW) - 1
                height: parent.height
                readonly property bool known: modelData !== null && modelData !== undefined && isFinite(modelData)
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.known ? Math.max(1, parent.height * modelData / 100) : parent.height
                    color: !parent.known ? "transparent" : modelData >= bus.caution ? Theme.caution : Theme.signal
                    border.color: parent.known ? "transparent" : Theme.grid
                    border.width: Theme.border
                }
            }
        }
    }
}
