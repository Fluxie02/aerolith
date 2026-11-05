import QtQuick
import qs.core
import qs.components
import qs.services
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
    property var profile: Theme

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
    property bool spectra: true
    readonly property var schemeRow: rows.filter(r => r.path === "theme.scheme")[0]

    // Unknown stays N/A; Theme reads the current output's live monitor data.
    readonly property real outputRefreshRate: Theme.refreshRate
    readonly property string refreshLabel: isFinite(outputRefreshRate) ? String(Math.round(outputRefreshRate * 100) / 100) + " Hz" : "Refresh rate unavailable"
    readonly property string motionLabel: !Theme.animate ? (Theme.lowEffects ? "Motion: off · low effects" : "Motion: off") :
        "Motion: " + (Theme.travel ? "" : "reduced · ") + "synced to " + (isFinite(outputRefreshRate) ? refreshLabel : "display")

    function showRegister() { spectra = false; bay.forceActiveFocus(); }
    function showSpectra() { editing = false; spectra = true; spectrum.forceActiveFocus(); }

    function buildRows() {
        const out = [];
        const walk = (node, prefix) => {
            for (const k in node.props) {
                const p = node.props[k];
                const path = prefix ? prefix + "." + k : k;
                if (p.hidden || skipped.indexOf(path) !== -1)
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
        message = err ? err : row.path + " → " + JSON.stringify(value);
        messageState = err ? "error" : "requested";
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
        if (event.key === Qt.Key_Tab) {
            if (tourAction.activeFocus) showSpectra();
            else if (spectra) showRegister();
            else if (diagnosticsList.activeFocus || !diagnosticsPanel.visible) tourAction.forceActiveFocus();
            else diagnosticsList.forceActiveFocus();
            event.accepted = true;
            return;
        }
        if (spectra) return;
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
            if (row.path === "theme.scheme") {
                showSpectra();
            } else if (row.type === "string") {
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
    readonly property var diagnostics: Config.errors.map(d => ({path: d.path, message: d.message, error: true}))
        .concat(Config.warnings.map(d => ({path: d.path, message: d.message, error: false})))
    function description(row) {
        return row.path === "theme.intensity" ? "Decoration level: Saturated / Insane. Changes how much ornament is shown." : row.description;
    }
    function caption(path) {
        const leaf = path.substring(path.lastIndexOf(".") + 1);
        return leaf.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, c => c.toUpperCase());
    }

    Bezel { profile: bay.profile;
        anchors.fill: parent
        designation: "SETTINGS"
        title: "Settings"
        status: bay.editing ? "EDIT / UNSAVED" : "CONFIG / LIVE"
        statusColor: bay.editing ? bay.profile.caution : bay.profile.signal

        Column {
            id: content
            anchors.fill: parent
            spacing: Theme.du(12)

            Row {
                width: parent.width
                height: Theme.du(32)
                spacing: Theme.du(6)
                Repeater {
                    model: ["SPECTRA / " + spectrum.schemeCount, "REGISTER / " + bay.rows.length]
                    Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool chosen: index === (bay.spectra ? 0 : 1)
                        width: Math.min(Theme.du(180), (content.width - Theme.du(6)) / 2); height: Theme.du(32)
                        color: chosen ? bay.profile.surface2 : bay.profile.bg
                        border.color: chosen ? bay.profile.signal : bay.profile.grid; radius: Theme.du(4)
                        Text {
                            anchors.centerIn: parent; text: modelData; textFormat: Text.PlainText
                            color: parent.chosen ? bay.profile.signal : bay.profile.textDim
                            font.family: Theme.mono; font.pixelSize: Theme.fontXs
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (index === 0) bay.showSpectra(); else bay.showRegister(); }
                    }
                }
                Rectangle {
                    id: tourAction
                    objectName: "settingsTakeTour"
                    width: tourCaption.implicitWidth + 2 * Theme.pad; height: parent.height
                    color: tourPointer.containsMouse ? bay.profile.surface2 : bay.profile.bg
                    border.color: activeFocus ? bay.profile.text : bay.profile.signal
                    border.width: activeFocus ? Theme.px(2) : Theme.border
                    radius: Theme.radius; activeFocusOnTab: true
                    function activate() { if (Tour.start()) Ui.close(); }
                    Keys.onReturnPressed: activate()
                    Keys.onEnterPressed: activate()
                    Keys.onSpacePressed: activate()
                    Keys.onTabPressed: bay.showSpectra()
                    Keys.onBacktabPressed: { if (diagnosticsPanel.visible) diagnosticsList.forceActiveFocus(); else bay.showRegister(); }
                    Text {
                        id: tourCaption; anchors.centerIn: parent
                        text: "Take the tour"; textFormat: Text.PlainText
                        color: bay.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                    }
                    MouseArea { id: tourPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tourAction.activate() }
                    Accessible.role: Accessible.Button; Accessible.name: "Take the tour"
                    Accessible.onPressAction: activate()
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.du(36)
                radius: Theme.radius
                color: bay.profile.surface
                border.color: bay.profile.grid
                border.width: Theme.border
                Text {
                    x: Theme.du(12); width: Math.max(0, parent.width * .64 - x)
                    height: parent.height; verticalAlignment: Text.AlignVCenter
                    text: bay.motionLabel; textFormat: Text.PlainText
                    color: Theme.animate ? bay.profile.signal : bay.profile.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
                Text {
                    x: parent.width * .64; width: Math.max(0, parent.width - x - Theme.du(12))
                    height: parent.height; verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: (Ui.screenName ? Ui.screenName + " · " : "") + bay.refreshLabel
                    textFormat: Text.PlainText
                    color: bay.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                    elide: Text.ElideLeft
                }
                Accessible.role: Accessible.StaticText
                Accessible.name: bay.motionLabel + ". " + (Ui.screenName || "Current output") + ". " + bay.refreshLabel
            }

            Item {
                width: parent.width
                height: Math.max(0, content.height - y - feedback.height - status.height - diagnosticsPanel.height - content.spacing * (diagnosticsPanel.visible ? 4 : 3))

                SchemePicker { profile: bay.profile;
                    id: spectrum
                    anchors.fill: parent
                    visible: bay.spectra
                    focus: bay.spectra
                    onPicked: scheme => bay.apply(bay.schemeRow, scheme)
                    onRegisterRequested: bay.showRegister()
                }

                ListView {
                    id: list
                    visible: !bay.spectra
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
                            Rectangle { width: Theme.du(18); height: Theme.px(2); color: bay.profile.signal; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                id: sectionLabel
                                text: section.toUpperCase(); textFormat: Text.PlainText
                                color: bay.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 2
                            }
                            Rectangle {
                                width: Math.max(0, parent.width - sectionLabel.width - Theme.du(42))
                                height: Theme.border; color: bay.profile.grid; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === bay.current
                        width: list.width
                        height: Math.max(Theme.du(74), row.modelData.path === "theme.scheme" ? 0 : valueControl.implicitHeight + Theme.du(24), rowLabels.implicitHeight + Theme.du(24))
                        radius: Theme.radius
                        color: selected ? bay.profile.surface2 : bay.profile.surface
                        border.color: selected ? (bay.editing ? bay.profile.caution : bay.profile.grid) : "transparent"
                        border.width: Theme.border
                        Rectangle {
                            y: Theme.radius; width: Theme.du(3); height: Math.max(0, parent.height - 2 * y); radius: width / 2
                            color: bay.editing ? bay.profile.caution : bay.profile.signal; visible: row.selected
                        }
                        Text {
                            visible: Theme.insane
                            x: Theme.du(12); y: Theme.du(12)
                            text: (row.index + 1 < 10 ? "0" : "") + (row.index + 1); textFormat: Text.PlainText
                            color: row.selected ? bay.profile.signal : bay.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                        }
                        Column {
                            id: rowLabels
                            x: Theme.du(Theme.insane ? 42 : 16)
                            width: Math.max(0, valueControl.x - x - Theme.pad)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.du(5)
                            Text {
                                width: parent.width; text: bay.caption(row.modelData.path); textFormat: Text.PlainText
                                color: row.selected ? bay.profile.signal : bay.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width; text: bay.description(row.modelData); textFormat: Text.PlainText
                                color: bay.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontXs
                                wrapMode: row.selected && !bay.inspectorVisible ? Text.WordWrap : Text.NoWrap
                                elide: row.selected && !bay.inspectorVisible ? Text.ElideNone : Text.ElideRight
                            }
                        }
                        SettingControl { profile: bay.profile;
                            id: valueControl
                            visible: row.modelData.path !== "theme.scheme"
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
                        Rectangle {
                            z: 2; visible: row.modelData.path === "theme.scheme"
                            x: valueControl.x; width: valueControl.width; height: Theme.du(34); anchors.verticalCenter: parent.verticalCenter
                            color: bay.profile.bg; border.color: bay.profile.signal; radius: Theme.du(4)
                            Text {
                                anchors.fill: parent; anchors.margins: Theme.du(8)
                                text: Theme.specimen.name + "  /  OPEN SPECTRA"; textFormat: Text.PlainText
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                color: bay.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bay.showSpectra(); }
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
                        color: bay.profile.signal
                        visible: list.contentHeight > list.height
                    }
                }

                Item {
                    visible: bay.inspectorVisible && !bay.spectra
                    x: parent.width * .68 + Theme.pad
                    width: Math.max(0, parent.width - x)
                    height: parent.height
                    Rectangle { x: -Theme.pad; width: Theme.border; height: parent.height; color: bay.profile.grid }
                    Column {
                        width: parent.width
                        spacing: Theme.du(18)
                        Text {
                            text: bay.editing ? "DRAFT / TEXT" : "SELECTED / " + bay.selectedRow.type.toUpperCase(); textFormat: Text.PlainText
                            color: bay.editing ? bay.profile.caution : bay.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
                        }
                        Text {
                            width: parent.width; text: bay.caption(bay.selectedRow.path); textFormat: Text.PlainText
                            wrapMode: Text.WordWrap; color: bay.profile.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(30)
                        }
                        Text {
                            width: parent.width; text: bay.selectedRow.path; textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere; color: bay.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                        }
                        Rectangle { width: parent.width; height: Theme.border; color: bay.profile.grid }
                        Text {
                            width: parent.width; text: bay.description(bay.selectedRow); textFormat: Text.PlainText
                            wrapMode: Text.WordWrap; color: bay.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm; lineHeight: 1.4
                        }
                        Text {
                            width: parent.width
                            text: bay.editing ? "Text is a draft until Enter.\nEscape discards the draft." : bay.selectedRow.type === "string" ? "Enter to edit text.\nChanges save when confirmed." : "← / →  " + (bay.selectedRow.type === "bool" ? "Toggle on or off" : bay.selectedRow.type === "enum" ? "Cycle choices" : "Step " + bay.stepOf(bay.selectedRow)) + "\nChanges save and apply live."
                            textFormat: Text.PlainText; wrapMode: Text.WordWrap
                            color: bay.editing ? bay.profile.caution : bay.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; lineHeight: 1.5
                        }
                    }
                }
            }

            Rectangle {
                id: diagnosticsPanel
                objectName: "settingsDiagnostics"
                width: parent.width
                visible: bay.diagnostics.length > 0
                height: visible ? Math.min(Theme.du(144), content.height * .25, diagnosticsHeading.implicitHeight + diagnosticsList.contentHeight + Theme.du(30)) : 0
                color: bay.profile.bg; radius: Theme.radius
                border.color: diagnosticsList.activeFocus ? bay.profile.text : Config.errors.length ? bay.profile.critical : bay.profile.caution
                border.width: diagnosticsList.activeFocus ? Theme.px(2) : Theme.border
                Text {
                    id: diagnosticsHeading
                    x: Theme.du(12); y: Theme.du(8); width: parent.width - 2 * x
                    text: "CONFIG DIAGNOSTICS / " + Config.errors.length + " errors · " + Config.warnings.length + " warnings"
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: bay.profile.text; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                ListView {
                    id: diagnosticsList
                    objectName: "settingsDiagnosticsList"
                    x: Theme.du(12); y: diagnosticsHeading.y + diagnosticsHeading.height + Theme.du(6)
                    width: parent.width - 2 * x; height: Math.max(0, parent.height - y - Theme.du(8))
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    model: bay.diagnostics; spacing: Theme.du(8)
                    activeFocusOnTab: true
                    Keys.onTabPressed: tourAction.forceActiveFocus()
                    Keys.onBacktabPressed: bay.showRegister()
                    Keys.onDownPressed: incrementCurrentIndex()
                    Keys.onUpPressed: decrementCurrentIndex()
                    delegate: Column {
                        required property var modelData
                        width: diagnosticsList.width - Theme.gap; spacing: Theme.du(3)
                        Text {
                            width: parent.width
                            text: (modelData.error ? "ERROR / " : "WARNING / ") + modelData.path
                            textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                            color: modelData.error ? bay.profile.critical : bay.profile.caution
                            font.family: Theme.mono; font.pixelSize: Theme.fontXs
                        }
                        Text {
                            width: parent.width; text: modelData.message
                            textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                            color: bay.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                        }
                    }
                    ScrollMark { profile: bay.profile; viewport: diagnosticsList }
                }
            }
            Rectangle {
                id: feedback
                width: parent.width
                height: feedbackText.implicitHeight + Theme.du(18)
                radius: Theme.radius
                color: bay.messageState === "error" ? bay.profile.bg : bay.profile.surface
                border.color: bay.messageState === "error" ? bay.profile.critical : bay.profile.grid
                border.width: Theme.border
                Text {
                    id: feedbackText
                    x: Theme.du(12); y: Theme.du(9); width: parent.width - 2 * x
                    text: bay.editing ? "DRAFT  /  " + bay.selectedRow.path + "  /  Enter to save · Esc to cancel" : bay.message ? (bay.messageState === "error" ? "REFUSED  /  " : "REQUESTED  /  ") + bay.message : "READY  /  Settings save to config.json and apply immediately."
                    textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                    color: bay.editing ? bay.profile.caution : bay.messageState === "error" ? bay.profile.critical : bay.messageState === "ok" ? bay.profile.signal : bay.profile.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
            }
            StatusLine { profile: bay.profile;
                id: status
                width: parent.width
                hints: bay.editing ? [{key: "⏎", action: "save text"}, {key: "Esc", action: "cancel"}] : bay.spectra ? [
                    {key: "↑↓←→ / h j k l", action: "browse"},
                    {key: "⏎ / Space", action: "apply"},
                    {key: "Tab", action: "register"}
                ] : [
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
