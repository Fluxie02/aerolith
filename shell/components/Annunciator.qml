import QtQuick
import qs.core

// Flight Strip annunciator cell: a short code, optional value, and a
// status colour (nominal | caution | critical | active | unknown).
// Caution and critical cells get a tinted plate so they read at a glance.
Item {
    id: root
    property string code: ""
    property string value: ""
    property string status: "nominal"
    property bool interactive: true
    signal clicked(var mouse)
    signal wheel(var wheel)

    readonly property bool raised: status === "caution" || status === "critical"
    readonly property color tone: status === "nominal" ? Theme.textDim : Theme.stateColor(status)
    implicitWidth: row.implicitWidth + Theme.pad
    implicitHeight: parent ? parent.height : Theme.stripHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Theme.px(4)
        anchors.bottomMargin: Theme.px(4)
        color: root.raised ? (Theme.lowEffects ? Theme.surface2 : Theme.alpha(root.tone, 0.14)) : mouse.containsMouse && root.interactive ? Theme.surface2 : "transparent"
        border.color: root.raised ? root.tone : "transparent"
        border.width: Theme.border
        radius: Theme.radius
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.px(5)
        Text {
            textFormat: Text.PlainText
            text: root.code
            color: root.tone
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            textFormat: Text.PlainText
            visible: root.value !== ""
            text: root.value
            color: root.status === "nominal" ? Theme.text : root.tone
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
}
