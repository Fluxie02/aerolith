import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// Visual stack of transient notices (action results) and notification
// popups. Shown by the notice column surface, and by the Deck while it is
// open so notices stay above it.
//
// Contracts (see ARCHITECTURE.md): records come from Ui.notices and
// Notifications.popups through keyed models, so a card lives as long as its
// record; expiry is owned by those services, not by the cards. Clicking a
// popup calls Notifications.activate(n); clicking a notice calls
// Ui.dismiss(id). Notification text is untrusted: plain text only.
Item {
    id: column

    readonly property var notices: Ui.notices
    readonly property var popups: Notifications.popups
    readonly property bool hasContent: notices.length > 0 || popups.length > 0

    implicitWidth: Theme.px(380)
    implicitHeight: stack.implicitHeight

    Column {
        id: stack
        width: parent.width
        spacing: Theme.du(12)

        Repeater {
            model: ScriptModel {
                values: column.popups
            }
            delegate: NoticeCard {
                required property var modelData
                width: stack.width
                severity: modelData.urgency === 2 ? "error" : "info"
                code: "NTF"
                message: modelData.summary || modelData.appName
                detail: (modelData.appName ? modelData.appName + " · " : "") + (modelData.body || "")
                onDismissed: Notifications.activate(modelData)
            }
        }
        Repeater {
            model: ScriptModel {
                values: column.notices
                objectProp: "id"
            }
            delegate: NoticeCard {
                required property var modelData
                width: stack.width
                severity: modelData.severity
                code: modelData.severity === "ok" ? "OK" : modelData.severity === "error" ? "FAULT" : modelData.severity === "caution" ? "CAUT" : "INFO"
                message: modelData.message
                detail: modelData.detail
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
        signal dismissed

        readonly property color tone: severity === "error" ? Theme.critical : severity === "caution" ? Theme.caution : severity === "ok" ? Theme.signal : Theme.textDim
        implicitHeight: body.implicitHeight + Theme.du(32)
        color: Theme.surface
        border.color: Theme.grid
        border.width: Theme.border
        radius: Theme.radius
        Rectangle {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: Theme.radius; anchors.bottomMargin: Theme.px(2)
            width: Theme.du(40); height: Theme.border; color: card.tone
        }
        Rectangle {
            width: Theme.px(2)
            y: Theme.radius; height: Math.max(0, parent.height - 2 * y); radius: width / 2
            color: card.tone
        }
        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.du(16)
            anchors.leftMargin: Theme.du(20)
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
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.displaySans
                    font.pixelSize: Theme.fontMd
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: card.detail !== ""
                width: parent.width
                text: card.detail
                textFormat: Text.PlainText
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: card.dismissed()
        }
    }
}
