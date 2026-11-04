import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services
import "../../lib/telemetry.mjs" as T

// The Flight Strip: a thin edge-mounted status strip on its assigned output. It never takes keyboard focus; everything here is also
// reachable through the Command Core.
PanelWindow {
    id: strip
    objectName: "flightStrip"
    property string picker: ""

    required property var outputScreen
    readonly property alias profile: displayProfile
    DisplayProfile {
        id: displayProfile
        persistent: true
        output: strip.outputScreen ? strip.outputScreen.name : ""
    }
    contentItem {
        opacity: displayProfile.opacity
        Behavior on opacity {
            enabled: Theme.animate && targetValue < 1
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
    }
    screen: outputScreen
    visible: Config.strip.visible && outputScreen !== null
    onVisibleChanged: if (!visible) picker = ""
    color: displayProfile.bg
    implicitHeight: Theme.stripHeight
    exclusiveZone: Theme.stripHeight
    anchors {
        left: true
        right: true
        top: Config.strip.edge === "top"
        bottom: Config.strip.edge === "bottom"
    }
    WlrLayershell.namespace: "aerolith-strip"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool hideContent: displayProfile.hideContent
    readonly property bool atTop: Config.strip.edge === "top"
    readonly property string telemetryMode: Config.strip.telemetry
    readonly property bool compact: width < Theme.px(1500)

    // Datum line on the inner edge.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: strip.atTop ? parent.height - height : 0
        height: Theme.border
        color: strip.profile.grid
        opacity: displayProfile.decorationOpacity
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        spacing: Theme.gap

        // Identity mark: opens the Command Core.
        Item {
            opacity: strip.hideContent ? 0 : 1
            Behavior on opacity { enabled: Theme.animate && targetValue < 1; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            enabled: !strip.hideContent
            Layout.fillHeight: true
            implicitWidth: mark.implicitWidth + Theme.pad
            Row {
                id: mark
                anchors.centerIn: parent
                spacing: Theme.px(6)
                Rectangle {
                    width: Theme.px(8)
                    height: width
                    rotation: 45
                    color: "transparent"
                    border.color: Ui.deckOpen ? strip.profile.signal : strip.profile.textDim
                    border.width: Theme.px(2)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    textFormat: Text.PlainText
                    visible: !strip.compact
                    text: "AEROLITH"
                    color: strip.profile.text
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggle("command")
            }
        }

        StripDivider {}

        Flickable {
            opacity: strip.hideContent ? 0 : 1
            Behavior on opacity { enabled: Theme.animate && targetValue < 1; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            enabled: !strip.hideContent
            Layout.fillHeight: true
            Layout.minimumHeight: Theme.stripHeight
            Layout.preferredHeight: Theme.stripHeight
            Layout.preferredWidth: Math.min(workspaces.implicitWidth, strip.width * (strip.compact ? .16 : .24))
            Layout.minimumWidth: Layout.preferredWidth
            contentWidth: workspaces.implicitWidth; contentHeight: height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            WorkspaceTape { profile: strip.profile; id: workspaces; height: Theme.stripHeight; compact: strip.compact }
        }

        StripDivider {}

        // Focused window
        Row {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            visible: Config.strip.showWindowTitle && !strip.compact
            opacity: strip.hideContent ? 0 : 1
            Behavior on opacity { enabled: Theme.animate && targetValue < 1; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            spacing: Theme.gap
            clip: true
            Text {
                textFormat: Text.PlainText
                visible: Compositor.activeClass !== ""
                text: Compositor.activeClass.toUpperCase()
                color: strip.profile.appLink
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Theme.px(140))
                elide: Text.ElideRight
            }
            Text {
                textFormat: Text.PlainText
                text: Compositor.available ? Compositor.activeTitle : "COMPOSITOR LINK DOWN"
                color: Compositor.available ? strip.profile.text : strip.profile.caution
                font.family: Compositor.available ? Theme.sans : Theme.mono
                font.pixelSize: Theme.fontSm
                elide: Text.ElideRight
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Item {
            Layout.fillWidth: !Config.strip.showWindowTitle || strip.compact
        }

        // Annunciators
        Row {
            Layout.fillHeight: true
            spacing: Theme.px(2)

            NetworkIndicator {
                id: networkIndicator
                profile: strip.profile
                compact: strip.compact
                visible: Network.available
                opacity: strip.hideContent ? 0 : 1
                enabled: opacity > 0
                onClicked: strip.picker = strip.picker === "network" ? "" : "network"
            }
            BluetoothIndicator {
                id: bluetoothIndicator
                profile: strip.profile
                compact: strip.compact
                visible: Bluetooth.available
                opacity: strip.hideContent ? 0 : 1
                enabled: opacity > 0
                onClicked: strip.picker = strip.picker === "bluetooth" ? "" : "bluetooth"
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: Compositor.screencastActive
                code: "● SHARE"
                value: Compositor.screencastOwner.toUpperCase()
                status: "critical"
                interactive: false
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: Config.errors.length > 0 || Routines.errors.length > 0
                code: "CFG"
                value: String(Config.errors.length + Routines.errors.length)
                status: "caution"
                onClicked: {
                    const msgs = Config.errors.map(e => e.path + ": " + e.message).concat(Routines.errors.map(e => "routines" + (e.routine ? "/" + e.routine : "") + ": " + e.message));
                    Ui.notify(msgs.length + " configuration problem(s)", "caution", msgs.slice(0, 4).join("\n"));
                }
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: strip.telemetryMode === "always" || (strip.telemetryMode === "alert" && Telemetry.cpuState === "caution")
                code: "CPU"
                value: T.formatPercent(Telemetry.cpu.total)
                status: Telemetry.cpuState === "unknown" ? "unknown" : Telemetry.cpuState
                onClicked: Ui.toggle("systems")
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: strip.telemetryMode === "always" || (strip.telemetryMode === "alert" && Telemetry.memState === "caution")
                code: "MEM"
                value: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)
                status: Telemetry.memState === "unknown" ? "unknown" : Telemetry.memState
                onClicked: Ui.toggle("systems")
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: strip.telemetryMode === "always" || (strip.telemetryMode === "alert" && (Telemetry.tempState === "caution" || Telemetry.tempState === "critical"))
                code: "TMP"
                value: T.formatTemp(Telemetry.temps.cpu)
                status: Telemetry.tempState === "unknown" ? "unknown" : Telemetry.tempState
                onClicked: Ui.toggle("systems")
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: Media.active !== null
                code: Media.playing ? "▶" : "Ⅱ"
                value: {
                    const t = Media.title;
                    return t.length > 26 ? t.slice(0, 25) + "…" : t;
                }
                status: Media.playing ? "active" : "nominal"
                onClicked: m => {
                    if (m.button === Qt.MiddleButton)
                        Registry.run("media.play-pause");
                    else
                        Ui.toggle("signal");
                }
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: true
                code: "AUD"
                value: !Audio.ready || Audio.sink === null || !Audio.volumeKnown ? "N/A" : Audio.muted ? "MUTE" : String(Audio.volumePercent)
                status: !Audio.ready || Audio.sink === null || !Audio.volumeKnown ? "unknown" : Audio.muted ? "caution" : "nominal"
                onClicked: m => {
                    if (m.button === Qt.MiddleButton)
                        Registry.run("audio.mute.toggle");
                    else
                        Ui.toggle("signal");
                }
                onWheel: w => Registry.execute(w.angleDelta.y > 0 ? "audio.volume.up" : "audio.volume.down", {}, {
                        record: false
                    })
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: Audio.ready && Audio.source !== null && Audio.sourceMuted
                code: "MIC"
                value: "MUTE"
                status: "caution"
                onClicked: Registry.run("audio.input.mute.toggle")
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: Power.hasBattery
                code: Power.charging ? "CHG" : "BAT"
                value: Math.round(Power.batteryPercent) + "%"
                status: Power.charging ? "nominal" : T.classify(100 - Power.batteryPercent, 80, 90)
                interactive: false
            }
            Annunciator { profile: strip.profile;
                opacity: strip.hideContent && !raised ? 0 : 1
                enabled: opacity > 0
                compact: strip.compact
                visible: Notifications.enabled && (Notifications.count > 0 || Notifications.doNotDisturb)
                code: Notifications.doNotDisturb ? "DND" : "NTF"
                value: String(Notifications.count)
                status: Notifications.doNotDisturb ? "caution" : "active"
                onClicked: Ui.openCommand("notification")
            }
        }

        StripDivider {}

        StripClock {
            profile: strip.profile
            compact: strip.compact
            Layout.fillHeight: true
        }
    }

    // The lifetime of each surface is the scan/discovery lifetime. Removing an
    // output destroys its loader and releases demand through the picker too.
    LazyLoader {
        id: networkPickerLoader
        objectName: "networkPickerLoader"
        active: strip.picker === "network" && Network.available && !Ui.locked
        NetworkPicker {
            outputScreen: strip.outputScreen
            profile: strip.profile
            anchorX: networkIndicator.mapToItem(strip.contentItem, networkIndicator.width, 0).x
            onDismissed: strip.picker = ""
        }
    }
    LazyLoader {
        id: bluetoothPickerLoader
        objectName: "bluetoothPickerLoader"
        active: strip.picker === "bluetooth" && Bluetooth.available && !Ui.locked
        BluetoothPicker {
            outputScreen: strip.outputScreen
            profile: strip.profile
            anchorX: bluetoothIndicator.mapToItem(strip.contentItem, bluetoothIndicator.width, 0).x
            onDismissed: strip.picker = ""
        }
    }
    Connections {
        target: Ui
        function onLockedChanged() { if (Ui.locked) strip.picker = ""; }
        function onDeckOpenChanged() { if (Ui.deckOpen) strip.picker = ""; }
    }
    Connections {
        target: Tour
        function onActiveChanged() { if (Tour.active) strip.picker = ""; }
    }
    Connections {
        target: Network
        function onAvailableChanged() { if (!Network.available && strip.picker === "network") strip.picker = ""; }
    }
    Connections {
        target: Bluetooth
        function onAvailableChanged() { if (!Bluetooth.available && strip.picker === "bluetooth") strip.picker = ""; }
    }

    component StripDivider: Rectangle {
        Layout.preferredWidth: Theme.border
        Layout.fillHeight: true
        Layout.topMargin: Theme.px(7)
        Layout.bottomMargin: Theme.px(7)
        color: strip.profile.grid
        opacity: displayProfile.decorationOpacity
    }
}
