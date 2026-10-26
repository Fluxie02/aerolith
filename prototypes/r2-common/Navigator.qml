import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// NAV-02 · Spatial Navigator: a tactical map of the workspaces on the one
// display AEROLITH runs on. Each workspace is a sector; windows are drawn at
// their real positions, scaled. Text and icons by default; live thumbnails
// only when navigator.thumbnails is enabled (they use
// hyprland-toplevel-export and cost GPU memory).
//
// Keys: arrows/hjkl move between sectors, Tab cycles windows in a sector,
// Enter focuses, 1-9 jumps to a workspace, M then 1-9 moves the selected
// window, X twice closes it, / filters, Esc clears filter or closes.
FocusScope {
    id: nav
    required property var s

    property int sectorIndex: 0
    property int windowIndex: 0
    property bool moveMode: false
    property string confirmClose: ""
    property string filter: ""
    property bool filtering: false
    property string statusText: ""
    property string statusState: ""

    readonly property var monitor: Compositor.monitorGeometry()
    readonly property var allWindows: Compositor.windows()

    readonly property var sectors: {
        const byWs = {};
        const wins = allWindows;
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (w.workspaceId <= 0)
                continue;
            if (!byWs[w.workspaceId])
                byWs[w.workspaceId] = [];
            byWs[w.workspaceId].push(w);
        }
        const ids = {};
        const ws = Compositor.workspaces;
        for (let i = 0; i < ws.length; i++)
            ids[ws[i].id] = true;
        for (const k in byWs)
            ids[k] = true;
        if (Config.navigator.showEmptyWorkspaces)
            for (let i = 1; i <= Config.strip.workspaceCount; i++)
                ids[i] = true;
        const out = Object.keys(ids).map(Number).sort((a, b) => a - b).map(id => ({
                    id: id,
                    focused: id === Compositor.focusedWorkspaceId,
                    windows: (byWs[id] || []).sort((a, b) => (a.floating === b.floating ? 0 : a.floating ? 1 : -1))
                }));
        return out;
    }

    readonly property int columns: Math.max(1, s.keel ? 3 : sectors.length)
    readonly property var currentSector: sectors.length > 0 ? sectors[Math.min(sectorIndex, sectors.length - 1)] : null
    readonly property var currentWindow: currentSector && currentSector.windows.length > 0 ? currentSector.windows[Math.min(windowIndex, currentSector.windows.length - 1)] : null

    function matches(w) {
        if (filter.trim() === "")
            return true;
        const f = filter.toLowerCase();
        return (w.title + " " + w.appId).toLowerCase().indexOf(f) !== -1;
    }

    function setStatus(t, s) {
        statusText = t;
        statusState = s;
    }

    function selectInitial() {
        for (let i = 0; i < sectors.length; i++)
            if (sectors[i].focused) {
                sectorIndex = i;
                const wins = sectors[i].windows;
                windowIndex = 0;
                for (let k = 0; k < wins.length; k++)
                    if (wins[k].active)
                        windowIndex = k;
                return;
            }
    }

    function moveSelection(dx, dy) {
        const n = sectors.length;
        if (n === 0)
            return;
        let i = sectorIndex + dx + dy * columns;
        if (i < 0 || i >= n)
            i = Math.max(0, Math.min(n - 1, i));
        sectorIndex = i;
        windowIndex = 0;
        confirmClose = "";
    }

    function runAndReport(id, args, closeAfter) {
        setStatus("…", "busy");
        Registry.execute(id, args, {
            record: false
        }).then(r => {
            nav.setStatus(r.message, r.ok ? "ok" : "error");
            if (r.ok && closeAfter)
                Ui.close();
            else
                Compositor.refresh();
        });
    }

    function activateSelection() {
        if (filtering && filter.trim() !== "") {
            for (let i = 0; i < allWindows.length; i++)
                if (matches(allWindows[i]))
                    return runAndReport("window.focus", {
                        address: allWindows[i].address
                    }, true);
            setStatus("No window matches “" + filter + "”", "error");
            return;
        }
        if (currentWindow)
            runAndReport("window.focus", {
                address: currentWindow.address
            }, true);
        else if (currentSector)
            runAndReport("workspace.focus", {
                workspace: currentSector.id
            }, true);
    }

    Component.onCompleted: {
        Compositor.refresh();
        selectInitial();
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (filtering) {
            if (k === Qt.Key_Escape) {
                filtering = false;
                filter = "";
                filterInput.text = "";
                nav.forceActiveFocus();
                event.accepted = true;
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                activateSelection();
                event.accepted = true;
            }
            return;
        }
        if (moveMode) {
            if (k >= Qt.Key_1 && k <= Qt.Key_9 && currentWindow) {
                runAndReport("window.move", {
                    address: currentWindow.address,
                    workspace: k - Qt.Key_0,
                    follow: false
                }, false);
            } else {
                setStatus("Move cancelled", "");
            }
            moveMode = false;
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Left || k === Qt.Key_H)
            moveSelection(-1, 0);
        else if (k === Qt.Key_Right || k === Qt.Key_L)
            moveSelection(1, 0);
        else if (k === Qt.Key_Up || k === Qt.Key_K)
            moveSelection(0, -1);
        else if (k === Qt.Key_Down || k === Qt.Key_J)
            moveSelection(0, 1);
        else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            const n = currentSector ? currentSector.windows.length : 0;
            if (n > 0)
                windowIndex = (windowIndex + (k === Qt.Key_Backtab ? -1 : 1) + n) % n;
            confirmClose = "";
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            activateSelection();
        else if (k >= Qt.Key_1 && k <= Qt.Key_9 && !(event.modifiers & Qt.ControlModifier))
            runAndReport("workspace.focus", {
                workspace: k - Qt.Key_0
            }, true);
        else if (k === Qt.Key_M && currentWindow) {
            moveMode = true;
            setStatus("Move “" + (currentWindow.title || currentWindow.appId) + "” to workspace: press 1-9", "caution");
        } else if ((k === Qt.Key_X || k === Qt.Key_Delete) && currentWindow) {
            if (confirmClose === currentWindow.address) {
                confirmClose = "";
                runAndReport("window.close", {
                    address: currentWindow.address
                }, false);
            } else {
                confirmClose = currentWindow.address;
                setStatus("Press X again to close “" + (currentWindow.title || currentWindow.appId) + "”", "caution");
            }
        } else if (k === Qt.Key_Slash) {
            filtering = true;
            filterInput.forceActiveFocus();
        } else
            return;
        event.accepted = true;
    }

    Rectangle {
        id:filterRow;width:parent.width;height:s.px(35);color:"transparent"
        Ink {s:nav.s;text:"/";font.pixelSize:s.px(17);color:s.accent}
        TextInput {
            id:filterInput;x:s.px(28);width:parent.width-x;height:parent.height
            color:s.text;font.family:s.mono;font.pixelSize:s.px(13);onTextChanged:nav.filter=text;Keys.forwardTo:[nav]
            Ink {s:nav.s;visible:filterInput.text==="";text:nav.filtering?"FILTER BY TITLE OR APPLICATION":"PRESS / TO FILTER   ·   "+nav.allWindows.length+" WINDOWS / "+nav.sectors.length+" WORKSPACES";color:s.dim;font.pixelSize:s.px(11)}
        }
        Rectangle {y:parent.height-1;width:parent.width;height:1;color:s.line}
    }
    Item {
        id:field;y:s.px(60);width:parent.width;height:parent.height-y-s.px(65)
        readonly property int rows:Math.max(1,Math.ceil(nav.sectors.length/nav.columns))
        readonly property real cellW:(width-(nav.columns-1)*s.px(22))/nav.columns
        readonly property real cellH:(height-(rows-1)*s.px(22))/rows
        Repeater {model:nav.sectors
            delegate:Sector {
                required property var modelData
                required property int index
                s:nav.s
                x:(index%nav.columns)*(field.cellW+s.px(22))
                y:Math.floor(index/nav.columns)*(field.cellH+s.px(22)) + (s.limb?Math.abs(index-2)*s.px(24):s.fault?(index%2)*s.px(30):0)
                width:field.cellW;height:field.cellH-(s.keel?0:s.px(60))
                sector:modelData;selected:index===nav.sectorIndex
                selectedWindow:index===nav.sectorIndex&&nav.currentWindow?nav.currentWindow.address:""
                closeArmed:nav.confirmClose;filterFn:w=>nav.matches(w);monitor:nav.monitor
                onSectorClicked:nav.runAndReport("workspace.focus",{workspace:modelData.id},true)
                onWindowClicked:w=>nav.runAndReport("window.focus",{address:w.address},true)
            }
        }
    }
    Ink {s:nav.s;y:parent.height-s.px(40);width:parent.width;text:"←↑↓→ SECTOR   TAB WINDOW   ⏎ FOCUS   1–9 WORKSPACE   M MOVE   X CLOSE   / FILTER";color:s.dim;font.pixelSize:s.px(10)}
    Ink {s:nav.s;y:parent.height-s.px(15);width:parent.width;text:nav.statusText|| (nav.currentWindow?Compositor.windowLabel(nav.currentWindow):nav.currentSector?"Workspace "+nav.currentSector.id+" · empty":"");color:nav.statusState==="caution"?s.caution:s.dim;font.pixelSize:s.px(11)}
}
