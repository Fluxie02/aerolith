import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services
import "../../lib/telemetry.mjs" as T

// The Flight Strip: a thin edge-mounted status strip on the one display
// AEROLITH runs on. It never takes keyboard focus; everything here is also
// reachable through the Command Core.
PanelWindow {
    id: strip

    screen: Ui.screen
    visible: Config.strip.visible && Ui.screen !== null
    color: Theme.bg
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

    readonly property bool atTop: Config.strip.edge === "top"
    readonly property string telemetryMode: Config.strip.telemetry
    readonly property bool compact: width < Theme.px(1500)

    // Datum line on the inner edge.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: strip.atTop ? parent.height - height : 0
        height: Theme.border
        color: Theme.grid
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        spacing: Theme.gap

        // Identity mark: opens the Command Core.
        Item {
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
                    border.color: Ui.deckOpen ? Theme.signal : Theme.textDim
                    border.width: Theme.px(2)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    textFormat: Text.PlainText
                    visible: !strip.compact
                    text: "AEROLITH"
                    color: Theme.text
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
            Layout.fillHeight: true
            Layout.minimumHeight: Theme.stripHeight
            Layout.preferredHeight: Theme.stripHeight
            Layout.preferredWidth: Math.min(workspaces.implicitWidth, strip.width * (strip.compact ? .16 : .24))
            Layout.minimumWidth: Layout.preferredWidth
            contentWidth: workspaces.implicitWidth; contentHeight: height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            WorkspaceTape { id: workspaces; height: Theme.stripHeight; compact: strip.compact }
        }

        StripDivider {}

        // Focused window
        Row {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            visible: Config.strip.showWindowTitle && !strip.compact
            spacing: Theme.gap
            clip: true
            Text {
                textFormat: Text.PlainText
                visible: Compositor.activeClass !== ""
                text: Compositor.activeClass.toUpperCase()
                color: Theme.signal
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
                color: Compositor.available ? Theme.text : Theme.caution
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

            Annunciator {
                compact: strip.compact
                visible: Compositor.screencastActive
                code: "● SHARE"
                value: Compositor.screencastOwner.toUpperCase()
                status: "critical"
                interactive: false
            }
            Annunciator {
                compact: strip.compact
                visible: Ui.multipleDisplays && Config.display.warnOnMultipleDisplays
                code: "DISP"
                value: "1/" + Ui.screenCount
                status: "caution"
                onClicked: Ui.notify("AEROLITH runs on one display (" + Ui.screenName + "). Other outputs are left untouched.", "caution", "Set display.output in config.json to choose the output.")
            }
            Annunciator {
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
            Annunciator {
                compact: strip.compact
                visible: strip.telemetryMode === "always" || (strip.telemetryMode === "alert" && Telemetry.cpuState === "caution")
                code: "CPU"
                value: T.formatPercent(Telemetry.cpu.total)
                status: Telemetry.cpuState === "unknown" ? "unknown" : Telemetry.cpuState
                onClicked: Ui.toggle("systems")
            }
            Annunciator {
                compact: strip.compact
                visible: strip.telemetryMode === "always" || (strip.telemetryMode === "alert" && Telemetry.memState === "caution")
                code: "MEM"
                value: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)
                status: Telemetry.memState === "unknown" ? "unknown" : Telemetry.memState
                onClicked: Ui.toggle("systems")
            }
            Annunciator {
                compact: strip.compact
                visible: strip.telemetryMode === "always" || (strip.telemetryMode === "alert" && (Telemetry.tempState === "caution" || Telemetry.tempState === "critical"))
                code: "TMP"
                value: T.formatTemp(Telemetry.temps.cpu)
                status: Telemetry.tempState === "unknown" ? "unknown" : Telemetry.tempState
                onClicked: Ui.toggle("systems")
            }
            Annunciator {
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
            Annunciator {
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
            Annunciator {
                compact: strip.compact
                visible: Audio.ready && Audio.source !== null && Audio.sourceMuted
                code: "MIC"
                value: "MUTE"
                status: "caution"
                onClicked: Registry.run("audio.input.mute.toggle")
            }
            Annunciator {
                compact: strip.compact
                visible: Power.hasBattery
                code: Power.charging ? "CHG" : "BAT"
                value: Math.round(Power.batteryPercent) + "%"
                status: Power.charging ? "nominal" : T.classify(100 - Power.batteryPercent, 80, 90)
                interactive: false
            }
            Annunciator {
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
            compact: strip.compact
            Layout.fillHeight: true
        }
    }

    component StripDivider: Rectangle {
        Layout.preferredWidth: Theme.border
        Layout.fillHeight: true
        Layout.topMargin: Theme.px(7)
        Layout.bottomMargin: Theme.px(7)
        color: Theme.grid
    }
}
