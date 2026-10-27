import QtQuick
import qs.core
import qs.services
import "../lib/telemetry.mjs" as T

// A working section through the airframe: identity on the right, workspace
// in the exposed annulus, existing service samples on the lower datum.
Item {
    id: rig
    property bool instrument: false
    readonly property bool compact: width < Theme.du(1500) || height < Theme.du(850)
    readonly property var windows: Compositor.windows()
    readonly property string ws: Compositor.focusedWorkspaceId > 0 ? ("0" + Compositor.focusedWorkspaceId).slice(-2) : "N/A"
    readonly property string cpu: T.formatPercent(Telemetry.cpu.total)
    readonly property string mem: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)
    readonly property real ignition: instrument ? 1 : Theme.bootProgress
    readonly property var entryBays: [{label:"SEARCH",bay:"command"}, {label:"WINDOWS",bay:"navigator"}, {label:"SYSTEM MONITOR",bay:"systems"}, {label:"SETTINGS",bay:"settings"}]
    opacity: Math.min(1, ignition * 3)

    Column {
        x: parent.width * .055
        y: Math.max(Theme.stripHeight + Theme.du(18), parent.height * .068)
        spacing: Theme.du(12)
        visible: !rig.instrument || !rig.compact
        Text {
            text: "AEROLITH   /   YOUR WORKSPACE"
            textFormat: Text.PlainText; color: Theme.signal
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1.6
        }
        Text {
            visible: !rig.compact
            text: "WORKSPACE " + rig.ws + "   /   " + rig.windows.length + " WINDOWS   /   " + (Compositor.available ? "DESKTOP CONNECTED" : "DESKTOP UNAVAILABLE")
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        Text {
            visible: !rig.compact
            text: "CPU " + rig.cpu + "    MEMORY " + rig.mem
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
    }

    // The dominant number always means the actual focused workspace.
    Column {
        x: parent.width * .135; y: parent.height * .365
        width: parent.width * .24; spacing: Theme.du(5)
        visible: !rig.instrument
        opacity: Math.max(0, Math.min(1, (rig.ignition - .08) / .26))
        Text {
            text: "ACTIVE / WORKSPACE"; textFormat: Text.PlainText
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; color: Theme.signal; font.letterSpacing: 1
        }
        Text {
            text: rig.ws; textFormat: Text.PlainText
            font.family: Theme.displaySans
            // At 720p / uiScale 1.5 the application bus must leave both the
            // focused class and the full title line visible above it.
            font.pixelSize: Math.min(Theme.du(Theme.insane ? 192 : 170), rig.height * (rig.compact ? .15 : .24))
            font.weight: Font.ExtraLight; font.letterSpacing: -8; color: Theme.text
            lineHeight: .9
        }
        Row {
            spacing: Theme.du(7)
            Rectangle { width: Theme.du(22); height: Theme.du(3); color: Theme.signal; anchors.verticalCenter: parent.verticalCenter }
            Text {
                width: rig.width * .19; elide: Text.ElideRight
                text: Compositor.activeClass ? Compositor.activeClass.toUpperCase() : "NO FOCUSED APPLICATION"
                textFormat: Text.PlainText; color: Theme.signal
                font.family: Theme.mono; font.pixelSize: Theme.fontSm
            }
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            visible: !rig.compact
            text: Compositor.activeTitle || "Search for an app to begin"
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.sans; font.pixelSize: Theme.fontMd
        }
    }

    Column {
        x: parent.width * .69; y: parent.height * .27
        width: parent.width * .25
        spacing: Theme.du(24); visible: !rig.instrument
        opacity: Math.max(0, Math.min(1, (rig.ignition - .22) / .30))
        NowPlaying { width: parent.width }
        Flow {
            width: parent.width; spacing: Theme.du(5)
            Repeater {
                model: rig.entryBays
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - Theme.du(5)) / 2; height: Theme.du(34)
                    color: entryPointer.containsMouse ? Theme.signal : Theme.bg
                    border.color: entryPointer.containsMouse ? Theme.signal : Theme.grid
                    Text {
                        anchors.centerIn: parent; width: parent.width - Theme.du(8)
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: modelData.label; textFormat: Text.PlainText
                        color: entryPointer.containsMouse ? Theme.bg : Theme.text
                        font.family: Theme.mono; font.pixelSize: Theme.fontXs
                    }
                    MouseArea {
                        id: entryPointer; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: Ui.open(modelData.bay)
                    }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.label
                    Accessible.onPressAction: Ui.open(modelData.bay)
                }
            }
        }
    }

    // A narrow window register occupies the clear side of the structural fins.
    Column {
        x: parent.width * .70; y: parent.height * .66; width: parent.width * .24
        spacing: Theme.du(8); visible: !rig.instrument && !rig.compact
        opacity: Math.max(0, Math.min(1, (rig.ignition - .48) / .26))
        Text {
            text: "OPEN WINDOWS / " + rig.windows.length; textFormat: Text.PlainText
            color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
        }
        Repeater {
            model: rig.windows.slice(0, 3)
            delegate: Item {
                required property var modelData
                width: parent.width; height: Theme.du(32)
                Rectangle { width: parent.width; height: 1; color: Theme.grid }
                Text {
                    y: Theme.du(9); width: parent.width - Theme.du(38); elide: Text.ElideRight
                    text: modelData.title; textFormat: Text.PlainText; color: Theme.text
                    font.family: Theme.sans; font.pixelSize: Theme.fontSm
                }
                Text {
                    anchors.right: parent.right; y: Theme.du(9)
                    text: "W" + modelData.workspaceId; textFormat: Text.PlainText
                    color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Registry.run("window.focus", { address: modelData.address });
                        if (rig.instrument)
                            Ui.close();
                    }
                }
            }
        }
    }

    // The core comb uses the service's existing samples. It never polls.
    Item {
        x: parent.width * .69; y: parent.height * .105
        width: parent.width * .25; height: parent.height * .085
        visible: !rig.compact && !rig.instrument
        Text {
            text: "CPU CORES / " + Math.min(Theme.insane ? 64 : 32, Telemetry.cpu.cores.length) + " OF " + Telemetry.cpu.cores.length
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontXs
        }
        Row {
            id: coreRow
            y: Theme.du(21); height: parent.height - y; width: parent.width; spacing: Theme.du(3)
            Repeater {
                model: Telemetry.cpu.cores.slice(0, Theme.insane ? 64 : 32)
                delegate: Item {
                    id: core
                    required property var modelData
                    readonly property bool known: modelData !== null && modelData !== undefined && isFinite(modelData)
                    width: Math.max(1, Math.min(Theme.du(14), (coreRow.width - Math.max(0, coreRepeater.count - 1) * coreRow.spacing) / Math.max(1, coreRepeater.count)))
                    height: coreRow.height
                    Rectangle { anchors.fill: parent; color: Theme.surface; border.width: core.known ? 0 : Theme.border; border.color: Theme.textDim }
                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width
                        height: core.known ? Math.max(1, parent.height * Math.min(100, modelData) / 100) : 0
                        color: Theme.signal
                    }
                }
                id: coreRepeater
            }
        }
    }

    WorkspaceOrbit { anchors.fill: parent; instrument: rig.instrument; visible: !rig.instrument }
    Text {
        x: parent.width * .055; y: parent.height * .846
        visible: !rig.instrument && !rig.compact
        text: "WORKSPACES / CLICK TO SWITCH"; textFormat: Text.PlainText
        color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
    }

    // THEARS offers native surfaces; PIYTI exposes real window continuity.
    AppContinuity {
        x: parent.width * .055; y: parent.height - height - Theme.du(16) - (Config.strip.edge === "bottom" ? Theme.stripHeight : 0)
        width: parent.width * .885
        height: Theme.du(48)
        visible: !rig.instrument
        instrument: rig.instrument
    }
    Text {
        x: parent.width * .055; y: parent.height * .815
        visible: !rig.instrument && Theme.bootProgress < 1
        text: "ASSEMBLING / " + Math.round(Theme.bootProgress * 100) + "%"; textFormat: Text.PlainText
        color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
    }
}
