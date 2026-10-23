import QtQuick
import qs.core
import qs.components
import "../../lib/config.mjs" as ConfigLib

// Settings bay: every setting in the configuration schema, generated from the
// schema, so new settings appear here without code changes. Changes go
// through Config.setValue (validated, saved to config.json, applied live).
//
// Keys: Up/Down (j/k) select, Left/Right (h/l) change enums and numbers,
// Enter/Space toggle, step or start editing text, Escape cancels editing
// (otherwise the Deck closes). PgUp/PgDn move a page.
//
// This file is deliberately plain; its look belongs to the visual design.
// Keep buildRows(), valueOf(), change(), commitText() and the key handling.
FocusScope {
    id: bay

    // Set by the Deck; this bay holds no demand, so nothing depends on it.
    property bool active: true

    // Settings that are not edited here: written by AEROLITH itself, or
    // structured values that need their own editor.
    readonly property var skipped: ["schemaVersion", "theme.palette"]
    readonly property var rows: buildRows()
    property int current: 0
    property bool editing: false
    property string message: ""
    property string messageState: ""

    function buildRows() {
        const out = [];
        const walk = (node, prefix) => {
            for (const k in node.props) {
                const p = node.props[k];
                const path = prefix ? prefix + "." + k : k;
                if (skipped.indexOf(path) !== -1)
                    continue;
                if (p.type === "object")
                    walk(p, path);
                else if (["bool", "enum", "int", "number", "string"].indexOf(p.type) !== -1)
                    out.push({
                        path: path,
                        section: prefix,
                        type: p.type,
                        values: p.values || [],
                        min: p.min,
                        max: p.max,
                        description: p.description || ""
                    });
            }
        };
        walk(ConfigLib.SCHEMA, "");
        return out;
    }

    function valueOf(path) {
        Config.revision;
        return ConfigLib.getPath(Config.data, path);
    }

    function display(row) {
        const v = valueOf(row.path);
        if (row.type === "bool")
            return v ? "on" : "off";
        if (row.type === "string")
            return v === "" ? "(empty)" : String(v);
        return String(v);
    }

    function apply(row, value) {
        const err = Config.setValue(row.path, value);
        message = err ? err : row.path + " set to " + JSON.stringify(value);
        messageState = err ? "error" : "ok";
    }

    // Step size for numbers: about a hundredth of the range, rounded to a
    // power of ten for integers (1, 10, 100, ...).
    function stepOf(row) {
        const span = row.max - row.min;
        if (row.type === "number")
            return span <= 2 ? 0.05 : span / 100;
        return span <= 100 ? 1 : Math.pow(10, Math.floor(Math.log(span) / Math.LN10) - 1);
    }

    function change(row, dir) {
        const v = valueOf(row.path);
        if (row.type === "bool") {
            apply(row, !v);
        } else if (row.type === "enum") {
            const i = row.values.indexOf(v);
            apply(row, row.values[(i + dir + row.values.length) % row.values.length]);
        } else if (row.type === "int" || row.type === "number") {
            let next = v + dir * stepOf(row);
            next = Math.max(row.min, Math.min(row.max, next));
            apply(row, row.type === "int" ? Math.round(next) : Math.round(next * 100) / 100);
        }
    }

    function commitText(text) {
        editing = false;
        apply(rows[current], text);
        bay.forceActiveFocus();
    }

    function move(delta) {
        current = Math.max(0, Math.min(rows.length - 1, current + delta));
        list.positionViewAtIndex(current, ListView.Contain);
    }

    Keys.onPressed: event => {
        if (editing)
            return;
        const row = rows[current];
        const k = event.key;
        if (k === Qt.Key_Down || k === Qt.Key_J)
            move(1);
        else if (k === Qt.Key_Up || k === Qt.Key_K)
            move(-1);
        else if (k === Qt.Key_PageDown)
            move(10);
        else if (k === Qt.Key_PageUp)
            move(-10);
        else if (k === Qt.Key_Right || k === Qt.Key_L)
            change(row, 1);
        else if (k === Qt.Key_Left || k === Qt.Key_H)
            change(row, -1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (row.type === "string") {
                editing = true;
                editor.text = valueOf(row.path);
                editor.forceActiveFocus();
                editor.selectAll();
            } else {
                change(row, 1);
            }
        } else
            return;
        event.accepted = true;
    }

    // Presentation only: the schema traversal, mutations and keys above stay exact.
    readonly property var selectedRow: rows[current]
    readonly property bool inspectorVisible: width >= Theme.du(1050)
    function caption(path) {
        const leaf = path.substring(path.lastIndexOf(".") + 1);
        return leaf.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, c => c.toUpperCase());
    }

    Bezel {
        anchors.fill: parent
        designation: "SET / 07"
        title: "Settings"
        status: bay.editing ? "EDIT / UNSAVED" : "CONFIG / LIVE"
        statusColor: bay.editing ? Theme.caution : Theme.signal

        Column {
            id: content
            anchors.fill: parent
            spacing: Theme.du(12)

            Row {
                width: parent.width
                Text {
                    width: parent.width * .65
                    text: "CONFIGURATION REGISTER"; textFormat: Text.PlainText
                    color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 2
                }
                Text {
                    width: parent.width * .35; horizontalAlignment: Text.AlignRight
                    text: (bay.current + 1) + " / " + bay.rows.length + " SETTINGS"; textFormat: Text.PlainText
                    color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
            }

            Item {
                width: parent.width
                height: Math.max(0, content.height - y - feedback.height - status.height - content.spacing * 3)

                ListView {
                    id: list
                    width: bay.inspectorVisible ? parent.width * .68 - Theme.pad : parent.width
                    height: parent.height
                    clip: true
                    model: bay.rows
                    currentIndex: bay.current
                    spacing: Theme.du(3)
                    boundsBehavior: Flickable.StopAtBounds
                    section.property: "section"
                    section.delegate: Item {
                        required property string section
                        width: list.width; height: Theme.du(38)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; spacing: Theme.du(12)
                            Rectangle { width: Theme.du(18); height: Theme.px(2); color: Theme.signal; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                id: sectionLabel
                                text: section.toUpperCase(); textFormat: Text.PlainText
                                color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 2
                            }
                            Rectangle {
                                width: Math.max(0, parent.width - sectionLabel.width - Theme.du(42))
                                height: Theme.border; color: Theme.grid; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === bay.current
                        width: list.width
                        height: Math.max(Theme.du(74), valueControl.implicitHeight + Theme.du(24), rowLabels.implicitHeight + Theme.du(24))
                        radius: Theme.radius
                        color: selected ? Theme.surface2 : Theme.surface
                        border.color: selected ? (bay.editing ? Theme.caution : Theme.grid) : "transparent"
                        border.width: Theme.border
                        Rectangle {
                            y: Theme.radius; width: Theme.du(3); height: Math.max(0, parent.height - 2 * y); radius: width / 2
                            color: bay.editing ? Theme.caution : Theme.signal; visible: row.selected
                        }
                        Text {
                            visible: Theme.insane
                            x: Theme.du(12); y: Theme.du(12)
                            text: (row.index + 1 < 10 ? "0" : "") + (row.index + 1); textFormat: Text.PlainText
                            color: row.selected ? Theme.signal : Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                        }
                        Column {
                            id: rowLabels
                            x: Theme.du(Theme.insane ? 42 : 16)
                            width: Math.max(0, valueControl.x - x - Theme.pad)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.du(5)
                            Text {
                                width: parent.width; text: bay.caption(row.modelData.path); textFormat: Text.PlainText
                                color: row.selected ? Theme.signal : Theme.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width; text: row.modelData.description; textFormat: Text.PlainText
                                color: Theme.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontXs
                                wrapMode: row.selected && !bay.inspectorVisible ? Text.WordWrap : Text.NoWrap
                                elide: row.selected && !bay.inspectorVisible ? Text.ElideNone : Text.ElideRight
                            }
                        }
                        SettingControl {
                            id: valueControl
                            z: 1
                            width: parent.width * .43
                            anchors.right: parent.right; anchors.rightMargin: Theme.du(14)
                            anchors.verticalCenter: parent.verticalCenter
                            height: implicitHeight
                            setting: row.modelData; value: bay.valueOf(row.modelData.path)
                            selected: row.selected; editing: row.selected && bay.editing; draft: editor.text
                            onStepped: direction => { bay.current = row.index; bay.forceActiveFocus(); bay.change(row.modelData, direction); }
                            onChoicePicked: value => { bay.current = row.index; bay.forceActiveFocus(); bay.apply(row.modelData, value); }
                            onEditRequested: {
                                bay.current = row.index;
                                bay.editing = true;
                                editor.text = bay.valueOf(row.modelData.path);
                                editor.forceActiveFocus();
                                editor.selectAll();
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                bay.current = row.index;
                                bay.forceActiveFocus();
                            }
                            onDoubleClicked: bay.change(row.modelData, 1)
                        }
                    }
                    // A static position marker also works with motion off.
                    Rectangle {
                        anchors.right: parent.right
                        width: Theme.px(2)
                        height: Math.min(list.height, Math.max(Theme.du(18), list.height * list.visibleArea.heightRatio))
                        y: Math.max(0, Math.min(list.height - height, list.visibleArea.yPosition * list.height))
                        color: Theme.signal
                        visible: list.contentHeight > list.height
                    }
                }

                Item {
                    visible: bay.inspectorVisible
                    x: parent.width * .68 + Theme.pad
                    width: Math.max(0, parent.width - x)
                    height: parent.height
                    Rectangle { x: -Theme.pad; width: Theme.border; height: parent.height; color: Theme.grid }
                    Column {
                        width: parent.width
                        spacing: Theme.du(18)
                        Text {
                            text: bay.editing ? "DRAFT / TEXT" : "SELECTED / " + bay.selectedRow.type.toUpperCase(); textFormat: Text.PlainText
                            color: bay.editing ? Theme.caution : Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
                        }
                        Text {
                            width: parent.width; text: bay.caption(bay.selectedRow.path); textFormat: Text.PlainText
                            wrapMode: Text.WordWrap; color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(30)
                        }
                        Text {
                            width: parent.width; text: bay.selectedRow.path; textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                        }
                        Rectangle { width: parent.width; height: Theme.border; color: Theme.grid }
                        Text {
                            width: parent.width; text: bay.selectedRow.description; textFormat: Text.PlainText
                            wrapMode: Text.WordWrap; color: Theme.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm; lineHeight: 1.4
                        }
                        Text {
                            width: parent.width
                            text: bay.editing ? "Text is a draft until Enter.\nEscape discards the draft." : bay.selectedRow.type === "string" ? "Enter to edit text.\nChanges save when confirmed." : "← / →  " + (bay.selectedRow.type === "bool" ? "Toggle on or off" : bay.selectedRow.type === "enum" ? "Cycle choices" : "Step " + bay.stepOf(bay.selectedRow)) + "\nChanges save and apply live."
                            textFormat: Text.PlainText; wrapMode: Text.WordWrap
                            color: bay.editing ? Theme.caution : Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; lineHeight: 1.5
                        }
                    }
                }
            }

            Rectangle {
                id: feedback
                width: parent.width
                height: feedbackText.implicitHeight + Theme.du(18)
                radius: Theme.radius
                color: bay.messageState === "error" ? Theme.bg : Theme.surface
                border.color: bay.messageState === "error" ? Theme.critical : Theme.grid
                border.width: Theme.border
                Text {
                    id: feedbackText
                    x: Theme.du(12); y: Theme.du(9); width: parent.width - 2 * x
                    text: bay.editing ? "DRAFT  /  " + bay.selectedRow.path + "  /  Enter to save · Esc to cancel" : bay.message ? (bay.messageState === "error" ? "REFUSED  /  " : "SAVED  /  ") + bay.message : "READY  /  Settings save to config.json and apply immediately."
                    textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                    color: bay.editing ? Theme.caution : bay.messageState === "error" ? Theme.critical : bay.messageState === "ok" ? Theme.signal : Theme.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
            }
            StatusLine {
                id: status
                width: parent.width
                hints: bay.editing ? [{key: "⏎", action: "save text"}, {key: "Esc", action: "cancel"}] : [
                    {key: "↑↓ / j k", action: "select"},
                    {key: "←→ / h l", action: "change"},
                    {key: "⏎ / Space", action: "toggle / edit"},
                    {key: "PgUp Dn", action: "page"}
                ]
            }
        }
    }

    // The one text editor. It is transparent (an invisible item cannot take
    // focus); the selected row shows what is being typed.
    TextInput {
        id: editor
        enabled: bay.editing
        width: 1
        height: 1
        opacity: 0
        Keys.onReturnPressed: bay.commitText(text)
        Keys.onEnterPressed: bay.commitText(text)
        Keys.onEscapePressed: event => {
            bay.editing = false;
            bay.forceActiveFocus();
            event.accepted = true;
        }
    }
}
