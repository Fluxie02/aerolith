import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

// CMD-01 · Command Core: the universal command interface.
//
// Search, validation and execution are owned by the registry; this file
// only renders results and turns keys into registry calls.
FocusScope {
    id: core

    property string query: Ui.pendingQuery
    property int scopeIndex: 0
    property int currentIndex: 0
    property string confirmKey: ""
    property string statusText: ""
    property string statusState: ""
    property bool busy: false

    readonly property var scopes: [
        {
            id: "",
            label: "ALL"
        },
        {
            id: "apps",
            label: "APPS"
        },
        {
            id: "windows",
            label: "WINDOWS"
        },
        {
            id: "audio",
            label: "AUDIO"
        },
        {
            id: "media",
            label: "MEDIA"
        },
        {
            id: "system",
            label: "SYSTEM"
        },
        {
            id: "routines",
            label: "ROUTINES"
        }
    ].concat(Registry.revision >= 0 && Registry.get("ai.ask") ? [
            {
                id: "ai",
                label: "AI"
            }
        ] : [])

    readonly property string scopeId: scopes[Math.min(scopeIndex, scopes.length - 1)].id

    readonly property var recentItems: {
        if (query.trim() !== "" || scopeId !== "")
            return [];
        const list = Store.recent.slice(0, 6);
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            const cmd = Registry.get(e.commandId);
            if (!cmd)
                continue;
            let avail = true;
            if (typeof cmd.available === "function") {
                const a = cmd.available(Registry.context());
                avail = a === true || a === undefined ? true : String(a);
            }
            out.push({
                key: "recent:" + i,
                kind: "recent",
                title: e.title,
                subtitle: "Recent · " + cmd.title,
                category: cmd.category,
                icon: "",
                commandId: e.commandId,
                args: e.args || {},
                available: avail === true,
                reason: avail === true ? "" : avail,
                sensitive: cmd.sensitive === true,
                needsArgs: false,
                highlights: {},
                badge: ""
            });
        }
        return out;
    }

    readonly property var results: {
        Registry.revision; // re-run when commands change
        return recentItems.concat(Registry.search(query, {
            scope: scopeId
        }));
    }

    readonly property var current: results.length > 0 ? results[Math.min(currentIndex, results.length - 1)] : null

    onQueryChanged: {
        currentIndex = 0;
        confirmKey = "";
    }
    onScopeIndexChanged: currentIndex = 0

    function tagFor(item) {
        const kinds = {
            app: "APP",
            window: "WIN",
            workspace: "WSP",
            device: "AUD",
            player: "MED",
            routine: "RTN",
            invocation: "RUN",
            notification: "NTF",
            recent: "HIS"
        };
        if (kinds[item.kind])
            return kinds[item.kind];
        const cats = {
            apps: "APP",
            windows: "WIN",
            workspaces: "WSP",
            audio: "AUD",
            media: "MED",
            system: "SYS",
            routines: "RTN",
            settings: "SET",
            shell: "SHL",
            ai: "AI"
        };
        return cats[item.category] || "CMD";
    }

    function setStatus(text, state) {
        statusText = text;
        statusState = state;
    }

    function activate(keepOpen) {
        const item = current;
        if (!item || busy)
            return;
        if (!item.available) {
            setStatus("Unavailable: " + item.reason, "error");
            return;
        }
        if (item.kind === "invocation" && !item.valid) {
            setStatus(item.validation, "error");
            return;
        }
        if (item.needsArgs) {
            if (item.alias) {
                input.text = item.alias + " ";
                input.cursorPosition = input.text.length;
                setStatus("Type the arguments for " + item.title, "caution");
            } else {
                setStatus(item.title + " needs arguments", "error");
            }
            return;
        }
        if (item.sensitive && confirmKey !== item.key) {
            confirmKey = item.key;
            setStatus("Press Enter again to confirm: " + item.title, "caution");
            return;
        }
        const bayBefore = Ui.activeBay;
        busy = true;
        setStatus("Executing " + item.title + "…", "busy");
        Registry.execute(item.commandId, item.args, {
            confirmed: item.sensitive && confirmKey === item.key,
            title: item.kind === "app" || item.kind === "routine" ? item.title : undefined
        }).then(r => {
            core.busy = false;
            core.confirmKey = "";
            if (r.needsConfirmation) {
                core.setStatus(r.message, "caution");
                return;
            }
            core.setStatus(r.message, r.ok ? "ok" : "error");
            // Close after success unless asked to stay or the command
            // already moved to another bay.
            if (r.ok && !keepOpen && Ui.activeBay === bayBefore)
                Ui.close();
            else if (!r.ok)
                Ui.report(r);
        });
    }

    function move(delta) {
        if (results.length === 0)
            return;
        currentIndex = (currentIndex + delta + results.length) % results.length;
        confirmKey = "";
    }

    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
            move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
            move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            move(Math.max(1, list.visibleRows - 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            move(-Math.max(1, list.visibleRows - 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activate((event.modifiers & Qt.ShiftModifier) !== 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const back = event.key === Qt.Key_Backtab;
            scopeIndex = (scopeIndex + (back ? -1 : 1) + scopes.length) % scopes.length;
            event.accepted = true;
        } else if (ctrl && event.key === Qt.Key_L) {
            input.text = "";
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && input.text !== "") {
            input.text = "";
            event.accepted = true;
        }
    }

    Bezel {
        id: bezel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.08)
        width: Math.min(Theme.px(820), parent.width - Theme.pad * 4)
        height: Math.min(parent.height - y - Theme.pad, headerHeight + Theme.gap + inputRow.height + Theme.gap + scopeRow.height + list.contentHeightCapped + status.height + Theme.pad * 2)
        designation: "CMD-01"
        title: "Command Core"
        status: {
            Registry.revision;
            return (Apps.ready ? Apps.entries.length + " APPS · " : "") + Registry.api.size() + " COMMANDS";
        }

        Behavior on height {
            enabled: Theme.animate
            NumberAnimation {
                duration: Theme.fast
            }
        }

        // Swallow clicks so they don't reach the Deck backdrop.
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        Column {
            anchors.fill: parent
            spacing: Theme.gap

            // Input
            Rectangle {
                id: inputRow
                width: parent.width
                height: Math.round(Theme.rowHeight * 1.25)
                color: Theme.bg
                border.color: input.activeFocus ? Theme.signal : Theme.grid
                border.width: Theme.border
                radius: Theme.radius

                Text {
                    id: prompt
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.signal
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontLg
                }
                TextInput {
                    id: input
                    anchors.left: prompt.right
                    anchors.leftMargin: Theme.gap
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true
                    text: core.query
                    onTextChanged: core.query = text
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.signal, 0.35)
                    selectedTextColor: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontMd
                    clip: true
                    Component.onCompleted: cursorPosition = text.length
                    Text {
                        visible: input.text === ""
                        text: "Type an app, window, command or routine…   > commands   @ windows   ! routines"
                        color: Theme.textDim
                        font: input.font
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // Scope selector
            Row {
                id: scopeRow
                spacing: Theme.px(2)
                Repeater {
                    model: core.scopes
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === core.scopeIndex
                        width: scopeLabel.implicitWidth + Theme.pad * 1.4
                        height: Math.round(Theme.rowHeight * 0.7)
                        color: selected ? Theme.alpha(Theme.signal, 0.14) : "transparent"
                        border.color: selected ? Theme.signal : Theme.grid
                        border.width: Theme.border
                        radius: Theme.radius
                        Text {
                            id: scopeLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.selected ? Theme.signal : Theme.textDim
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            font.letterSpacing: 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: core.scopeIndex = index
                        }
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: Theme.pad
                    text: "TAB · SCOPE"
                }
            }

            // Results
            ListView {
                id: list
                width: parent.width
                readonly property int rowH: Math.round(Theme.rowHeight * 1.35)
                readonly property int visibleRows: Math.max(4, Math.floor((core.height * 0.62) / rowH))
                readonly property int contentHeightCapped: Math.max(rowH, Math.min(Math.max(1, count) * rowH, visibleRows * rowH))
                height: contentHeightCapped
                clip: true
                model: core.results
                currentIndex: core.currentIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Theme.fast
                keyNavigationEnabled: false

                delegate: ResultRow {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: list.rowH
                    item: modelData
                    selected: index === core.currentIndex
                    confirming: core.confirmKey === modelData.key
                    tag: core.tagFor(modelData)
                    onActivated: {
                        core.currentIndex = index;
                        core.activate(false);
                    }
                    onHovered: core.currentIndex = index
                }

                // Empty and loading states
                Column {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    spacing: Theme.px(4)
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        strong: true
                        text: !Apps.ready && core.query.trim() !== "" ? "Indexing applications…" : core.query.trim() === "" ? "Start typing" : "No match"
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "> commands · @ windows · ! routines · F1 help"
                    }
                }
            }

            StatusLine {
                id: status
                width: parent.width
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
                        key: "⇧⏎",
                        action: "run, stay"
                    },
                    {
                        key: "ESC",
                        action: "close"
                    }
                ]
                message: core.statusText !== "" ? core.statusText : core.current ? (core.current.available ? core.current.commandId : "unavailable: " + core.current.reason) : ""
                messageState: core.statusText !== "" ? core.statusState : core.current && !core.current.available ? "caution" : ""
            }
        }
    }
}
