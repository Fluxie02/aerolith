import QtQuick
import qs.core

// Instrument bezel: the frame every AEROLITH panel sits in.
// A flat surface with a hairline border, corner registration brackets that
// light up when the panel is active, a designation header and a ruler
// divider. Children go into the content area below the header.
Item {
    id: root

    property string designation: ""   // e.g. "CMD-01"
    property string title: ""
    property string status: ""
    property color statusColor: Theme.textDim
    property bool active: true
    property bool showHeader: title !== "" || designation !== ""
    property color accent: active ? Theme.signal : Theme.grid
    property alias headerRight: headerRightSlot.data
    default property alias content: body.data
    readonly property int headerHeight: showHeader ? Math.round(Theme.rowHeight * 0.85) : 0

    Rectangle {
        id: face
        anchors.fill: parent
        color: Theme.surface
        border.color: Theme.grid
        border.width: Theme.border
        radius: Theme.radius
    }

    // Corner registration brackets.
    Repeater {
        model: 4
        delegate: Item {
            required property int index
            readonly property bool isRight: index === 1 || index === 3
            readonly property bool isBottom: index >= 2
            x: isRight ? root.width - Theme.bracket : 0
            y: isBottom ? root.height - Theme.bracket : 0
            width: Theme.bracket
            height: Theme.bracket
            Rectangle {
                width: parent.width
                height: Theme.bracketWeight
                y: parent.isBottom ? parent.height - height : 0
                color: root.accent
            }
            Rectangle {
                width: Theme.bracketWeight
                height: parent.height
                x: parent.isRight ? parent.width - width : 0
                color: root.accent
            }
        }
    }

    Item {
        id: header
        visible: root.showHeader
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: Theme.pad + Theme.bracket
            rightMargin: Theme.pad + Theme.bracket
        }
        height: root.headerHeight

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap * 1.5
            Text {
                visible: root.designation !== ""
                text: root.designation
                color: root.accent
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.title.toUpperCase()
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            id: headerRightSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap
            Text {
                visible: root.status !== ""
                text: root.status
                color: root.statusColor
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Ruler {
        visible: root.showHeader
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            leftMargin: Theme.border
            rightMargin: Theme.border
        }
    }

    Item {
        id: body
        anchors {
            fill: parent
            topMargin: root.headerHeight + (root.showHeader ? Theme.gap : Theme.pad)
            leftMargin: Theme.pad
            rightMargin: Theme.pad
            bottomMargin: Theme.pad
        }
    }
}
