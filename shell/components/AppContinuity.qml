import QtQuick
import qs.core
import qs.services
import "../lib/appbus.mjs" as Bus

// Five physical sockets in the SHEAR airframe. A socket switches to its
// application's window when it runs (again: its next window) and starts it
// when it is installed but not running; only an application that is not
// installed opens the search (lib/appbus.mjs). PIYTI also shows the link
// state. No process discovery, timer, network or thumbnails.
Item {
    id: bus
    property bool instrument: false
    readonly property bool compact: width < Theme.du(1050)
    readonly property bool exposed: visible && Window.window && Window.window.visible
    readonly property var windows: exposed ? Compositor.windows() : []
    readonly property string activeClass: Compositor.activeClass.toLowerCase()
    readonly property var ports: Bus.PORTS
    function matches(appId, port) {
        return Bus.matches(appId, port);
    }
    function windowsFor(port) {
        return windows.filter(function(w) { return bus.matches(w.appId, port); });
    }
    function activate(port) {
        // Read the windows now, not the last exposed snapshot.
        const a = Bus.action(Compositor.windows(), port, Compositor.activeAddress, Apps.entries);
        if (a.kind === "focus")
            Registry.run("window.focus", { address: a.address });
        else if (a.kind === "launch")
            Registry.run("app.launch", { app: a.id });
        else if (a.kind === "search") {
            Ui.openCommand(a.query);
            return;
        }
        // From the Deck, get out of the way of the window.
        if (bus.instrument && a.kind !== "none")
            Ui.close();
    }
    opacity: instrument ? 1 : Math.max(0, Math.min(1, (Theme.bootProgress - .62) / .30))

    Rectangle { anchors.fill: parent; color: Theme.bg }
    Rectangle { width: parent.width; height: Theme.border; color: Theme.grid }
    Text {
        y: Theme.du(9)
        text: Theme.applicationName + (Theme.integratedApps ? " / APPLICATION BUS" : " / SHARED MATERIAL")
        textFormat: Text.PlainText; color: Theme.appLink
        font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1.2
    }
    Text {
        anchors.right: parent.right; y: Theme.du(9)
        text: Theme.integratedApps ? (Compositor.available ? "WINDOW SNAPSHOT / NAVIGATOR REFRESHES" : "WINDOW LINK / UNAVAILABLE") : "SHEAR / FIVE APP ADAPTERS"
        textFormat: Text.PlainText; color: Theme.textDim
        font.family: Theme.mono; font.pixelSize: Theme.fontXs
        visible: !bus.compact
    }
    Row {
        id: sockets
        y: Theme.du(30); width: parent.width
        spacing: Theme.du(8)
        Repeater {
            model: bus.ports
            delegate: Item {
                id: socket
                required property var modelData
                required property int index
                readonly property var linked: bus.windowsFor(modelData)
                readonly property bool installed: Bus.entryFor(Apps.entries, modelData) !== null
                readonly property bool current: Theme.integratedApps && bus.matches(bus.activeClass, modelData)
                readonly property color ink: current ? Theme.appLink : Theme.signal
                property real reach: current ? 1 : 0
                width: (sockets.width - 4 * sockets.spacing) / 5
                height: Math.max(Theme.du(64), bus.height - sockets.y - Theme.du(7))
                clip: true
                activeFocusOnTab: true
                Keys.onReturnPressed: activate()
                Keys.onEnterPressed: activate()
                Keys.onSpacePressed: activate()
                Rectangle {
                    anchors.fill: parent
                    color: pointer.containsMouse || socket.current ? Theme.surface2 : Theme.surface
                    border.width: socket.activeFocus ? Theme.du(2) : Theme.border
                    border.color: socket.activeFocus ? Theme.signal : socket.current ? Theme.appLink : Theme.grid
                }
                // Opposed seams echo SHEAR's pressure skin using retained
                // rectangles. Content keeps a full rectangular working area.
                Rectangle {
                    x: Theme.du(8); y: 0; width: parent.width - Theme.du(16); height: Theme.du(2)
                    color: socket.ink
                }
                Item {
                    x: Theme.du(8); y: parent.height - Theme.du(3)
                    width: parent.width - Theme.du(16); height: Theme.du(3)
                    clip: true; visible: Theme.integratedApps
                    Rectangle {
                        width: parent.width; height: parent.height
                        x: (socket.reach - 1) * width
                        color: Theme.appLink
                        Behavior on x { enabled: Theme.travel && Theme.ambient && bus.exposed; XAnimator { id: latch; duration: Theme.slow; easing.type: Easing.OutCubic } }
                        Connections {
                            target: bus
                            function onExposedChanged() { if (!bus.exposed) latch.complete(); }
                        }
                        Connections {
                            target: Theme
                            function onTravelChanged() { if (!Theme.travel) latch.complete(); }
                            function onAmbientChanged() { if (!Theme.ambient) latch.complete(); }
                        }
                    }
                }
                Text {
                    x: Theme.du(11); y: Theme.du(10)
                    text: modelData.code + " / " + modelData.kind; textFormat: Text.PlainText
                    color: socket.ink; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                Text {
                    x: Theme.du(11); y: Theme.du(25); width: parent.width - 2*x
                    text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Theme.text; font.family: Theme.displaySans
                    font.pixelSize: bus.compact ? Theme.fontMd : Theme.du(20); font.weight: Font.Medium
                }
                Text {
                    x: Theme.du(11); y: Theme.du(51); width: parent.width - 2*x
                    visible: parent.height >= Theme.du(85)
                    text: socket.linked.length ? socket.linked.length + " WINDOW" + (socket.linked.length === 1 ? "" : "S") + " / SWITCH  ↗" : socket.installed ? "NOT RUNNING / OPEN  ↗" : "NOT INSTALLED / FIND  ↗"
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                function activate() {
                    bus.activate(modelData);
                }
                MouseArea {
                    id: pointer; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: socket.activate()
                }
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name + (linked.length ? ", switch to its window" : installed ? ", start it" : ", not installed: search")
                Accessible.onPressAction: socket.activate()
            }
        }
    }
}
