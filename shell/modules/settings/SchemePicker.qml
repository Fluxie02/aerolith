import QtQuick
import qs.core
import "../../lib/schemes.mjs" as Schemes

// A spectrum register: actual mineral planes, inscription and selection
// samples, followed by fixed-order signal / link / status bands. Cursor and
// active state are independent. No timers, shaders or offscreen layers.
FocusScope {
    id: picker
    signal picked(string scheme)
    signal registerRequested()
    readonly property int schemeCount: Schemes.SCHEMES.length
    readonly property int columns: width >= Theme.du(840) ? 3 : width >= Theme.du(600) ? 2 : 1
    readonly property bool shallow: height < Theme.du(380)
    property int cursor: 0
    readonly property bool overrides: Object.keys(Theme.cfg.palette || {}).length > 0

    function locateActive() {
        for (let i = 0; i < Schemes.SCHEMES.length; i++)
            if (Schemes.SCHEMES[i].id === Theme.scheme) cursor = i;
    }
    function containCursor() {
        // Geometry settles after creation and scaling. Containing before that
        // can leave the active specimen cut off on short screens.
        Qt.callLater(function() { if (picker.visible) registerView.positionViewAtIndex(picker.cursor, GridView.Contain); });
    }
    function move(delta) {
        cursor = Math.max(0, Math.min(Schemes.SCHEMES.length - 1, cursor + delta));
        registerView.positionViewAtIndex(cursor, GridView.Contain);
    }
    function choose(index) {
        cursor = index;
        picked(Schemes.SCHEMES[index].id);
    }
    Component.onCompleted: { locateActive(); containCursor(); }
    onVisibleChanged: if (visible) { locateActive(); containCursor(); }
    onColumnsChanged: containCursor()
    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Right || k === Qt.Key_L) move(1);
        else if (k === Qt.Key_Left || k === Qt.Key_H) move(-1);
        else if (k === Qt.Key_Down || k === Qt.Key_J) move(columns);
        else if (k === Qt.Key_Up || k === Qt.Key_K) move(-columns);
        else if (k === Qt.Key_Home) move(-Schemes.SCHEMES.length);
        else if (k === Qt.Key_End) move(Schemes.SCHEMES.length);
        else if (k === Qt.Key_PageDown) move(columns * 3);
        else if (k === Qt.Key_PageUp) move(-columns * 3);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) choose(cursor);
        else if (k === Qt.Key_Tab) registerRequested();
        else return;
        event.accepted = true;
    }

    Column {
        id: heading
        width: parent.width
        spacing: Theme.du(picker.shallow ? 4 : 8)
        Row {
            visible: !picker.shallow
            width: parent.width
            Text {
                width: parent.width * .65
                text: "COLOUR / SPECTRUM REGISTER"; textFormat: Text.PlainText
                color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1.5
            }
            Text {
                width: parent.width * .35; horizontalAlignment: Text.AlignRight
                text: Theme.applicationName + " / " + Theme.variantName.toUpperCase(); textFormat: Text.PlainText
                color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }
        }
        Row {
            width: parent.width
            spacing: Theme.du(16)
            Text {
                text: Theme.specimen.name; textFormat: Text.PlainText
                color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(picker.shallow ? 24 : 36); font.weight: Font.Light
            }
            Text {
                anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.du(5)
                width: Math.max(0, parent.width - x)
                text: Theme.specimen.description; textFormat: Text.PlainText
                color: Theme.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                elide: Text.ElideRight
            }
        }
        Text {
            width: parent.width
            text: picker.overrides ? "Custom palette overrides remain active. Specimens show the original spectra." : "Choose a spectrum. Every instrument follows immediately."
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            color: picker.overrides ? Theme.caution : Theme.textDim
            font.family: Theme.sans; font.pixelSize: Theme.fontSm
        }
    }

    GridView {
        id: registerView
        anchors.top: heading.bottom; anchors.topMargin: Theme.du(18)
        anchors.bottom: legend.top; anchors.bottomMargin: Theme.du(10)
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Schemes.SCHEMES
        cellWidth: width / picker.columns
        // Fit the whole register where practical; compact displays scroll.
        cellHeight: Math.max(Theme.du(82), Math.min(Theme.du(128), height / Math.ceil(Schemes.SCHEMES.length / picker.columns)))
        currentIndex: picker.cursor
        onHeightChanged: picker.containCursor()
        delegate: Item {
            id: specimen
            required property var modelData
            required property int index
            readonly property var p: modelData.palette
            readonly property bool chosen: Theme.scheme === modelData.id
            readonly property bool cursorHere: picker.cursor === index && picker.activeFocus
            readonly property bool compact: registerView.cellHeight < Theme.du(110)
            width: registerView.cellWidth
            height: registerView.cellHeight
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.name + ". " + modelData.description
            Accessible.checkable: true
            Accessible.checked: chosen
            Accessible.onPressAction: { picker.forceActiveFocus(); picker.choose(index); }

            Rectangle {
                id: plate
                x: Theme.du(4); y: Theme.du(4)
                width: parent.width - Theme.du(10); height: parent.height - Theme.du(10)
                color: specimen.p.obsidian
                radius: Theme.du(4)
                border.width: specimen.chosen ? Theme.px(2) : Theme.border
                border.color: specimen.chosen ? specimen.p.signal : specimen.p.grid
                Rectangle {
                    x: Theme.du(12); y: Theme.du(12)
                    width: Theme.du(3); height: Theme.du(specimen.compact ? 32 : 42)
                    color: specimen.chosen ? specimen.p.signal : specimen.p.surface2
                }
                Text {
                    x: Theme.du(23); y: Theme.du(10)
                    text: (specimen.index + 1 < 10 ? "0" : "") + (specimen.index + 1)
                    textFormat: Text.PlainText; color: specimen.p.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                Text {
                    x: Theme.du(48); y: Theme.du(7)
                    width: Math.max(0, plate.width - x - Theme.du(78))
                    text: specimen.modelData.name; textFormat: Text.PlainText
                    color: specimen.p.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(23)
                    elide: Text.ElideRight
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: Theme.du(12); y: Theme.du(13)
                    text: specimen.chosen ? "ACTIVE" : "Aa"; textFormat: Text.PlainText
                    color: specimen.chosen ? specimen.p.signal : specimen.p.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                Rectangle {
                    x: Theme.du(23); y: Theme.du(specimen.compact ? 34 : 40)
                    width: Theme.du(58); height: Theme.du(specimen.compact ? 18 : 21); radius: Theme.du(3)
                    color: specimen.p.signal
                    Text {
                        anchors.centerIn: parent; text: "SELECT"; textFormat: Text.PlainText
                        color: specimen.p.obsidian; font.family: Theme.mono; font.pixelSize: Theme.px(9)
                    }
                }
                Text {
                    x: Theme.du(90); y: Theme.du(specimen.compact ? 36 : 43)
                    width: Math.max(0, parent.width - x - Theme.du(12))
                    text: specimen.modelData.description; textFormat: Text.PlainText
                    color: specimen.p.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
                Row {
                    x: Theme.du(12); y: Theme.du(specimen.compact ? 59 : 75)
                    width: parent.width - x * 2
                    height: Theme.du(specimen.compact ? 8 : 22)
                    spacing: Theme.px(2)
                    Repeater {
                        model: [specimen.p.surface2, specimen.p.signal, specimen.modelData.link, specimen.p.nominal, specimen.p.caution, specimen.p.critical]
                        Rectangle {
                            required property color modelData
                            required property int index
                            width: (parent.width - parent.spacing * 5) * (index === 0 ? .25 : .15)
                            height: parent.height - (index === 0 ? Theme.du(specimen.compact ? 2 : 6) : 0)
                            anchors.bottom: parent.bottom
                            color: modelData
                        }
                    }
                }
                // Cursor corners remain distinct from the active scheme's rim.
                Repeater {
                    model: 2
                    Item {
                        required property int index
                        visible: specimen.cursorHere
                        x: index === 0 ? -Theme.du(3) : plate.width - Theme.du(9)
                        y: index === 0 ? -Theme.du(3) : plate.height - Theme.du(9)
                        width: Theme.du(12); height: Theme.du(12)
                        rotation: index === 0 ? 0 : 180
                        Rectangle { width: parent.width; height: Theme.px(2); color: specimen.p.text }
                        Rectangle { width: Theme.px(2); height: parent.height; color: specimen.p.text }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { picker.forceActiveFocus(); picker.choose(specimen.index); }
            }
        }
        Rectangle {
            anchors.right: parent.right
            width: Theme.px(2)
            height: Math.min(registerView.height, Math.max(Theme.du(18), registerView.height * registerView.visibleArea.heightRatio))
            y: Math.max(0, Math.min(registerView.height - height, registerView.visibleArea.yPosition * registerView.height))
            color: Theme.signal
            visible: registerView.contentHeight > registerView.height
        }
    }

    Text {
        id: legend
        anchors.bottom: parent.bottom
        width: parent.width
        text: "BANDS  /  PLANE · FOCUS · APP EDGE · READY · CAUTION · CRITICAL"
        textFormat: Text.PlainText; wrapMode: Text.WordWrap
        color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
    }
}
