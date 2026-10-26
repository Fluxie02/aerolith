import QtQuick
import qs.core

// Schema-driven controls. SettingsBay owns validation and keyboard behaviour.
Item {
    id: control
    required property var setting
    required property var value
    property bool selected: false
    property bool editing: false
    property string draft: ""
    signal stepped(int direction)
    signal choicePicked(var value)
    signal editRequested()
    readonly property bool numeric: setting.type === "int" || setting.type === "number"
    readonly property color ink: editing ? Theme.caution : selected ? Theme.signal : Theme.text
    implicitHeight: setting.type === "enum" ? choices.implicitHeight : numeric ? Theme.du(49) : Theme.du(34)
    Connections {
        target: Theme
        function onTravelChanged() { if (!Theme.travel) knobMotion.complete(); }
    }

    Row {
        visible: control.setting.type === "bool"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.du(12)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.value ? "ON" : "OFF"
            textFormat: Text.PlainText
            color: control.ink
            font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        Rectangle {
            width: Theme.du(54); height: Theme.du(26)
            radius: height / 2
            color: Theme.bg; border.color: control.value ? control.ink : Theme.textDim
            border.width: Theme.border
            Rectangle {
                x: control.value ? parent.width - width - Theme.du(4) : Theme.du(4)
                y: Theme.du(4); width: Theme.du(15); height: parent.height - 2 * y
                radius: height / 2
                color: control.value ? control.ink : Theme.textDim
                Behavior on x { enabled: Theme.travel; XAnimator { id: knobMotion; duration: Theme.fast; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: control.stepped(1) }
        }
    }

    Flow {
        id: choices
        visible: control.setting.type === "enum"
        width: parent.width
        layoutDirection: Qt.RightToLeft
        spacing: Theme.du(4)
        Repeater {
            // Reverse for a right-aligned flow, preserving schema reading order.
            model: control.setting.values.slice().reverse()
            delegate: Rectangle {
                required property string modelData
                readonly property bool chosen: modelData === control.value
                width: Math.min(choices.width, choiceLabel.implicitWidth + Theme.du(18))
                height: Theme.du(30)
                radius: Theme.radius
                color: chosen ? Theme.surface2 : Theme.bg
                border.color: chosen ? control.ink : Theme.grid; border.width: Theme.border
                Text {
                    id: choiceLabel
                    anchors.fill: parent; anchors.margins: Theme.du(4)
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: modelData; textFormat: Text.PlainText
                    color: parent.chosen ? control.ink : Theme.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
                Rectangle { visible: parent.chosen; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - Theme.radius * 2; height: Theme.px(2); color: control.ink }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: control.choicePicked(modelData) }
            }
        }
    }

    Column {
        visible: control.numeric
        width: parent.width
        spacing: Theme.du(5)
        Row {
            width: parent.width
            Row {
                width: parent.width * .5
                height: Theme.du(25)
                Rectangle {
                    width: Theme.du(25); height: parent.height; radius: Theme.radius
                    color: Theme.bg; border.color: Theme.grid
                    Text { anchors.centerIn: parent; text: "−"; textFormat: Text.PlainText; color: control.ink; font.family: Theme.sans; font.pixelSize: Theme.fontMd }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: control.stepped(-1) }
                }
                Text {
                    width: Math.max(0, parent.width - Theme.du(50)); height: parent.height
                    text: String(control.value); textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    color: control.ink; font.family: Theme.mono; font.pixelSize: Theme.fontMd; elide: Text.ElideRight
                }
                Rectangle {
                    width: Theme.du(25); height: parent.height; radius: Theme.radius
                    color: Theme.bg; border.color: Theme.grid
                    Text { anchors.centerIn: parent; text: "+"; textFormat: Text.PlainText; color: control.ink; font.family: Theme.sans; font.pixelSize: Theme.fontMd }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: control.stepped(1) }
                }
            }
            Text {
                width: parent.width * .5; horizontalAlignment: Text.AlignRight
                text: String(control.setting.min) + " … " + String(control.setting.max); textFormat: Text.PlainText
                color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }
        }
        Item {
            width: parent.width; height: Theme.du(14)
            Rectangle { width: parent.width; height: Theme.border; y: Theme.du(5); color: Theme.grid }
            Repeater {
                model: Theme.insane ? 21 : 11
                Rectangle {
                    required property int index
                    x: (parent.width - width) * index / (Theme.insane ? 20 : 10)
                    width: Theme.border; height: Theme.du(index % 5 === 0 ? 11 : 6)
                    color: Theme.grid
                }
            }
            Rectangle {
                readonly property real fraction: control.numeric ? Math.max(0, Math.min(1, (Number(control.value) - control.setting.min) / (control.setting.max - control.setting.min))) : 0
                x: (parent.width - width) * fraction
                width: Theme.du(4); height: parent.height; color: control.ink
            }
        }
    }

    Rectangle {
        visible: control.setting.type === "string"
        width: parent.width; height: Theme.du(34)
        color: Theme.bg; radius: Theme.radius
        border.color: control.editing ? Theme.caution : control.selected ? Theme.signal : Theme.grid
        border.width: Theme.border
        Text {
            anchors.fill: parent; anchors.margins: Theme.du(8)
            verticalAlignment: Text.AlignVCenter
            text: control.editing ? control.draft + "▏" : control.value === "" ? "(empty)" : String(control.value)
            textFormat: Text.PlainText; elide: Text.ElideLeft
            color: control.ink; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: control.editRequested() }
    }
}
