import QtQuick
import qs.core

Rectangle {
    id: action
    property var profile: Theme
    property string text: ""
    property bool chosen: false
    property var tabNext: null
    property var tabPrevious: null
    signal triggered()
    signal focused(var item)
    onActiveFocusChanged: if (activeFocus) focused(action)
    implicitWidth: caption.implicitWidth + Theme.du(24)
    implicitHeight: Math.max(Theme.du(36), caption.implicitHeight + Theme.du(16))
    width: implicitWidth; height: implicitHeight
    activeFocusOnTab: true
    radius: Theme.du(4)
    color: chosen || pointer.containsMouse ? profile.surface2 : profile.bg
    border.color: activeFocus ? profile.text : chosen ? profile.signal : profile.grid
    border.width: activeFocus ? Theme.px(2) : Theme.border
    opacity: enabled ? 1 : .55
    function activate() { if (enabled) triggered(); }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()
    Keys.onTabPressed: event => { if (tabNext) tabNext.forceActiveFocus(); else event.accepted = false; }
    Keys.onBacktabPressed: event => { if (tabPrevious) tabPrevious.forceActiveFocus(); else event.accepted = false; }
    Text {
        id: caption
        anchors.centerIn: parent
        text: action.text; textFormat: Text.PlainText
        color: action.chosen ? action.profile.signal : action.profile.text
        font.family: Theme.sans; font.pixelSize: Theme.fontSm
    }
    Rectangle { visible: action.chosen; width: Theme.du(3); height: parent.height - Theme.du(12); y: Theme.du(6); color: action.profile.signal }
    MouseArea {
        id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { action.forceActiveFocus(); action.activate(); }
    }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: activate()
}
