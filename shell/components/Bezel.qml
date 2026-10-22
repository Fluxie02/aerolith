import QtQuick
import qs.core

// Limb's chord: one chamfered mineral plane, a measured upper edge and
// opposite phosphor registrations. The body API also serves the AI package.
Item {
    id: root

    property string designation: ""
    property string title: ""
    property string status: ""
    property color statusColor: Theme.textDim
    property bool active: true
    property bool showHeader: title !== "" || designation !== ""
    property color accent: active ? Theme.signal : Theme.grid
    property alias headerRight: headerRightSlot.data
    default property alias content: body.data
    readonly property int headerHeight: showHeader ? Theme.headerHeight : 0

    Canvas {
        id: face
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            const w = width;
            const h = height;
            const cut = Math.min(Theme.du(20), w / 4, h / 4);
            c.reset();
            c.beginPath();
            c.moveTo(0.5, 0.5);
            c.lineTo(w - cut - 0.5, 0.5);
            c.lineTo(w - 0.5, cut + 0.5);
            c.lineTo(w - 0.5, h - 0.5);
            c.lineTo(0.5, h - 0.5);
            c.closePath();
            c.fillStyle = Theme.alpha(Theme.surface, Theme.panelOpacity);
            c.fill();
            c.lineWidth = Theme.border;
            c.strokeStyle = Theme.grid;
            c.stroke();
            c.beginPath();
            c.strokeStyle = Theme.grid;
            for (let x = Theme.du(72); x < w - cut - Theme.du(16); x += Theme.du(12)) {
                c.moveTo(x + 0.5, 1);
                c.lineTo(x + 0.5, Theme.du((Math.round(x / Theme.unit) % 60 === 0) ? 8 : 4));
            }
            c.stroke();
            c.beginPath();
            c.strokeStyle = root.accent;
            c.lineWidth = Theme.bracketWeight;
            c.moveTo(0, Theme.du(28));
            c.lineTo(0, 0);
            c.lineTo(Theme.du(54), 0);
            c.moveTo(w, h - Theme.du(28));
            c.lineTo(w, h);
            c.lineTo(w - Theme.du(54), h);
            c.stroke();
        }
        Connections {
            target: Theme
            function onPaletteChanged() { face.requestPaint(); }
            function onPanelOpacityChanged() { face.requestPaint(); }
        }
        Connections {
            target: root
            function onAccentChanged() { face.requestPaint(); }
        }
    }

    Item {
        id: header
        visible: root.showHeader
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: Theme.contentInset
            rightMargin: Theme.contentInset
        }
        height: root.headerHeight
        Row {
            id: headerLabel
            width: Math.max(0, header.width - headerRightSlot.width - Theme.du(20))
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.du(20)
            Text {
                id: designationText
                textFormat: Text.PlainText
                visible: root.designation !== ""
                text: root.designation
                color: root.accent
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                textFormat: Text.PlainText
                text: root.title.toUpperCase()
                width: Math.max(0, headerLabel.width - designationText.width - headerLabel.spacing)
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
                font.letterSpacing: 2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            id: headerRightSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap
            Text {
                textFormat: Text.PlainText
                visible: root.status !== ""
                text: root.status
                width: Math.min(implicitWidth, header.width * .48)
                elide: Text.ElideRight
                color: root.statusColor
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    Rectangle {
        visible: root.showHeader
        x: Theme.contentInset
        y: header.height - height
        width: Math.max(0, root.width - 2 * x)
        height: Theme.border
        color: Theme.grid
    }
    Item {
        id: body
        anchors {
            fill: parent
            topMargin: root.headerHeight + Theme.contentInset
            leftMargin: Theme.contentInset
            rightMargin: Theme.contentInset
            bottomMargin: Theme.contentInset
        }
    }
}
