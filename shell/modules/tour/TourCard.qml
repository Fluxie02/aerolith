import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

Bezel {
    id: card
    objectName: "tourCard"
    property int step: Tour.step
    property string stepName: ""
    property string heading: ""
    property string explanation: ""
    property string shortcut: ""
    contentPadding: Theme.du(24)
    titleHeight: Theme.du(48)
    title: "QUICK TOUR"
    status: ""
    width: Theme.du(420)
    height: headerHeight + contentPadding * 2 + copy.implicitHeight
    Column {
        id: copy
        width: parent.width
        spacing: Theme.du(16)
        Row {
            spacing: Theme.du(6)
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    objectName: "tourProgress-" + index
                    width: Theme.du(22); height: Theme.du(3)
                    color: index <= card.step ? card.profile.signal : card.profile.grid
                }
            }
        }
        Text {
            objectName: "tourStepLabel"
            width: parent.width; wrapMode: Text.WordWrap
            text: (card.step + 1) + " of 5 · " + card.stepName; textFormat: Text.PlainText
            font.family: Theme.mono; font.pixelSize: Theme.fontSm
            color: card.profile.signal
        }
        Text {
            objectName: "tourTitle"
            width: parent.width; wrapMode: Text.WordWrap
            text: card.heading; textFormat: Text.PlainText
            font.family: Theme.sans; font.pixelSize: Theme.fontXl; font.weight: Font.DemiBold
            color: card.profile.text
        }
        Text {
            objectName: "tourExplanation"
            width: parent.width; wrapMode: Text.WordWrap
            text: card.explanation; textFormat: Text.PlainText
            font.family: Theme.sans; font.pixelSize: Theme.fontMd; lineHeight: 1.35
            color: card.profile.text
        }
        Text {
            objectName: "tourShortcut"
            width: parent.width; wrapMode: Text.WordWrap; visible: text !== ""
            text: card.shortcut; textFormat: Text.PlainText
            font.family: Theme.mono; font.pixelSize: Theme.fontXs; lineHeight: 1.4
            color: card.profile.signal
        }
        TourButton {
            objectName: "tourSettings"
            visible: card.step === 4
            label: "OPEN SETTINGS"
            onActivated: { Tour.finish(); Registry.execute("shell.open.settings"); }
        }
        RowLayout {
            width: parent.width; spacing: Theme.du(8)
            TourButton { objectName: "tourSkip"; label: "SKIP"; onActivated: Tour.skip() }
            Item { Layout.fillWidth: true }
            TourButton { objectName: "tourBack"; label: "BACK"; visible: card.step > 0; onActivated: Tour.back() }
            TourButton { objectName: "tourNext"; label: card.step === 4 ? "FINISH" : "NEXT"; primary: true; onActivated: Tour.next() }
        }
    }
    component TourButton: Rectangle {
        id: button
        property string label: ""
        property bool primary: false
        signal activated()
        implicitWidth: caption.implicitWidth + Theme.du(24)
        implicitHeight: Theme.du(36)
        color: primary ? card.profile.signal : hover.containsMouse ? card.profile.surface2 : card.profile.bg
        border.color: activeFocus ? card.profile.text : primary ? card.profile.signal : card.profile.grid
        border.width: activeFocus ? Theme.px(2) : Theme.border
        activeFocusOnTab: true
        Text {
            id: caption; anchors.centerIn: parent
            text: button.label; textFormat: Text.PlainText
            font.family: Theme.mono; font.pixelSize: Theme.fontXs
            color: button.primary ? card.profile.bg : card.profile.text
        }
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.activated() }
        Accessible.role: Accessible.Button; Accessible.name: label
        Accessible.onPressAction: activated()
    }
}
