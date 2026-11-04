import QtQuick
import qs.core
import qs.components

Rectangle {
    id: ground
    property var profile: Theme
    color: profile.bg
    clip: true
    InstrumentField { profile: ground.profile; anchors.fill: parent }
    Instrumentation { profile: ground.profile; anchors.fill: parent }
    Component.onCompleted: Theme.ignite()
}
