import QtQuick
import qs.core
import qs.services
import "../lib/telemetry.mjs" as T

// A working section through the airframe: identity on the right, workspace
// in the exposed annulus, existing service samples on the lower datum.
Item {
    id: rig
    property var profile: Theme
    property bool instrument: false
    readonly property var geometry: Theme.groundGeometry(width, height, Screen.name)
    readonly property bool compact: geometry.compact
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
            textFormat: Text.PlainText; color: rig.profile.signal
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1.6
        }
        Text {
            visible: !rig.compact
            text: "WORKSPACE " + rig.ws + "   /   " + rig.windows.length + " WINDOWS   /   " + (Compositor.available ? "DESKTOP CONNECTED" : "DESKTOP UNAVAILABLE")
            textFormat: Text.PlainText; color: rig.profile.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        Text {
            visible: !rig.compact
            text: "CPU " + rig.cpu + "    MEMORY " + rig.mem
            textFormat: Text.PlainText; color: rig.profile.textDim
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
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; color: rig.profile.signal; font.letterSpacing: 1
        }
        Text {
            text: rig.ws; textFormat: Text.PlainText
            font.family: Theme.displaySans
            // At 720p / uiScale 1.5 the application bus must leave both the
            // focused class and the full title line visible above it.
            font.pixelSize: Math.min(Theme.du(Theme.insane ? 192 : 170), rig.height * (rig.compact ? .15 : .24))
            font.weight: Font.ExtraLight; font.letterSpacing: -8; color: rig.profile.text
            lineHeight: .9
        }
        Row {
            spacing: Theme.du(7)
            Rectangle { width: Theme.du(22); height: Theme.du(3); color: rig.profile.signal; anchors.verticalCenter: parent.verticalCenter }
            Text {
                width: rig.width * .19; elide: Text.ElideRight
                text: Compositor.activeClass ? Compositor.activeClass.toUpperCase() : "NO FOCUSED APPLICATION"
                textFormat: Text.PlainText; color: rig.profile.signal
                font.family: Theme.mono; font.pixelSize: Theme.fontSm
            }
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            visible: !rig.compact
            text: Compositor.activeTitle || "Search for an app to begin"
            textFormat: Text.PlainText; color: rig.profile.textDim
            font.family: Theme.sans; font.pixelSize: Theme.fontMd
        }
    }

    Column {
        x: parent.width * .69; y: parent.height * .27
        width: rig.geometry.instrumentWidth
        spacing: Theme.du(24); visible: !rig.instrument
        opacity: Math.max(0, Math.min(1, (rig.ignition - .22) / .30))
        NowPlaying { profile: rig.profile; width: parent.width }
        Flow {
            width: parent.width; spacing: Theme.du(5)
            Repeater {
                model: rig.entryBays
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - Theme.du(5)) / 2; height: Theme.du(34)
                    color: entryPointer.containsMouse ? rig.profile.signal : rig.profile.bg
                    border.color: entryPointer.containsMouse ? rig.profile.signal : rig.profile.grid
                    Text {
                        anchors.centerIn: parent; width: parent.width - Theme.du(8)
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: modelData.label; textFormat: Text.PlainText
                        color: entryPointer.containsMouse ? rig.profile.bg : rig.profile.text
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

    // Keep the register above the actual second bearing; overflow scrolls
    // through every window instead of silently truncating the model.
    Column {
        id: windowRegister
        x: rig.geometry.windows.x; y: rig.geometry.windows.y
        width: rig.geometry.windows.width
        spacing: Theme.du(8); visible: !rig.instrument && !rig.compact
        opacity: Math.max(0, Math.min(1, (rig.ignition - .48) / .26))
        Text {
            id: windowHeading
            text: "OPEN WINDOWS / " + rig.windows.length; textFormat: Text.PlainText
            color: rig.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
        }
        Flickable {
            id: windowViewport
            objectName: "groundWindowRegister"
            // One border of horizontal raster allowance keeps fractional-
            // scale rule endpoints intact; content retains its original width.
            width: parent.width + Theme.border
            height: Math.max(0, Math.min(Theme.du(32) * 3 + Theme.du(8) * 2,
                rig.geometry.windows.height - windowHeading.height - windowRegister.spacing))
            contentWidth: width; contentHeight: windowRows.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            Column {
                id: windowRows
                width: windowRegister.width; spacing: windowRegister.spacing
                Repeater {
                    model: rig.windows
                    delegate: Item {
                        required property var modelData
                        width: windowRows.width; height: Theme.du(32)
                        Rectangle { width: parent.width; height: 1; color: rig.profile.grid }
                        Text {
                            y: Theme.du(9); width: parent.width - Theme.du(38); elide: Text.ElideRight
                            text: modelData.title; textFormat: Text.PlainText; color: rig.profile.text
                            font.family: Theme.sans; font.pixelSize: Theme.fontSm
                        }
                        Text {
                            anchors.right: parent.right; y: Theme.du(9)
                            text: "W" + modelData.workspaceId; textFormat: Text.PlainText
                            color: rig.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs
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
            // Reveal the position mark on interaction, keeping the resting
            // register's original inscriptions and pixels intact.
            HoverHandler { id: windowHover }
            ScrollMark {
                profile: rig.profile; viewport: windowViewport
                opacity: windowHover.hovered || windowViewport.contentY > 0 ? 1 : 0
            }
        }
    }

    // The core comb uses the service's existing samples. It never polls.
    Item {
        x: parent.width * .69; y: parent.height * .105
        width: rig.geometry.instrumentWidth; height: parent.height * .085
        visible: !rig.compact && !rig.instrument
        Text {
            text: "CPU CORES / " + Math.min(Theme.insane ? 64 : 32, Telemetry.cpu.cores.length) + " OF " + Telemetry.cpu.cores.length
            textFormat: Text.PlainText; color: rig.profile.textDim
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
                    Rectangle { anchors.fill: parent; color: rig.profile.surface; border.width: core.known ? 0 : Theme.border; border.color: rig.profile.textDim }
                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width
                        height: core.known ? Math.max(1, parent.height * Math.min(100, modelData) / 100) : 0
                        color: rig.profile.signal
                    }
                }
                id: coreRepeater
            }
        }
    }

    WorkspaceOrbit { profile: rig.profile; anchors.fill: parent; instrument: rig.instrument; visible: !rig.instrument }
    Text {
        x: parent.width * .055; y: parent.height * .846
        visible: !rig.instrument && !rig.compact
        text: "WORKSPACES / CLICK TO SWITCH"; textFormat: Text.PlainText
        color: rig.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
    }

    // THEARS offers native surfaces; PIYTI exposes real window continuity.
    AppContinuity { profile: rig.profile;
        x: rig.geometry.apps.x; y: rig.geometry.apps.y
        width: rig.geometry.apps.width
        height: rig.geometry.apps.height
        visible: !rig.instrument && !!Displays.primary && Screen.name === Displays.primary.name && !rig.profile.hideContent
        instrument: rig.instrument
    }
    Text {
        x: parent.width * .055; y: parent.height * .815
        visible: !rig.instrument && Theme.bootProgress < 1
        text: "ASSEMBLING / " + Math.round(Theme.bootProgress * 100) + "%"; textFormat: Text.PlainText
        color: rig.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
    }
}
