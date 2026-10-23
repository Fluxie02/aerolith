import QtQuick
import qs.core

// An airframe, rather than a card: a stepped pressure skin and two exposed
// registration rails. The body API also serves the separately shipped AI bay.
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
    readonly property bool compact: height < Theme.du(600)
    property int contentPadding: compact ? Theme.pad : Theme.contentInset
    property int titleHeight: compact ? Theme.du(42) : Theme.headerHeight
    readonly property int headerHeight: showHeader ? titleHeight : 0
    readonly property real cut: Math.min(Theme.du(Theme.insane ? 30 : 22), width / 8, height / 8, contentPadding * 1.25)
    property real engagement: active ? 1 : 0.24

    Behavior on engagement {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
    }

    Canvas {
        id: face
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            const c = getContext("2d");
            const w = width;
            const h = height;
            const cut = root.cut;
            const step = Math.min(Theme.du(8), cut / 2);
            const shoulder = Math.min(Theme.du(Theme.insane ? 130 : 100), w / 3);
            const seam = Theme.du(5);
            c.reset();

            // Opposed facets and the dropped right shoulder keep the housing
            // asymmetric without moving its content or eating into its inset.
            c.beginPath();
            c.moveTo(cut + 0.5, 0.5);
            c.lineTo(w - shoulder, 0.5);
            c.lineTo(w - shoulder + step, step + 0.5);
            c.lineTo(w - cut - 0.5, step + 0.5);
            c.lineTo(w - 0.5, cut + step + 0.5);
            c.lineTo(w - 0.5, h - cut - 0.5);
            c.lineTo(w - cut - 0.5, h - 0.5);
            c.lineTo(shoulder, h - 0.5);
            c.lineTo(shoulder - step, h - step - 0.5);
            c.lineTo(cut + 0.5, h - step - 0.5);
            c.lineTo(0.5, h - cut - step - 0.5);
            c.lineTo(0.5, cut + 0.5);
            c.closePath();
            c.fillStyle = Theme.alpha(Theme.surface, Theme.panelOpacity);
            c.fill();
            c.lineWidth = Theme.border;
            c.strokeStyle = Theme.grid;
            c.stroke();

            // A recessed perimeter. These traces live in the padding; inner
            // controls retain exactly the same rectangular working area.
            c.beginPath();
            c.moveTo(seam + 0.5, cut + seam);
            c.lineTo(cut + seam, seam + 0.5);
            c.lineTo(w - shoulder - Theme.du(12), seam + 0.5);
            c.moveTo(w - seam - 0.5, root.headerHeight + Theme.du(12));
            c.lineTo(w - seam - 0.5, h - cut - seam);
            c.lineTo(w - cut - seam, h - seam - 0.5);
            c.lineTo(shoulder + Theme.du(12), h - seam - 0.5);
            c.lineWidth = Theme.border;
            c.strokeStyle = Theme.grid;
            c.stroke();

            // Calibrated slots are structural marks, not simulated telemetry.
            c.beginPath();
            for (let i = 0; i < (Theme.insane ? 12 : 7); i++) {
                const x = cut + Theme.du(36 + i * 9);
                if (x > w - shoulder - Theme.du(24)) break;
                c.moveTo(x + 0.5, 1);
                c.lineTo(x - Theme.du(3) + 0.5, Theme.du(i % 4 === 0 ? 7 : 4));
            }
            c.stroke();

            // The live signal insert identifies the current bay. Its only
            // animation follows actual activation and dies with the event.
            const reach = Theme.du(44 + (Theme.travel ? root.engagement * 18 : 18));
            c.beginPath();
            c.strokeStyle = Theme.lowEffects ? root.accent : Theme.alpha(root.accent, root.engagement);
            c.lineWidth = Theme.bracketWeight;
            c.moveTo(0.5, cut + Theme.du(20));
            c.lineTo(0.5, cut + 0.5);
            c.lineTo(cut + 0.5, 0.5);
            c.lineTo(cut + reach, 0.5);
            c.moveTo(w - 0.5, h - cut - Theme.du(20));
            c.lineTo(w - 0.5, h - cut - 0.5);
            c.lineTo(w - cut - 0.5, h - 0.5);
            c.lineTo(w - cut - reach, h - 0.5);
            c.stroke();

            c.fillStyle = root.accent;
            c.beginPath();
            c.moveTo(w - shoulder + step + Theme.du(8), step + Theme.du(2));
            c.lineTo(w - shoulder + step + Theme.du(32), step + Theme.du(2));
            c.lineTo(w - shoulder + step + Theme.du(27), step + Theme.du(7));
            c.lineTo(w - shoulder + step + Theme.du(3), step + Theme.du(7));
            c.closePath();
            c.fill();
        }
        Connections {
            target: Theme
            function onPaletteChanged() { face.requestPaint(); }
            function onPanelOpacityChanged() { face.requestPaint(); }
            function onUnitChanged() { face.requestPaint(); }
            function onInsaneChanged() { face.requestPaint(); }
            function onTravelChanged() { face.requestPaint(); }
        }
        Connections {
            target: root
            function onAccentChanged() { face.requestPaint(); }
            function onEngagementChanged() { face.requestPaint(); }
            function onHeaderHeightChanged() { face.requestPaint(); }
        }
        Connections {
            target: face.Window.window
            function onVisibleChanged() { if (face.Window.window.visible) face.requestPaint(); }
        }
    }

    Item {
        id: header
        visible: root.showHeader
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: root.contentPadding
            rightMargin: root.contentPadding
        }
        height: root.headerHeight
        Row {
            id: headerLabel
            width: Math.max(0, header.width - headerRightSlot.width - Theme.du(20))
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.du(16)
            Text {
                id: designationText
                textFormat: Text.PlainText
                visible: root.designation !== ""
                text: root.designation
                color: root.accent
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                font.letterSpacing: Theme.du(1)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                textFormat: Text.PlainText
                text: root.title
                width: Math.max(0, headerLabel.width - (designationText.visible ? designationText.width + headerLabel.spacing : 0))
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                font.weight: Font.DemiBold
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
        x: root.contentPadding
        y: header.height - height
        width: Math.max(0, root.width - 2 * x)
        height: Theme.border
        color: Theme.grid
    }
    Rectangle {
        visible: root.showHeader
        x: root.contentPadding
        y: header.height - height
        width: Math.min(Theme.du(52), root.width / 5)
        height: Theme.border
        color: root.accent
    }
    Item {
        id: body
        anchors {
            fill: parent
            topMargin: root.headerHeight + root.contentPadding
            leftMargin: root.contentPadding
            rightMargin: root.contentPadding
            bottomMargin: root.contentPadding
        }
    }
}
