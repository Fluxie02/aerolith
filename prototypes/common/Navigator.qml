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

    readonly property int columns: s.index ? 1 : s.architecture ? 3 : 2
    readonly property var currentSector: sectors.length > 0 ? sectors[Math.min(sectorIndex, sectors.length - 1)] : null
    readonly property var currentWindow: currentSector && currentSector.windows.length > 0 ? currentSector.windows[Math.min(windowIndex, currentSector.windows.length - 1)] : null

    onSectorIndexChanged: {
        if (s.index) return;
        var top = Math.floor(sectorIndex / columns) * (s.px(s.architecture ? 310 : 226) + spatial.spacing);
        var bottom = top + s.px(s.architecture ? 310 : 226);
        if (top < spatialViewport.contentY) spatialViewport.contentY = top;
        else if (bottom > spatialViewport.contentY + spatialViewport.height)
            spatialViewport.contentY = bottom - spatialViewport.height;
    }

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
        id: filterRow; width: parent.width; height: s.px(36); color: "transparent"
        Ink { s: nav.s; text: "/"; color: s.accent; font.pixelSize: s.body }
        TextInput {
            id: filterInput; x: s.px(24); width: parent.width - x; height: parent.height
            color: s.ink; font.family: Config.theme.fontSans; font.pixelSize: s.body
            onTextChanged: nav.filter = text; Keys.forwardTo: [nav]
            Ink { s: nav.s; visible: filterInput.text === ""; text: nav.filtering ? "Filter by title or application" : "Press / to filter windows"; color: s.dim }
        }
    }
    ListView {
        id: passages
        visible: s.index
        y: s.px(56); width: parent.width; height: parent.height - y - s.px(90)
        model: s.index ? nav.sectors : []; spacing: s.px(14); clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: nav.sectorIndex
        highlightMoveDuration: s.travel ? s.fast : 0
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Passage {
            required property var modelData
            required property int index
            s: nav.s; sector: modelData; selected: index === nav.sectorIndex
            width: passages.width; height: Math.max(s.px(72), s.px(40) + sector.windows.length * s.row)
            windowPicked: index === nav.sectorIndex ? nav.windowIndex : -1
            onWorkspaceClicked: nav.runAndReport("workspace.focus", {workspace: sector.id}, true)
            onPicked: w => nav.runAndReport("window.focus", {address:w.address}, true)
        }
    }
    Flickable {
        id: spatialViewport
        visible: !s.index
        y: s.px(56); width: parent.width; height: parent.height - y - s.px(90)
        contentHeight: spatial.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
        Grid {
            id: spatial; width: parent.width; columns: nav.columns; spacing: s.px(24)
            Repeater {
                model: !s.index ? nav.sectors : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property var sector: modelData
                    width: (spatial.width - (nav.columns-1)*spatial.spacing)/nav.columns
                    height: s.architecture ? s.px(310) : s.px(226)
                    color: index === nav.sectorIndex ? s.inset : s.surface
                    border.color: index === nav.sectorIndex ? s.accent : s.line
                    border.width: index === nav.sectorIndex ? 2 : 1
                    Ink { s: nav.s; x: s.px(18); y: s.px(14); text: "0"+sector.id; font.pixelSize: s.px(40); font.weight: Font.Light }
                    Ink { s: nav.s; x: s.px(80); y: s.px(30); text: sector.focused ? "CURRENT" : sector.windows.length + (sector.windows.length === 1 ? " window" : " windows"); font.pixelSize: s.small; color: s.dim }
                    MouseArea { anchors.fill: parent; onClicked: nav.runAndReport("workspace.focus", {workspace:sector.id}, true) }
                    Column {
                        x: s.px(18); y: s.px(80); width: parent.width - s.px(36); spacing: s.px(8)
                        Repeater {
                            model: sector.windows
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: parent.width; height: s.row
                                color: s.bg
                                border.color: parent.parent.index === nav.sectorIndex && index === nav.windowIndex ? s.accent : s.line
                                opacity: nav.matches(modelData) ? 1 : 0.35
                                Ink { s: nav.s; x: s.px(10); y: s.px(8); width: parent.width - s.px(20); text: modelData.title || modelData.appId }
                                Ink { s: nav.s; x: s.px(10); y: s.px(32); width: parent.width-s.px(20); text: modelData.appId; font.pixelSize: s.small; color: s.dim }
                                MouseArea { anchors.fill: parent; onClicked: nav.runAndReport("window.focus", {address:modelData.address}, true) }
                            }
                        }
                        Ink { s: nav.s; visible: sector.windows.length === 0; text: "Empty"; color: s.dim }
                    }
                }
            }
        }
    }
    Ink { s: nav.s; y: parent.height - s.px(68); width: parent.width; text: "↑↓" + (s.index ? "" : "←→") + "  workspace     Tab  window     Enter  focus     1–9  jump     M  move     X X  close     /  filter"; font.pixelSize: s.small; color: s.dim }
    Ink { s: nav.s; y: parent.height - s.px(40); width: parent.width; text: nav.statusText || (nav.currentWindow ? Compositor.windowLabel(nav.currentWindow) : "Empty workspace"); font.pixelSize: s.small; color: nav.statusState === "caution" ? s.warning : nav.statusState === "error" ? s.error : s.dim }

    component Passage: Item {
        id: passage
        required property var s
        required property var sector
        property bool selected: false
        property int windowPicked: -1
        signal workspaceClicked()
        signal picked(var w)
        Rectangle { width: parent.width; height: 1; color: s.line }
        Rectangle {
            width: passage.selected ? s.px(100) : s.px(16); height: 3; color: passage.selected ? s.accent : s.line
            Behavior on width { enabled: s.travel; NumberAnimation { duration: s.normal; easing.type: Easing.OutCubic } }
        }
        Ink { s: passage.s; y: s.px(12); text: (sector.id < 10 ? "0" : "") + sector.id; color: passage.selected ? s.accent : s.ink; font.pixelSize: s.px(38); font.weight: Font.Light }
        MouseArea { width: s.px(100); height: parent.height; onClicked: passage.workspaceClicked() }
        Row {
            x: s.px(128); y: s.px(12); spacing: s.px(16)
            Ink { s: passage.s; text: "Workspace " + sector.id; font.pixelSize: s.small; color: s.dim }
            Ink { s: passage.s; text: sector.focused ? "CURRENT" : sector.windows.length === 0 ? "Empty" : sector.windows.length + (sector.windows.length === 1 ? " window" : " windows"); font.pixelSize: s.small; color: sector.focused ? s.accent : s.dim }
        }
        Column {
            x: s.px(128); y: s.px(40); width: parent.width - x
            Repeater {
                model: passage.sector.windows
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: parent.width; height: s.row
                    Rectangle { anchors.fill: parent; color: index === passage.windowPicked && passage.selected ? s.inset : "transparent" }
                    Rectangle { width: s.px(3); height: parent.height - s.px(10); visible: index === passage.windowPicked && passage.selected; color: nav.confirmClose === modelData.address ? s.warning : s.accent }
                    Ink { s: passage.s; x: s.px(16); y: s.px(2); width: parent.width - s.px(32); text: modelData.title || "Untitled"; color: nav.matches(modelData) ? s.ink : s.dim; font.pixelSize: s.px(20) }
                    Ink { s: passage.s; x: s.px(16); y: s.px(30); text: modelData.appId; color: s.dim; font.pixelSize: s.small }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: passage.picked(modelData) }
                }
            }
        }
    }
}
