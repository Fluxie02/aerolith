import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

PanelWindow {
    id: column
    required property var s
    screen: Ui.screen
    visible: Ui.screen !== null && (Ui.notices.length > 0 || Notifications.popups.length > 0)
    color: "transparent"
    anchors { right: true; top: Config.strip.edge === "top"; bottom: Config.strip.edge === "bottom" }
    margins { right: s.px(32); top: Theme.stripHeight + s.px(24); bottom: Theme.stripHeight + s.px(24) }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: s.px(380)
    implicitHeight: Math.max(1, stack.implicitHeight)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aerolith-notices"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Column {
        id: stack; width: parent.width; spacing: s.px(12)
        Repeater {
            model: Notifications.popups
            delegate: Annotation {
                required property var modelData
                s: column.s; width: stack.width
                message: modelData.summary || modelData.appName
                detail: modelData.body || ""
                severity: modelData.urgency === 2 ? "error" : "info"
                onDismissed: Notifications.dropPopup(modelData)
                Timer { running: true; interval: Config.notifications.popupTimeoutMs; onTriggered: parent.dismissed() }
            }
        }
        Repeater {
            model: Ui.notices
            delegate: Annotation {
                required property var modelData
                s: column.s; width: stack.width
                message: modelData.message; detail: modelData.detail; severity: modelData.severity
                onDismissed: Ui.dismiss(modelData.id)
                Timer { running: true; interval: Math.max(1, (modelData.severity === "error" || modelData.severity === "caution" ? 8000 : 3500) - (Date.now() - modelData.at)); onTriggered: parent.dismissed() }
            }
        }
    }
    component Annotation: Rectangle {
        id: note
        required property var s
        property string message: ""
        property string detail: ""
        property string severity: "info"
        signal dismissed()
        readonly property color tone: severity === "error" ? s.error : severity === "caution" ? s.warning : severity === "ok" ? s.success : s.accent
        height: content.implicitHeight + s.px(40)
        color: s.surface; border.width: 1; border.color: s.line
        Rectangle { width: s.px(4); height: parent.height; color: note.tone }
        Column {
            id: content; x: s.px(24); y: s.px(20); width: parent.width-s.px(60); spacing: s.px(10)
            Ink { s: note.s; text: note.severity === "ok" ? "Done" : note.severity === "error" ? "Error" : note.severity === "caution" ? "Caution" : "Notice"; color: note.tone; font.pixelSize: s.small }
            Ink { s: note.s; width: parent.width; text: note.message; wrapMode: Text.WordWrap; maximumLineCount: 3; font.pixelSize: s.body }
            Ink { s: note.s; visible: note.detail !== ""; width: parent.width; text: note.detail; wrapMode: Text.WordWrap; maximumLineCount: 4; color: s.dim; font.pixelSize: s.small }
        }
        Ink {
            s: note.s; anchors.right: parent.right; anchors.rightMargin: s.px(16); y: s.px(16); text: "×"; color: s.dim; font.pixelSize: s.px(20)
            MouseArea { anchors.fill: parent; anchors.margins: -s.px(8); onClicked: note.dismissed() }
        }
    }
}
