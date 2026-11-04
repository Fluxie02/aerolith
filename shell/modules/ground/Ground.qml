import QtQuick
import qs.core
import qs.components

Rectangle {
    id: ground
    property var profile: Theme
    color: profile.bg
    clip: true
    Item {
        anchors.fill: parent
        opacity: ground.profile.hideContent ? 0 : 1
        visible: opacity > 0
        enabled: !ground.profile.hideContent
        Behavior on opacity {
            enabled: Theme.animate && targetValue < 1
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        InstrumentField { profile: ground.profile; anchors.fill: parent }
        Instrumentation { profile: ground.profile; anchors.fill: parent }
    }
    Component.onCompleted: Theme.ignite()
}
