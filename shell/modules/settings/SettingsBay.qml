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

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.pad * 2
        color: Theme.surface
        border.color: Theme.grid
        border.width: Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.gap

            Text {
                text: "Settings"
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - y - status.height - Theme.gap
                clip: true
                model: bay.rows
                currentIndex: bay.current
                section.property: "section"
                section.delegate: Text {
                    required property string section
                    text: section
                    color: Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    topPadding: Theme.gap
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === bay.current
                    width: list.width
                    height: Theme.rowHeight + Theme.px(14)
                    color: selected ? Theme.surface2 : "transparent"

                    Column {
                        anchors.left: parent.left
                        anchors.right: valueText.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.pad
                        anchors.rightMargin: Theme.pad
                        Text {
                            width: parent.width
                            text: row.modelData.path
                            textFormat: Text.PlainText
                            color: row.selected ? Theme.signal : Theme.text
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontSm
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.description
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        id: valueText
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.pad
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.4)
                        text: row.selected && bay.editing ? editor.text + "_" : bay.display(row.modelData)
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        elide: Text.ElideLeft
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
            }

            StatusLine {
                id: status
                width: parent.width
                hints: bay.editing ? [
                    {
                        key: "⏎",
                        action: "save"
                    },
                    {
                        key: "Esc",
                        action: "cancel"
                    }
                ] : [
                    {
                        key: "↑↓",
                        action: "select"
                    },
                    {
                        key: "←→",
                        action: "change"
                    },
                    {
                        key: "⏎",
                        action: "toggle / edit"
                    }
                ]
                message: bay.message
                messageState: bay.messageState
            }
        }
    }

    // The one text editor. It is transparent (an invisible item cannot take
    // focus); the selected row shows what is being typed.
    TextInput {
        id: editor
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
