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
    required property var s

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

    readonly property real fieldWidth: s.observatory ? width * 0.64 : s.index ? width * 0.78 : width
    Ink { s: core.s; text: "Search applications, windows, commands and routines"; color: s.dim; font.pixelSize: s.small }
    Rectangle {
        id: inputRow; y: s.px(32); width: core.fieldWidth; height: s.px(72)
        color: s.surface
        Rectangle { y: parent.height - 3; width: parent.width; height: 3; color: input.activeFocus ? s.accent : s.line }
        TextInput {
            id: input
            anchors { fill: parent; margins: s.px(16) }
            focus: true; text: core.query; onTextChanged: core.query = text
            color: s.ink; selectionColor: s.accent; selectedTextColor: s.surface
            font.family: Config.theme.fontSans; font.pixelSize: s.px(30)
            clip: true; verticalAlignment: TextInput.AlignVCenter
            Component.onCompleted: cursorPosition = text.length
            Ink { s: core.s; anchors.verticalCenter: parent.verticalCenter; visible: input.text === ""; text: "What would you like to open?"; color: s.dim; font.pixelSize: s.px(28) }
        }
    }
    Row {
        id: scopeRow; y: inputRow.y + inputRow.height + s.px(22); spacing: s.px(20)
        Repeater {
            model: core.scopes
            delegate: Item {
                required property var modelData
                required property int index
                width: scopeLabel.implicitWidth; height: s.px(30)
                Ink { id: scopeLabel; s: core.s; text: modelData.label; font.pixelSize: s.small; color: index === core.scopeIndex ? s.accent : s.dim }
                Rectangle { visible: index === core.scopeIndex; y: s.px(22); width: parent.width; height: 2; color: s.accent }
                MouseArea { anchors.fill: parent; onClicked: core.scopeIndex = index }
            }
        }
    }
    ListView {
        id: list
        y: scopeRow.y + scopeRow.height + s.px(14)
        width: core.fieldWidth; height: Math.max(s.row, core.height - y - s.px(72))
        readonly property int visibleRows: Math.max(1, Math.floor(height / s.row))
        model: core.results; currentIndex: core.currentIndex
        clip: true; keyNavigationEnabled: false; boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: s.travel ? s.fast : 0
        delegate: Item {
            required property var modelData
            required property int index
            width: list.width; height: s.row
            Rectangle { anchors.fill: parent; color: index === core.currentIndex ? s.inset : "transparent" }
            Rectangle { x: 0; width: index === core.currentIndex ? s.px(4) : 0; height: parent.height; color: s.accent; Behavior on width { enabled: s.travel; NumberAnimation { duration: s.fast } } }
            Ink { s: core.s; x: s.px(18); y: s.px(8); width: parent.width - s.px(130); text: modelData.title; font.pixelSize: s.body; color: modelData.available ? s.ink : s.dim }
            Ink { s: core.s; x: s.px(18); y: s.px(30); width: parent.width - s.px(130); text: modelData.available ? modelData.subtitle || modelData.commandId : "Unavailable: " + modelData.reason; font.pixelSize: s.small; color: modelData.available ? s.dim : s.warning }
            Ink { s: core.s; anchors.right: parent.right; anchors.rightMargin: s.px(18); anchors.verticalCenter: parent.verticalCenter; text: core.confirmKey === modelData.key ? "CONFIRM" : core.tagFor(modelData); font.pixelSize: s.small; mono: true; color: core.confirmKey === modelData.key ? s.warning : s.dim }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: s.line }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: core.currentIndex = index; onClicked: { core.currentIndex = index; core.activate(false); } }
        }
        Ink { s: core.s; anchors.centerIn: parent; visible: list.count === 0; text: !Apps.ready ? "Indexing applications…" : core.query.trim() === "" ? "Start typing" : "No match"; color: s.dim }
    }
    Column {
        visible: !s.architecture
        x: core.fieldWidth + s.px(32); y: inputRow.y; width: Math.max(0, parent.width - x); spacing: s.px(22)
        Ink { s: core.s; text: "SEARCH PREFIXES"; color: s.dim; font.pixelSize: s.small; font.letterSpacing: 1.2 }
        Repeater { model: [">  Commands", "@  Windows", "!   Routines", "?  AI, when installed"]
            delegate: Ink { required property string modelData; s: core.s; width: parent.width; text: modelData; color: s.dim; font.pixelSize: s.small }
        }
    }
    Ink { s: core.s; y: parent.height - s.px(48); width: parent.width; text: "↑↓  select     Enter  run     Shift+Enter  run, stay     Tab  scope     > commands   @ windows   ! routines   ? AI"; font.pixelSize: s.small; color: s.dim }
    Ink { s: core.s; y: parent.height - s.px(22); width: parent.width; text: core.statusText; font.pixelSize: s.small; color: core.statusState === "error" ? s.error : core.statusState === "caution" ? s.warning : s.dim }
}
