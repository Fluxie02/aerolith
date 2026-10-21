import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// Transient notices (action results) and, when AEROLITH is the notification
// server, notification popups. The surface is only as large as its content
// and takes no keyboard focus, so it never blocks other windows.
PanelWindow {
    id: column

    readonly property var notices: Ui.notices
    readonly property var popups: Notifications.popups
    readonly property bool hasContent: notices.length > 0 || popups.length > 0

    screen: Ui.screen
    visible: hasContent && Ui.screen !== null
    color: "transparent"
    anchors {
        right: true
        top: Config.strip.edge === "top"
        bottom: Config.strip.edge === "bottom"
    }
    margins {
        right: Theme.pad
        top: Theme.pad
        bottom: Theme.pad
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: Theme.px(380)
    implicitHeight: Math.max(1, stack.implicitHeight)
    WlrLayershell.namespace: "aerolith-notices"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: stack
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: column.popups
            delegate: NoticeCard {
                required property var modelData
                width: stack.width
                severity: modelData.urgency === 2 ? "error" : "info"
                code: "NTF"
                message: modelData.summary || modelData.appName
                detail: (modelData.appName ? modelData.appName + " · " : "") + (modelData.body || "")
                lifetime: Config.notifications.popupTimeoutMs
                onDismissed: Notifications.dropPopup(modelData)
            }
        }
        Repeater {
            model: column.notices
            delegate: NoticeCard {
                required property var modelData
                width: stack.width
                severity: modelData.severity
                code: modelData.severity === "ok" ? "OK" : modelData.severity === "error" ? "FAULT" : modelData.severity === "caution" ? "CAUT" : "INFO"
                message: modelData.message
                detail: modelData.detail
                lifetime: modelData.severity === "error" || modelData.severity === "caution" ? 8000 : 3500
                onDismissed: Ui.dismiss(modelData.id)
            }
        }
    }

    component NoticeCard: Rectangle {
        id: card
        property string severity: "info"
        property string code: "INFO"
        property string message: ""
        property string detail: ""
        property int lifetime: 4000
        signal dismissed

        readonly property color tone: severity === "error" ? Theme.critical : severity === "caution" ? Theme.caution : severity === "ok" ? Theme.signal : Theme.textDim
        implicitHeight: body.implicitHeight + Theme.pad * 2
        color: Theme.surface
        border.color: Theme.grid
        border.width: Theme.border
        radius: Theme.radius

        Rectangle {
            width: Theme.px(3)
            height: parent.height
            color: card.tone
        }
        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
            anchors.leftMargin: Theme.pad + Theme.px(3)
            spacing: Theme.px(2)
            Row {
                spacing: Theme.gap
                Text {
                    text: card.code
                    color: card.tone
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.DemiBold
                }
                Text {
                    width: body.width - x
                    text: card.message
                    color: Theme.text
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: card.detail !== ""
                width: parent.width
                text: card.detail
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
        Timer {
            running: true
            interval: card.lifetime
            onTriggered: card.dismissed()
        }
        MouseArea {
            anchors.fill: parent
            onClicked: card.dismissed()
        }
    }
}
