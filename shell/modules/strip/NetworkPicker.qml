import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// Constructed only while open. Secrets live solely in the masked TextInput.
PanelWindow {
    id: picker
    objectName: bluetooth ? "bluetoothPicker" : "networkPicker"
    required property var outputScreen
    property var profile: Theme
    property real anchorX: width - Theme.pad
    property bool bluetooth: false
    property string passwordName: ""
    property string feedback: ""
    property var passwordRows: []
    onPasswordNameChanged: if (passwordName === "") passwordRows = []
    signal dismissed()
    screen: outputScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: bluetooth ? "aerolith-bluetooth" : "aerolith-network"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        if (bluetooth) Bluetooth.requestDiscovery(); else Network.requestScan();
        navigation.forceActiveFocus();
    }
    Component.onDestruction: {
        if (bluetooth) Bluetooth.releaseDiscovery(); else Network.releaseScan();
    }

    readonly property var rows: {
        // Keep the input alive while scan results arrive or change order.
        if (!bluetooth && passwordName !== "") return passwordRows;
        if (bluetooth) return [{kind: "power", name: "BLUETOOTH", detail: Bluetooth.powered ? "On · select to turn off" : "Off · select to turn on", badge: Bluetooth.powered ? "ON" : "OFF"}]
            .concat(Bluetooth.powered ? Bluetooth.devices.map(d => ({kind: "device", name: d.name, detail: d.connecting ? "Connecting…" : d.connected ? "Connected · select to disconnect" : d.paired ? "Paired · select to connect" : "New device · select to pair", badge: d.battery >= 0 ? d.battery + "%" : d.connected ? "CONNECTED" : d.paired ? "PAIRED" : "PAIR", data: d})) : []);
        let result = [];
        if (Network.wifiAvailable) result.push({kind: "power", name: "WI-FI", detail: Network.wifiEnabled ? "On · select to turn off" : "Off · select to turn on", badge: Network.wifiEnabled ? "ON" : "OFF"});
        if (Network.kind === "ethernet") result.push({kind: "wired", name: Network.connectionName || "Ethernet", detail: "Wired · select to disconnect all", badge: "CONNECTED"});
        if (Network.wifiEnabled) result = result.concat(Network.networks.map(n => ({kind: "network", name: n.name, detail: n.failed ? failureWords(n.failReason) : n.connecting ? "Connecting…" : n.connected ? "Connected · select to disconnect all" : (n.secured ? "Locked" : "Open") + (n.known ? " · saved" : n.secured ? " · password needed" : " · select to connect"), badge: n.signal + "%", data: n})));
        return result;
    }
    function failureWords(reason) {
        if (/password|secret|auth/i.test(reason)) return "Could not sign in. Check the password and try again.";
        if (/notfound|outofrange|accesspoint/i.test(reason)) return "Network out of reach. Move closer and try again.";
        if (/cancel/i.test(reason)) return "Connection cancelled. Select to try again.";
        return "Could not connect. Select to try again.";
    }
    function activate(row) {
        passwordName = "";
        feedback = "";
        let result;
        if (row.kind === "power") result = bluetooth ? Bluetooth.setPowered(!Bluetooth.powered) : Network.setWifiEnabled(!Network.wifiEnabled);
        else if (row.kind === "wired" || row.kind === "network" && row.data.connected) result = Network.disconnect();
        else if (row.kind === "network") {
            if (row.data.connecting) return;
            if (row.data.secured && !row.data.known && !row.data.takesPassword) {
                feedback = row.name + " needs an enterprise sign-in (user name and certificate). Set it up once in your network settings, for example with nmtui; after that it shows as saved.";
                return;
            }
            if (row.data.secured && !row.data.known) { passwordRows = rows; passwordName = row.name; return; }
            result = Network.connect(row.name);
        } else {
            if (row.data.connecting) return;
            result = row.data.connected ? Bluetooth.disconnect(row.data.address)
                : row.data.paired ? Bluetooth.connect(row.data.address) : Bluetooth.pair(row.data.address);
            if (!row.data.paired && !row.data.connected) feedback = "Accept any pairing request on your device, then select it to connect.";
        }
        if (result && result.ok === false) feedback = result.message || "The action could not be completed. Try again.";
    }

    MouseArea { objectName: "pickerOutside"; anchors.fill: parent; onClicked: picker.dismissed() }
    FocusScope {
        id: navigation
        objectName: "pickerNavigation"
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: picker.dismissed()
        Keys.onUpPressed: {
            picker.passwordName = "";
            list.currentIndex = Math.max(0, list.currentIndex - 1);
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            navigation.forceActiveFocus();
        }
        Keys.onDownPressed: {
            picker.passwordName = "";
            list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            navigation.forceActiveFocus();
        }
        Keys.onReturnPressed: if (picker.rows[list.currentIndex]) picker.activate(picker.rows[list.currentIndex])
        Keys.onEnterPressed: if (picker.rows[list.currentIndex]) picker.activate(picker.rows[list.currentIndex])
        Bezel {
            id: housing
            objectName: "pickerHousing"
            profile: picker.profile
            x: Math.max(Theme.pad, Math.min(picker.anchorX - width, picker.width - width - Theme.pad))
            y: Config.strip.edge === "top" ? Theme.stripHeight + Theme.du(10) : picker.height - height - Theme.stripHeight - Theme.du(10)
            width: Math.min(Theme.du(440), picker.width - Theme.pad * 2)
            height: Math.min(picker.height - Theme.stripHeight - Theme.du(36), headerHeight + contentPadding * 2 + picker.rows.reduce((h, r) => h + Theme.du(r.data && r.data.failed ? 86 : 68), 0) - Theme.du(4) + (picker.passwordName !== "" ? Theme.du(100) : 0) + footer.implicitHeight + Theme.du(12))
            contentPadding: Theme.du(20)
            titleHeight: Theme.du(48)
            title: picker.bluetooth ? "BLUETOOTH" : "NETWORK"
            designation: ""
            status: "ESC TO CLOSE"
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { enabled: Theme.animate; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
            // Eat clicks on blank space in the housing, before the outside area.
            MouseArea { anchors.fill: parent; onClicked: navigation.forceActiveFocus() }
            Column {
                anchors.fill: parent
                spacing: Theme.du(12)
                ListView {
                    id: list
                    objectName: "pickerList"
                    width: parent.width
                    height: Math.max(0, parent.height - footer.height - parent.spacing)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: picker.rows
                    currentIndex: 0
                    spacing: Theme.du(4)
                    onCountChanged: currentIndex = Math.max(0, Math.min(currentIndex, count - 1))
                    delegate: Item {
                        id: row
                        objectName: "pickerRow-" + modelData.name
                        required property var modelData
                        required property int index
                        readonly property bool selected: list.currentIndex === index
                        width: list.width
                        readonly property real rowHeight: Theme.du(modelData.data && modelData.data.failed ? 82 : 64)
                        height: rowHeight + (password.active ? Theme.du(100) : 0)
                        Rectangle {
                            width: parent.width; height: row.rowHeight
                            color: row.selected ? picker.profile.surface2 : picker.profile.bg
                            border.color: row.selected ? picker.profile.signal : picker.profile.grid
                            border.width: Theme.border
                            Rectangle { visible: !!row.modelData.data && row.modelData.data.connected === true; width: Theme.du(3); height: parent.height; color: picker.profile.signal }
                            Column {
                                x: Theme.du(14); anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - badge.width - Theme.du(42); spacing: Theme.du(5)
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: row.modelData.name; textFormat: Text.PlainText
                                    font.family: Theme.sans; font.pixelSize: Theme.fontMd; font.weight: Font.Medium
                                    color: picker.profile.text
                                }
                                Text {
                                    width: parent.width; wrapMode: Text.WordWrap
                                    text: row.modelData.detail; textFormat: Text.PlainText
                                    font.family: Theme.sans; font.pixelSize: Theme.fontXs
                                    color: row.modelData.data && row.modelData.data.failed ? picker.profile.caution : picker.profile.textDim
                                }
                            }
                            Item {
                                objectName: "networkLock"
                                visible: !!row.modelData.data && row.modelData.data.secured === true
                                anchors.right: badge.left; anchors.rightMargin: Theme.du(8); anchors.verticalCenter: parent.verticalCenter
                                width: Theme.du(12); height: Theme.du(16)
                                Rectangle { x: Theme.du(3); width: Theme.du(6); height: Theme.du(9); radius: Theme.du(3); color: "transparent"; border.color: picker.profile.textDim }
                                Rectangle { y: Theme.du(6); width: parent.width; height: Theme.du(9); color: picker.profile.bg; border.color: picker.profile.textDim }
                            }
                            Text {
                                id: badge
                                anchors.right: parent.right; anchors.rightMargin: Theme.du(12); anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.badge; textFormat: Text.PlainText
                                font.family: Theme.mono; font.pixelSize: Theme.fontXs
                                color: picker.profile.signal
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { list.currentIndex = row.index; navigation.forceActiveFocus(); picker.activate(row.modelData); }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: row.modelData.name + ", " + row.modelData.detail
                            Accessible.onPressAction: { list.currentIndex = row.index; picker.activate(row.modelData); }
                        }
                        Loader {
                            id: password
                            objectName: "networkPasswordRow"
                            y: row.rowHeight + Theme.du(6); width: parent.width
                            active: row.modelData.kind === "network" && picker.passwordName === row.modelData.name
                            onLoaded: { list.forceLayout(); list.positionViewAtIndex(row.index, ListView.Contain); }
                            sourceComponent: Column {
                                width: password.width; spacing: Theme.du(8)
                                Text {
                                    text: "PASSWORD · ENTER TO CONNECT"; textFormat: Text.PlainText
                                    font.family: Theme.mono; font.pixelSize: Theme.fontXs; color: picker.profile.textDim
                                }
                                Rectangle {
                                    width: parent.width; height: Theme.du(40)
                                    color: picker.profile.bg; border.color: picker.profile.signal
                                    TextInput {
                                        id: secret
                                        objectName: "networkPasswordInput"
                                        anchors.fill: parent; anchors.margins: Theme.du(10)
                                        color: picker.profile.text; selectionColor: picker.profile.signal; selectedTextColor: picker.profile.bg
                                        font.family: Theme.sans; font.pixelSize: Theme.fontMd
                                        echoMode: TextInput.Password
                                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                                        clip: true
                                        function submit() {
                                            const result = Network.connectWithPsk(row.modelData.name, text);
                                            clear();
                                            if (result && result.ok === false) picker.feedback = result.message || "Could not connect. Try again.";
                                            picker.passwordName = "";
                                            navigation.forceActiveFocus();
                                        }
                                        Keys.onReturnPressed: submit()
                                        Keys.onEnterPressed: submit()
                                        Keys.onEscapePressed: { clear(); picker.dismissed(); }
                                        Component.onCompleted: forceActiveFocus()
                                        Component.onDestruction: clear()
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    id: footer
                    objectName: "pickerHint"
                    width: parent.width; wrapMode: Text.WordWrap
                    text: picker.feedback || (picker.bluetooth ? !Bluetooth.powered ? "Turn Bluetooth on to find your devices." : Bluetooth.devices.length ? "Connected devices first, then paired devices.\n↑ ↓ CHOOSE   ENTER SELECT" : "Looking for devices. Put your device in pairing mode." : !Network.wifiAvailable ? Network.kind === "ethernet" ? "Your wired connection is ready." : "No Wi-Fi adapter. Connect an Ethernet cable to get online." : !Network.wifiEnabled ? "Turn Wi-Fi on to find a network." : Network.networks.length ? "Connected networks first, then saved networks.\n↑ ↓ CHOOSE   ENTER SELECT" : "Looking for networks. Move closer to your router.")
                    textFormat: Text.PlainText; color: picker.profile.textDim
                    font.family: Theme.sans; font.pixelSize: Theme.fontXs; lineHeight: 1.35
                }
            }
        }
    }
}
