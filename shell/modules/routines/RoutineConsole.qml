import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

// RTN-05 · Routine Console: preview, run, cancel and revert routines.
//
// Keys: ↑↓ select · ⏎ run (twice for routines with sensitive steps) ·
// ESC cancels a running routine (between steps) or closes · R revert last
// run · E edit routines.json.
FocusScope {
    id: console_

    property int selected: 0
    property string confirmId: ""
    property string statusText: ""
    property string statusState: ""

    readonly property var list: Routines.routines
    readonly property var current: list.length > 0 ? list[Math.min(selected, list.length - 1)] : null
    readonly property var plan: {
        Registry.revision;
        return current ? Routines.preview(current.id) : null;
    }

    Component.onCompleted: {
        if (Ui.selectedRoutine !== "")
            for (let i = 0; i < list.length; i++)
                if (list[i].id === Ui.selectedRoutine)
                    selected = i;
    }

    function setStatus(t, s) {
        statusText = t;
        statusState = s;
    }

    function runCurrent() {
        if (!current || Routines.running)
            return;
        const needs = plan && plan.needsConfirmation;
        if (needs && confirmId !== current.id) {
            confirmId = current.id;
            setStatus("Contains sensitive steps. Press Enter again to run " + current.name, "caution");
            return;
        }
        const confirmed = needs && confirmId === current.id;
        confirmId = "";
        setStatus("Running " + current.name + "…", "busy");
        Routines.start(current.id, confirmed).then(rep => {
            const r = Routines.summary(rep);
            console_.setStatus(r.message, r.ok ? "ok" : rep.cancelled ? "caution" : "error");
        });
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Escape && Routines.running) {
            Routines.cancel();
            setStatus("Cancelling after the current step…", "caution");
        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
            selected = Math.min(list.length - 1, selected + 1);
            confirmId = "";
        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
            selected = Math.max(0, selected - 1);
            confirmId = "";
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            runCurrent();
        else if (k === Qt.Key_R)
            Routines.revertLast().then(r => console_.setStatus(r.message, r.ok ? "ok" : "error"));
        else if (k === Qt.Key_E)
            Exec.run(["xdg-open", Paths.routinesFile]).then(r => console_.setStatus(r.code === 0 ? "Opened routines.json" : "Could not open " + Paths.routinesFile + " (create it first; see docs/COMMANDS.md)", r.code === 0 ? "ok" : "error"));
        else if (k === Qt.Key_PageDown || k === Qt.Key_PageUp) {
            const direction = k === Qt.Key_PageDown ? 1 : -1;
            contentView.contentY = Math.max(0, Math.min(contentView.contentHeight - contentView.height, contentView.contentY + direction * contentView.height * .8));
        } else
            return;
        event.accepted = true;
    }

    Bezel {
        anchors.fill: parent
        designation: "RTN / 05"
        title: "Routine Console"
        status: Routines.routines.length + " ROUTINES" + (Routines.errors.length ? " · " + Routines.errors.length + " PROBLEMS" : "") + (Routines.running ? " · RUNNING" : "")
        statusColor: Routines.errors.length ? Theme.caution : Theme.textDim

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.pad

            // Problems in routines.json
            Rectangle {
                visible: Routines.errors.length > 0
                Layout.fillWidth: true
                implicitHeight: errCol.implicitHeight + Theme.pad
                color: Theme.surface2
                border.color: Theme.caution
                border.width: Theme.border
                radius: Theme.radius
                Column {
                    id: errCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.pad
                    Repeater {
                        model: Routines.errors.slice(0, 5)
                        Text {
                            required property var modelData
                            width: errCol.width
                            text: "⚠ " + (modelData.routine ? modelData.routine + (modelData.step ? " · step " + modelData.step : "") + ": " : "") + modelData.message
                            textFormat: Text.PlainText
                            color: Theme.caution
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Flickable {
                id: contentView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                contentWidth: width
                contentHeight: contentRow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function reveal(item) {
                    if (!item) return;
                    const top = item.mapToItem(contentRow, 0, 0).y;
                    contentY = Math.max(0, Math.min(contentHeight - height, top < contentY ? top : top + item.height > contentY + height ? top + item.height - height : contentY));
                }
                RowLayout {
                    id: contentRow
                    width: contentView.width
                    height: Math.max(implicitHeight, contentView.height)
                    spacing: Theme.pad * 3

                    // Routine list
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        spacing: Theme.gap
                        Label {
                            text: "ROUTINE INDEX / " + console_.list.length
                            strong: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Paths.routinesFile.replace(Paths.home, "~")
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideMiddle
                        }
                        Repeater {
                            model: console_.list
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool sel: index === console_.selected
                                onSelChanged: if (sel) contentView.reveal(this)
                                Layout.fillWidth: true
                                implicitHeight: Math.round(Theme.rowHeight * 1.8)
                                color: sel ? Theme.surface2 : Theme.bg
                                border.color: sel ? Theme.signal : Theme.grid
                                border.width: Theme.border
                                radius: Theme.radius

                                Text {
                                    x: Theme.px(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String(index + 1).padStart(2, "0")
                                    color: sel ? Theme.signal : Theme.textDim
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontXs
                                }
                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Theme.pad
                                    anchors.leftMargin: Theme.px(40)
                                    Text {
                                        width: parent.width
                                        text: modelData.name
                                        textFormat: Text.PlainText
                                        color: Theme.text
                                        font.family: Theme.displaySans
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.id + " · " + modelData.steps.length + " steps" + (modelData.steps.some(s => s.sensitive) ? " · CONFIRM" : "")
                                        textFormat: Text.PlainText
                                        color: Theme.textDim
                                        font.family: Theme.mono
                                        font.pixelSize: Theme.fontXs
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        console_.selected = index;
                                        console_.confirmId = "";
                                    }
                                    onDoubleClicked: console_.runCurrent()
                                }
                            }
                        }
                        Text {
                            visible: console_.list.length === 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: Routines.fileMissing ? "No routines yet. Create " + Paths.routinesFile + " (see docs/COMMANDS.md for the format and an example), then it loads automatically." : "No valid routines in the file."
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Preview and run log
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 68
                        Layout.fillHeight: true
                        spacing: Theme.gap
                        Label {
                            text: "EXECUTION PLAN / " + (console_.current && console_.current.onError === "continue" ? "CONTINUE ON ERROR" : "STOP ON ERROR")
                            strong: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: console_.current ? console_.current.name : "No routine selected"
                            textFormat: Text.PlainText
                            color: Theme.text
                            font.family: Theme.displaySans
                            font.pixelSize: Theme.fontXl
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: console_.current !== null && console_.current.description !== ""
                            Layout.fillWidth: true
                            text: console_.current ? console_.current.description : ""
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            visible: console_.current === null
                            Layout.fillWidth: true
                            text: Routines.errors.length ? "Repair routines.json to load your execution plans. Press E to open the file." : "Add an execution plan to routines.json. Press E to open the file; each plan is previewed here before it runs."
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            wrapMode: Text.WordWrap
                        }
                        Ruler {
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: console_.plan ? console_.plan.steps : []
                            delegate: RowLayout {
                                id: stepRow
                                required property var modelData
                                readonly property var result: {
                                    if (!console_.current || (Routines.runningId !== console_.current.id && (!Routines.lastReport || Routines.lastReport.routine !== console_.current.id)))
                                        return null;
                                    const src = Routines.runningId === console_.current.id ? Routines.progress : Routines.lastReport.steps;
                                    for (let i = 0; i < src.length; i++)
                                        if (src[i].index === modelData.index)
                                            return src[i];
                                    return null;
                                }
                                Layout.fillWidth: true
                                spacing: Theme.gap
                                Text {
                                    Layout.preferredWidth: Theme.px(58)
                                    text: stepRow.result ? (stepRow.result.skipped ? "[SKIP]" : stepRow.result.ok ? "[ OK ]" : "[FAIL]") : Routines.runningId === (console_.current ? console_.current.id : "") ? "[ .. ]" : "[    ]"
                                    color: stepRow.result ? (stepRow.result.skipped ? Theme.textDim : stepRow.result.ok ? Theme.signal : Theme.critical) : Theme.textDim
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontXs
                                }
                                Text {
                                    Layout.preferredWidth: Theme.px(24)
                                    text: String(modelData.index).padStart(2, "0")
                                    color: Theme.textDim
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontXs
                                }
                                Text {
                                    Layout.preferredWidth: Theme.px(190)
                                    text: modelData.title
                                    textFormat: Text.PlainText
                                    color: Theme.text
                                    font.family: Theme.displaySans
                                    font.pixelSize: Theme.fontSm
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: stepRow.result ? stepRow.result.message : modelData.description
                                    textFormat: Text.PlainText
                                    color: stepRow.result && !stepRow.result.ok && !stepRow.result.skipped ? Theme.critical : Theme.textDim
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.sensitive || !modelData.available
                                    text: !modelData.available ? "N/A · " + modelData.reason : "SENSITIVE"
                                    textFormat: Text.PlainText
                                    color: Theme.caution
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontXs
                                }
                            }
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                        Text {
                            visible: Routines.lastReport !== null && Routines.lastReport.undo && Routines.lastReport.undo.length > 0
                            text: "Last run of " + (Routines.lastReport ? Routines.lastReport.name : "") + " can be reverted (" + (Routines.lastReport && Routines.lastReport.undo ? Routines.lastReport.undo.length : 0) + " steps): press R"
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                        }
                    }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: Math.max(Theme.du(24), contentView.width * Math.min(1, contentView.height / Math.max(1, contentView.contentHeight)))
                implicitHeight: Theme.px(2)
                visible: contentView.contentHeight > contentView.height
                color: Theme.signal
            }

            StatusLine {
                Layout.fillWidth: true
                hints: [
                    {
                        key: "↑↓",
                        action: "select"
                    },
                    {
                        key: "⏎",
                        action: "run"
                    },
                    {
                        key: "ESC",
                        action: Routines.running ? "cancel" : "close"
                    },
                    {
                        key: "R",
                        action: "revert"
                    },
                    {
                        key: "E",
                        action: "edit file"
                    }
                ]
                message: console_.statusText !== "" ? console_.statusText : console_.plan && console_.plan.blocked > 0 ? console_.plan.blocked + " step(s) unavailable right now" : ""
                messageState: console_.statusText !== "" ? console_.statusState : "caution"
            }
        }
    }
}
