import QtQuick
import qs.core

Rectangle {
    id: action
    property var profile: Theme
    property string text: ""
    property bool primary: false
    signal triggered()
    signal focused(var item)
    implicitWidth: caption.implicitWidth + Theme.du(28)
    implicitHeight: Math.max(Theme.du(38), caption.implicitHeight + Theme.du(18))
    width: implicitWidth; height: implicitHeight
    activeFocusOnTab: true
    color: primary ? profile.signal : pointer.containsMouse ? profile.surface2 : profile.bg
    border.color: activeFocus ? profile.text : primary ? profile.signal : profile.grid
    border.width: activeFocus ? Theme.px(2) : Theme.border; radius: Theme.du(3)
    opacity: enabled ? 1 : .6
    onActiveFocusChanged: if (activeFocus) focused(action)
    function activate() { if (enabled) triggered(); }
    Text {
        id: caption; anchors.centerIn: parent
        text: action.text; textFormat: Text.PlainText
        color: action.primary ? action.profile.bg : action.profile.text
        font.family: Theme.sans; font.pixelSize: Theme.fontSm
    }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { action.forceActiveFocus(); action.activate(); } }
    Accessible.role: Accessible.Button; Accessible.name: text
    Accessible.onPressAction: activate()
}
