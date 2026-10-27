import QtQuick
import qs.core
import qs.services
import "../lib/appbus.mjs" as Bus

// A single row of the user's applications. Sol can bind rankedEntries to
// Apps' forthcoming ordered desktop-entry list; no usage ranking lives here.
Item {
    id: bus
    property bool instrument: false
    property var rankedEntries: []
    readonly property bool exposed: visible && Window.window && Window.window.visible
    readonly property var windows: exposed ? Compositor.windows() : []
    readonly property int capacity: Math.max(1, Math.floor((width - more.width - Theme.du(8)) / Theme.du(140)))
    readonly property var ports: {
        const entries = rankedEntries.length ? rankedEntries : Array.from(Apps.entries).sort((a, b) => a.name.localeCompare(b.name));
        const out = [];
        function add(port) {
            if (!out.some(p => p.match === port.match)) out.push(port);
        }
        function fromEntry(e) {
            const known = Bus.PORTS.find(p => Bus.matches(e.id, p));
            return { name: e.name, icon: e.icon || "", match: known ? known.match : String(e.id).replace(/\.desktop$/, "").toLowerCase(),
                desktopIds: [e.id], query: e.name };
        }
        // Running apps come first until the service supplies its ranked list.
        if (!rankedEntries.length) {
            for (const w of windows) {
                if (!w.appId) continue;
                const known = Bus.PORTS.find(p => Bus.matches(w.appId, p));
                const probe = known || {match: String(w.appId).toLowerCase(), desktopIds: []};
                const exact = Array.from(Apps.entries).find(e => String(e.id).replace(/\.desktop$/, "").toLowerCase() === String(w.appId).toLowerCase());
                const e = exact || Bus.entryFor(Apps.entries, probe);
                add(e ? fromEntry(e) : {name: w.appId || "Application", icon: "", match: probe.match, desktopIds: [], query: w.appId});
            }
        }
        for (const e of entries) add(fromEntry(e));
        return out.slice(0, capacity);
    }
    function activate(port) {
        const a = Bus.action(Compositor.windows(), port, Compositor.activeAddress, Apps.entries);
        if (a.kind === "focus") Registry.run("window.focus", { address: a.address });
        else if (a.kind === "launch") Registry.run("app.launch", { app: a.id });
        else if (a.kind === "search") { Ui.openCommand(a.query); return; }
        if (instrument && a.kind !== "none") Ui.close();
    }
    opacity: instrument ? 1 : Math.max(0, Math.min(1, (Theme.bootProgress - .62) / .30))
    Rectangle { anchors.fill: parent; color: Theme.bg }
    Rectangle { width: parent.width; height: Theme.border; color: Theme.grid }
    Row {
        id: sockets
        y: Theme.du(4); height: parent.height - y; spacing: Theme.du(6)
        Repeater {
            model: bus.ports
            delegate: Rectangle {
                id: socket
                required property var modelData
                readonly property int windowCount: bus.windows.filter(w => Bus.matches(w.appId, modelData)).length
                readonly property bool current: Bus.matches(Compositor.activeClass, modelData)
                width: Math.min(Theme.du(164), (bus.width - more.width - Theme.du(8)) / Math.max(1, bus.ports.length) - sockets.spacing)
                height: sockets.height
                color: pointer.containsMouse || current ? Theme.surface2 : Theme.bg
                border.width: activeFocus ? Theme.du(2) : 0; border.color: Theme.signal
                activeFocusOnTab: true
                Keys.onReturnPressed: bus.activate(modelData)
                Keys.onSpacePressed: bus.activate(modelData)
                AppGlyph {
                    x: Theme.du(10); anchors.verticalCenter: parent.verticalCenter
                    size: Theme.du(24); icon: socket.modelData.icon; fallback: socket.modelData.name
                }
                Text {
                    x: Theme.du(43); anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - Theme.du(8)
                    text: socket.modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight
                    color: socket.current ? Theme.appLink : Theme.text
                    font.family: Theme.sans; font.pixelSize: Theme.fontSm
                }
                Rectangle {
                    visible: socket.windowCount > 0
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: socket.current ? parent.width - Theme.du(16) : Theme.du(14); height: Theme.du(2)
                    color: socket.current ? Theme.appLink : Theme.textDim
                }
                MouseArea {
                    id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: bus.activate(socket.modelData)
                }
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name + (windowCount ? ", " + windowCount + " windows, switch" : ", open")
                Accessible.onPressAction: bus.activate(modelData)
            }
        }
    }
    Rectangle {
        id: more
        anchors.right: parent.right; y: sockets.y
        width: Theme.du(104); height: sockets.height
        color: morePointer.containsMouse ? Theme.surface2 : Theme.bg
        border.color: activeFocus ? Theme.signal : Theme.grid
        activeFocusOnTab: true
        Keys.onReturnPressed: Ui.openCommand("")
        Keys.onSpacePressed: Ui.openCommand("")
        Text {
            anchors.centerIn: parent; text: "ALL APPS  ↗"; textFormat: Text.PlainText
            color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs
        }
        MouseArea {
            id: morePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: Ui.openCommand("")
        }
        Accessible.role: Accessible.Button; Accessible.name: "Search all applications"
        Accessible.onPressAction: Ui.openCommand("")
    }
}
