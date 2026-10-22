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
// Keys: left/right (h/l) move workspaces, up/down (k/j) and Tab select windows,
// Enter focuses, 1-9 jumps to a workspace, M then 1-9 moves the selected
// window, X twice closes it, / filters, Esc clears filter or closes.
FocusScope {
    id: nav

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

    readonly property int columns: Math.max(1, sectors.length)
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
        if (dy !== 0) {
            const count = currentSector ? currentSector.windows.length : 0;
            if (count > 0)
                windowIndex = Math.max(0, Math.min(count - 1, windowIndex + dy));
        } else {
            sectorIndex = Math.max(0, Math.min(n - 1, sectorIndex + dx));
            windowIndex = 0;
        }
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

    Bezel {
        anchors.fill: parent
        designation: "NAV / 02"
        title: "Spatial Navigator"
        status: nav.allWindows.length + " WINDOWS / " + nav.sectors.length + " WORKSPACES"
        MouseArea { anchors.fill: parent; z: -1 }
        Item {
            anchors.fill: parent
            Item {
                id: filterRow
                width: parent.width
                height: Theme.du(35)
                Text {
                    text: "/"; textFormat: Text.PlainText
                    color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.du(17)
                }
                TextInput {
                    id: filterInput
                    x: Theme.du(28); width: parent.width - x; height: parent.height
                    color: Theme.text; font.family: Theme.mono; font.pixelSize: Theme.fontMd
                    onTextChanged: nav.filter = text
                    Keys.forwardTo: [nav]
                    Text {
                        visible: filterInput.text === ""
                        text: nav.filtering ? "FILTER BY TITLE OR APPLICATION" : "PRESS / TO FILTER"
                        textFormat: Text.PlainText
                        color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.border; color: Theme.grid }
            }
            Flickable {
                id: field
                anchors.top: filterRow.bottom; anchors.topMargin: Theme.du(25)
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: status.top; anchors.bottomMargin: Theme.du(20)
                clip: true
                contentWidth: Math.max(width, nav.sectors.length * (cellW + Theme.du(22)) - Theme.du(22))
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                readonly property real cellW: Math.max(Theme.du(220), (width - (nav.sectors.length - 1) * Theme.du(22)) / Math.max(1, nav.sectors.length))
                function reveal() {
                    var left = nav.sectorIndex * (cellW + Theme.du(22));
                    contentX = Math.max(0, Math.min(contentWidth - width, left < contentX ? left : left + cellW > contentX + width ? left + cellW - width : contentX));
                }
                Connections { target: nav; function onSectorIndexChanged() { field.reveal(); } }
                onWidthChanged: reveal()
                Repeater {
                    model: nav.sectors
                    delegate: Sector {
                        required property var modelData
                        required property int index
                        x: index * (field.cellW + Theme.du(22))
                        y: Math.min(2, Math.abs(index - (nav.sectors.length - 1) / 2)) * Math.min(Theme.du(24), field.height * .035)
                        width: field.cellW; height: Math.max(0, field.height - (field.height < Theme.du(300) ? Math.min(Theme.du(48), field.height * .07) : Theme.du(60)))
                        sector: modelData; selected: index === nav.sectorIndex
                        selectedWindow: selected && nav.currentWindow ? nav.currentWindow.address : ""
                        closeArmed: nav.confirmClose; monitor: nav.monitor
                        filterFn: w => nav.matches(w)
                        onSectorClicked: nav.runAndReport("workspace.focus", {workspace: modelData.id}, true)
                        onWindowClicked: w => nav.runAndReport("window.focus", {address: w.address}, true)
                    }
                }
                Text {
                    visible: !Compositor.available
                    anchors.centerIn: parent; width: parent.width
                    text: "HYPRLAND NOT DETECTED · window overview unavailable"
                    textFormat: Text.PlainText; wrapMode: Text.WordWrap
                    color: Theme.caution; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                }
            }
            StatusLine {
                id: status
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                hints: [{key:"←→",action:"workspace"},{key:"↑↓ / TAB",action:"window"},{key:"⏎",action:"focus"},{key:"1–9",action:"workspace"},{key:"M",action:"move"},{key:"X X",action:"close"},{key:"/",action:"filter"}]
                message: nav.statusText !== "" ? nav.statusText : nav.currentWindow ? Compositor.windowLabel(nav.currentWindow) : nav.currentSector ? "Workspace " + nav.currentSector.id + " · empty" : ""
                messageState: nav.statusState
            }
        }
    }
}
