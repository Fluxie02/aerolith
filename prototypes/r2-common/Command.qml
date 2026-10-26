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

    readonly property real fieldWidth: s.limb ? width : width*.69
    readonly property var selectedWindow: current && current.kind === "window" ? Compositor.windows().filter(w => w.address === current.args.address)[0] || null : null
    Row { spacing:s.px(16)
        Ink {s:core.s;text:"UNIVERSAL INPUT";color:s.dim;font.pixelSize:s.px(11);font.letterSpacing:1}
        Ink {s:core.s;text:results.length+" MATCH"+(results.length===1?"":"ES");color:s.accent;font.pixelSize:s.px(11)}
    }
    Rectangle {
        id: inputRow; y:s.px(30);width:core.fieldWidth;height:s.px(s.fault?84:76);color:s.alpha(s.bg,.8)
        Rectangle {y:parent.height-2;width:parent.width;height:2;color:s.accent}
        Ink {s:core.s;x:s.px(16);anchors.verticalCenter:parent.verticalCenter;text:"›";color:s.accent;font.pixelSize:s.px(34)}
        TextInput {
            id:input
            x:s.px(50);width:parent.width-x-s.px(18);height:parent.height
            focus:true;text:core.query;onTextChanged:core.query=text
            color:s.text;selectionColor:s.accent;selectedTextColor:s.bg
            font.family:s.mono;font.pixelSize:s.px(s.keel?30:28)
            verticalAlignment:TextInput.AlignVCenter;clip:true
            Component.onCompleted:cursorPosition=text.length
            Ink {s:core.s;anchors.verticalCenter:parent.verticalCenter;visible:input.text==="";text:"App, window, command…";color:s.dim;font.pixelSize:s.px(24)}
        }
    }
    Row {
        id:scopeRow;y:inputRow.y+inputRow.height+s.px(18);spacing:s.px(18)
        Repeater {model:core.scopes
            delegate:Item {
                required property var modelData
                required property int index
                width:caption.implicitWidth;height:s.px(32)
                Ink {id:caption;s:core.s;text:modelData.label;color:index===core.scopeIndex?s.accent:s.dim;font.pixelSize:s.px(10);font.letterSpacing:1}
                Rectangle {visible:index===core.scopeIndex;y:s.px(22);width:parent.width;height:2;color:s.accent}
                MouseArea {anchors.fill:parent;onClicked:core.scopeIndex=index}
            }
        }
    }
    ListView {
        id:list;y:scopeRow.y+scopeRow.height+s.px(8);width:core.fieldWidth;height:core.height-y-s.px(70)
        readonly property int visibleRows:Math.max(1,Math.floor(height/s.px(68)))
        model:core.results;currentIndex:core.currentIndex
        clip:true;keyNavigationEnabled:false;boundsBehavior:Flickable.StopAtBounds
        highlightMoveDuration:s.animate?Theme.fast:0
        delegate:Item {
            required property var modelData
            required property int index
            width:list.width;height:s.px(68)
            Rectangle {anchors.fill:parent;color:index===core.currentIndex?s.alpha(s.inset,.92):"transparent"}
            Rectangle {visible:index===core.currentIndex;width:s.px(3);height:parent.height;color:s.accent}
            Ink {s:core.s;x:s.px(16);y:s.px(12);width:parent.width-s.px(110);text:modelData.title;mono:!s.fault;font.pixelSize:s.px(16);font.weight:s.fault?Font.DemiBold:Font.Normal;color:modelData.available?s.text:s.dim}
            Ink {s:core.s;x:s.px(16);y:s.px(39);width:parent.width-s.px(110);text:modelData.available?modelData.subtitle||modelData.commandId:"N/A · "+modelData.reason;color:modelData.available?s.dim:s.caution;font.pixelSize:s.px(11)}
            Ink {s:core.s;anchors.right:parent.right;anchors.rightMargin:s.px(16);anchors.verticalCenter:parent.verticalCenter;text:core.confirmKey===modelData.key?"CONFIRM":core.tagFor(modelData);color:core.confirmKey===modelData.key?s.caution:s.accent;font.pixelSize:s.px(10)}
            Rectangle {y:parent.height-1;width:parent.width;height:1;color:s.line}
            MouseArea {anchors.fill:parent;hoverEnabled:true;onEntered:core.currentIndex=index;onClicked:{core.currentIndex=index;core.activate(false);}}
        }
        Ink {s:core.s;visible:list.count===0;anchors.centerIn:parent;text:Apps.ready?"NO MATCH · > commands   @ windows   ! routines   ? AI":"INDEXING APPLICATIONS";color:s.dim;wrapMode:Text.WordWrap;width:parent.width}
    }
    Column {
        visible:!s.limb;x:core.fieldWidth+s.px(40);width:core.width-x;y:s.px(30);spacing:s.px(18)
        Ink {s:core.s;text:core.current?core.tagFor(core.current)+" / SELECTED":"INPUT / GRAMMAR";color:s.accent;font.pixelSize:s.px(11)}
        Rectangle {width:parent.width;height:1;color:s.line}
        Ink {s:core.s;width:parent.width;text:core.current?core.current.title:"Search the command registry";wrapMode:Text.WordWrap;maximumLineCount:3;mono:false;font.pixelSize:s.px(23);font.weight:Font.DemiBold}
        Ink {s:core.s;width:parent.width;text:core.current?core.current.subtitle||core.current.commandId:"";wrapMode:Text.WordWrap;maximumLineCount:3;color:s.dim;font.pixelSize:s.px(11)}
        Item {width:parent.width;height:s.px(115);visible:core.selectedWindow!==null
            Rectangle {anchors.fill:parent;color:s.bg;border.color:s.line}
            Repeater {model:core.selectedWindow?[core.selectedWindow]:[]
                Rectangle {required property var modelData
                    x:modelData.at?parent.width*modelData.at[0]/1920:8;y:modelData.at?parent.height*modelData.at[1]/1080:8
                    width:modelData.size?parent.width*modelData.size[0]/1920:parent.width-16;height:modelData.size?parent.height*modelData.size[1]/1080:parent.height-16
                    color:s.alpha(s.accent,.12);border.color:s.accent
                }
            }
        }
        Ink {s:core.s;text:">  COMMANDS\n@  WINDOWS\n!  ROUTINES\n?  AI IF INSTALLED";color:s.dim;font.pixelSize:s.px(11);lineHeight:1.8}
        Ink {s:core.s;text:Registry.api.size()+" COMMANDS / "+Apps.entries.length+" APPS";font.pixelSize:s.px(10);color:s.dim}
    }
    Ink {s:core.s;y:parent.height-s.px(45);width:parent.width;text:"↑↓ SELECT    ⏎ RUN    ⇧⏎ RUN, STAY    TAB SCOPE";color:s.dim;font.pixelSize:s.px(11)}
    Ink {s:core.s;y:parent.height-s.px(18);width:parent.width;text:core.statusText; color:core.statusState==="error"?s.error:core.statusState==="caution"?s.caution:s.dim;font.pixelSize:s.px(11)}
}
