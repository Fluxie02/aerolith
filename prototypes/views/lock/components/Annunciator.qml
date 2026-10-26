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
    property bool compact: false
    property real valueLimit: Theme.px(compact ? 88 : 210)
    signal clicked(var mouse)
    signal wheel(var wheel)

    readonly property bool raised: status === "caution" || status === "critical"
    readonly property color tone: status === "nominal" ? Theme.textDim : Theme.stateColor(status)
    implicitWidth: (compact ? Math.max(codeText.implicitWidth, valueText.width) : codeText.implicitWidth + (value !== "" ? Theme.px(5) + valueText.width : 0)) + Theme.pad
    implicitHeight: parent ? parent.height : Theme.stripHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.compact ? Theme.border : Theme.px(4)
        anchors.bottomMargin: root.compact ? Theme.border : Theme.px(4)
        color: root.raised ? (Theme.lowEffects ? Theme.surface2 : Theme.alpha(root.tone, 0.14)) : mouse.containsMouse && root.interactive ? Theme.surface2 : "transparent"
        border.color: root.raised ? root.tone : "transparent"
        border.width: Theme.border
        radius: Theme.radius
    }

    Item {
        anchors.fill: parent
        Text {
            id: codeText
            textFormat: Text.PlainText
            text: root.code
            color: root.tone
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            font.weight: Font.DemiBold
            font.letterSpacing: root.compact ? 0 : 0.8
            x: root.compact ? (parent.width - width) / 2 : Theme.pad / 2
            y: root.compact && root.value !== "" ? (parent.height - height - valueText.height) / 2 : (parent.height - height) / 2
        }
        Text {
            id: valueText
            textFormat: Text.PlainText
            visible: root.value !== ""
            text: root.value
            width: Math.min(implicitWidth, root.valueLimit)
            elide: Text.ElideRight
            color: root.status === "nominal" ? Theme.text : root.tone
            font.family: Theme.mono
            font.pixelSize: root.compact ? Theme.fontXs : Theme.fontSm
            x: root.compact ? (parent.width - width) / 2 : codeText.x + codeText.width + Theme.px(5)
            y: root.compact ? codeText.y + codeText.height : (parent.height - height) / 2
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
