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
    readonly property bool compact: height < Theme.du(600)

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
        anchors.fill: parent
        contentPadding: core.compact ? Theme.pad : Theme.contentInset
        titleHeight: core.compact ? Theme.du(42) : Theme.headerHeight
        designation: "CMD / 01"
        title: "Command Core"
        status: "ESC / CLOSE"

        // The Deck owns placement and motion; this bay accepts input immediately.
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        Item {
            anchors.fill: parent

            Row {
                id: summary
                spacing: Theme.pad * 1.6
                Text {
                    text: "UNIVERSAL INPUT"
                    textFormat: Text.PlainText
                    color: Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    font.letterSpacing: 1
                }
                Text {
                    text: core.results.length + " MATCH" + (core.results.length === 1 ? "" : "ES")
                    textFormat: Text.PlainText
                    color: Theme.signal
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                }
            }

            Rectangle {
                id: inputRow
                anchors.top: summary.bottom
                anchors.topMargin: core.compact ? Theme.gap : Theme.pad * 1.6
                width: parent.width
                height: core.compact ? Theme.du(48) : Math.max(Theme.px(76), Theme.rowHeight * 1.9)
                radius: Theme.radius
                color: Theme.lowEffects ? Theme.bg : Theme.alpha(Theme.bg, 0.8)

                Rectangle {
                    anchors.bottom: parent.bottom
                    x: Theme.radius; width: parent.width - 2 * x
                    height: Theme.px(2)
                    color: Theme.signal
                }
                Text {
                    id: prompt
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad * 1.6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    textFormat: Text.PlainText
                    color: Theme.signal
                    font.family: Theme.mono
                    font.pixelSize: core.compact ? Theme.fontLg : Theme.px(34)
                }
                TextInput {
                    id: input
                    anchors.left: prompt.right
                    anchors.leftMargin: Theme.pad * 1.6
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad * 1.8
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    text: core.query
                    onTextChanged: core.query = text
                    color: Theme.text
                    selectionColor: Theme.signal
                    selectedTextColor: Theme.bg
                    font.family: Theme.mono
                    font.pixelSize: core.compact ? Theme.fontLg : Theme.px(28)
                    clip: true
                    Component.onCompleted: cursorPosition = text.length
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "App, window, command…"
                        textFormat: Text.PlainText
                        color: Theme.textDim
                        font.family: Theme.mono
                        font.pixelSize: core.compact ? Theme.fontLg : Theme.px(24)
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            InstrumentTabs {
                id: scopeRow
                anchors.top: inputRow.bottom
                anchors.topMargin: core.compact ? Theme.gap : Theme.pad * 1.8
                width: parent.width
                height: implicitHeight
                entries: core.scopes
                currentIndex: core.scopeIndex
                onChosen: index => core.scopeIndex = index
            }

            ListView {
                id: list
                anchors.top: scopeRow.bottom
                anchors.topMargin: Theme.gap
                anchors.bottom: footer.top
                anchors.bottomMargin: Theme.pad
                width: parent.width
                readonly property int rowH: core.compact ? Theme.px(54) : Math.max(Theme.px(68), Math.round(Theme.rowHeight * 1.7))
                readonly property int visibleRows: Math.max(1, Math.floor(height / rowH))
                clip: true
                model: core.results
                currentIndex: core.currentIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Theme.animate ? Theme.fast : 0
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

                Column {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: Theme.gap
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: !Apps.ready && core.query.trim() !== "" ? "INDEXING APPLICATIONS…" : core.query.trim() === "" ? "START TYPING" : "NO MATCH"
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "> commands · @ windows · ! routines · ? AI · F1 help"
                        textFormat: Text.PlainText
                        color: Theme.textDim
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontXs
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Column {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: Theme.pad
                Text {
                    width: parent.width
                    text: "↑↓ SELECT    ⏎ RUN    ⇧⏎ RUN, STAY    TAB SCOPE"
                    textFormat: Text.PlainText
                    color: Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: core.statusText !== "" ? core.statusText : core.current && !core.current.available ? "N/A · " + core.current.reason : ""
                    textFormat: Text.PlainText
                    color: core.statusState === "error" ? Theme.critical : core.statusState === "caution" || core.current && !core.current.available ? Theme.caution : Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                    height: Math.max(implicitHeight, Theme.fontXs)
                }
            }
        }
    }
}
