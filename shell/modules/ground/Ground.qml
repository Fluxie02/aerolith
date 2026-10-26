import QtQuick
import qs.core
import qs.components

Rectangle {
    color: Theme.bg
    clip: true
    InstrumentField { anchors.fill: parent }
    Instrumentation { anchors.fill: parent }
    Component.onCompleted: Theme.ignite()
}
