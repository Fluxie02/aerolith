import QtQuick
import qs.core

TextInput {
    id: input
    property var profile: Theme
    property string label: ""
    signal focused(var item)
    width: parent.width; height: Math.max(Theme.du(40), font.pixelSize + Theme.du(20))
    leftPadding: Theme.du(10); rightPadding: Theme.du(10); verticalAlignment: TextInput.AlignVCenter
    color: profile.text; selectionColor: profile.signal; selectedTextColor: profile.bg
    font.family: Theme.sans; font.pixelSize: Theme.fontSm
    selectByMouse: true; activeFocusOnTab: true; clip: true; maximumLength: 4096
    onActiveFocusChanged: if (activeFocus) focused(input)
    Rectangle { anchors.fill: parent; z: -1; color: input.profile.bg; border.color: input.activeFocus ? input.profile.signal : input.profile.grid; radius: Theme.du(3) }
    Text { anchors.fill: parent; anchors.leftMargin: Theme.du(10); verticalAlignment: Text.AlignVCenter; visible: input.text === "" && !input.activeFocus; text: input.label; textFormat: Text.PlainText; color: input.profile.textDim; font: input.font }
    Accessible.name: label
}
