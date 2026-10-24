import QtQuick
import qs.core
import qs.services

// Five physical sockets in the SHEAR airframe. THEARS is an appearance
// catalogue; PIYTI exposes only the compositor state already available today.
// No process discovery, timer, network, thumbnails or application automation.
Item {
    id: bus
    property bool instrument: false
    readonly property bool compact: width < Theme.du(1050)
    readonly property bool exposed: visible && Window.window && Window.window.visible
    readonly property var windows: Theme.integratedApps && exposed ? Compositor.windows() : []
    readonly property string activeClass: Compositor.activeClass.toLowerCase()
    readonly property var ports: [
        {name:"Firefox", code:"01", kind:"BROWSE", match:"firefox", query:"firefox"},
        {name:"LibreOffice", code:"02", kind:"COMPOSE", match:"libreoffice", query:"libreoffice"},
        {name:"Steam", code:"03", kind:"PLAY", match:"steam", query:"steam"},
        {name:"Discord", code:"04", kind:"CONNECT", match:"discord", query:"discord"},
        {name:"ArtCraft", code:"05", kind:"CREATE", match:"craft", query:"craft"}
    ]
    function matches(appId, port) {
        var id = String(appId || "").toLowerCase();
        if (port.match === "craft") return /(^|[.\/_-])(photo|vector|film|light|pdf|effect|design|fig|word|sound|deck|cad|grid)craft($|[.\/_-])/.test(id);
        if (port.match === "steam") return /^(steam|com\.valvesoftware\.steam)$/.test(id);
        if (port.match === "discord") return /^(discord|discordcanary|discordptb|vesktop|com\.discordapp\.discord|dev\.vencord\.vesktop)$/.test(id);
        return id.indexOf(port.match) >= 0;
    }
    function windowsFor(port) {
        return windows.filter(function(w) { return bus.matches(w.appId, port); });
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
                    text: !Theme.integratedApps ? "FIND APPLICATION  ↗" : !Compositor.available ? "UNAVAILABLE" : socket.linked.length ? socket.linked.length + " KNOWN WINDOW" + (socket.linked.length === 1 ? "" : "S") + " / NAVIGATOR  ↗" : "NO KNOWN WINDOWS / FIND APP  ↗"
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                function activate() {
                    if (Theme.integratedApps && linked.length) Ui.open("navigator");
                    else Ui.openCommand(modelData.query);
                }
                MouseArea {
                    id: pointer; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: socket.activate()
                }
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name + (Theme.integratedApps && linked.length ? ", open Navigator" : ", search applications")
                Accessible.onPressAction: socket.activate()
            }
        }
    }
}
