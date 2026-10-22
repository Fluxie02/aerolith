import QtQuick
import qs.core
import qs.services
import "../lib/telemetry.mjs" as T

// Information uses real compositor state and the existing slow strip samples.
// Hide detail in compact layouts; never compress the functional bay's text.
Item {
    id: rig
    property bool instrument: false
    readonly property int level: Theme.variantLevel
    readonly property bool compact: width < Theme.du(1500) || height < Theme.du(850)
    readonly property var windows: Compositor.windows()
    readonly property string ws: Compositor.focusedWorkspaceId > 0 ? ("0" + Compositor.focusedWorkspaceId).slice(-2) : "N/A"
    readonly property string cpu: T.formatPercent(Telemetry.cpu.total)
    readonly property string mem: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)
    readonly property real ignition: instrument ? 1 : Theme.bootProgress
    opacity: Math.min(1, ignition * 2)

    Text {
        x: parent.width * .055; y: Math.max(Theme.stripHeight + Theme.du(14), parent.height * .065)
        visible: !rig.instrument || !rig.compact
        text: "LIMB / " + Theme.variantName.toUpperCase() + "   ·   AEROLITH"
        textFormat: Text.PlainText; color: Theme.signal
        font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1.8
    }
    Text {
        x: parent.width * .055; y: parent.height * .113
        visible: !compact
        text: "WORKSPACE " + ws + "   /   " + windows.length + " WINDOWS   /   " + (Compositor.available ? "COMPOSITOR LINKED" : "COMPOSITOR N/A")
        textFormat: Text.PlainText; color: Theme.textDim
        font.family: Theme.mono; font.pixelSize: Theme.fontSm
    }
    Text {
        x: parent.width * .055; y: parent.height * .15
        visible: !compact && (!instrument || level > 1)
        text: "CPU " + rig.cpu + "    MEMORY " + rig.mem + "    SAMPLE / " + (Telemetry.interval > 0 ? Telemetry.interval + " MS" : "OFF")
        textFormat: Text.PlainText; color: Theme.text
        font.family: Theme.mono; font.pixelSize: Theme.fontSm
    }

    // The hub's focused workspace is the dominant number, not fake telemetry.
    Column {
        x: parent.width * .125; y: parent.height * .36
        width: parent.width * (rig.level === 3 ? .16 : .28)
        visible: !instrument
        opacity: Math.max(0, Math.min(1, (rig.ignition - .1) / .3))
        spacing: Theme.du(8)
        Text {
            text: "WORKSPACE / ACTIVE"; textFormat: Text.PlainText
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; color: Theme.textDim
        }
        Text {
            text: rig.ws; textFormat: Text.PlainText
            font.family: Theme.displaySans; font.pixelSize: Theme.du(rig.level === 2 ? 136 : 162)
            font.weight: Font.Light; font.letterSpacing: -5; color: Theme.text
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: Compositor.activeClass ? Compositor.activeClass.toUpperCase() : "NO FOCUSED APPLICATION"
            textFormat: Text.PlainText; color: Theme.signal
            font.family: Theme.mono; font.pixelSize: Theme.fontMd
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: Compositor.activeTitle || "Use Command Core to begin"
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.sans; font.pixelSize: Theme.fontMd
        }
    }

    // Saturated adds a per-core comb; Insane widens it to 64 real core values.
    Item {
        x: parent.width * (rig.level === 3 ? .60 : .66); y: parent.height * .105
        width: parent.width * (rig.level === 3 ? .32 : .26); height: parent.height * .085
        visible: rig.level > 1 && !compact
        Text {
            text: "CORE ARRAY / " + Math.min(rig.level === 3 ? 64 : 32, Telemetry.cpu.cores.length) + " OF " + Telemetry.cpu.cores.length
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontXs
        }
        Row {
            y: Theme.du(21); height: parent.height - y; width: parent.width
            spacing: Theme.du(4)
            Repeater {
                model: Telemetry.cpu.cores.slice(0, rig.level === 3 ? 64 : 32)
                delegate: Item {
                    required property var modelData
                    readonly property bool known: modelData !== null && modelData !== undefined && isFinite(modelData)
                    width: Math.max(1, Math.min(Theme.du(20), (parent.width - (parent.children.length - 1) * Theme.du(4)) / Math.max(1, parent.children.length - 1)))
                    height: parent.height
                    Rectangle {
                        anchors.fill: parent; color: Theme.surface2
                        border.width: parent.known ? 0 : Theme.border
                        border.color: Theme.textDim
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width
                        height: !parent.known ? 0 : Math.max(1, parent.height * Math.min(100, modelData) / 100)
                        color: Theme.signal
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.textDim; y: parent.height * .5 }
                }
            }
        }
    }

    Column {
        id: identity
        x: parent.width * (rig.level === 3 ? .52 : .55)
        y: parent.height * (rig.level === 2 ? .28 : .25)
        width: parent.width * .39
        spacing: Theme.du(6)
        visible: !instrument && !compact
        opacity: Math.max(0, Math.min(1, (rig.ignition - .15) / .25))
        Text {
            text: "PERSONAL COMPUTING / INSTRUMENT " + ("0" + rig.level).slice(-2)
            textFormat: Text.PlainText; color: Theme.signal
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1.2
        }
        Text {
            text: rig.level === 3 ? "AERO\nLITH" : "AEROLITH"
            textFormat: Text.PlainText; color: Theme.text
            font.family: Theme.displaySans; font.pixelSize: Theme.du(rig.level === 2 ? 84 : 112)
            font.weight: Font.Light; font.letterSpacing: rig.level === 3 ? 7 : 1; lineHeight: .9
        }
        Rectangle { width: parent.width; height: Theme.du(rig.level === 3 ? 5 : 2); color: Theme.signal }
        Flow {
            width: parent.width; spacing: Theme.du(16)
            Repeater {
                model: [{t:"01 COMMAND",b:"command"},{t:"02 NAVIGATOR",b:"navigator"},{t:"03 SYSTEMS",b:"systems"},{t:"04 SOUND",b:"signal"}]
                delegate: Text {
                    required property var modelData
                    text: modelData.t; textFormat: Text.PlainText; color: Theme.signal
                    font.family: Theme.mono; font.pixelSize: Theme.fontSm
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open(modelData.b) }
                }
            }
        }
    }

    Column {
        x: parent.width * (rig.level === 3 ? .75 : .55)
        y: parent.height * (rig.level === 2 ? .51 : .57)
        width: parent.width * (rig.level === 3 ? .17 : .39)
        spacing: Theme.du(10)
        visible: !instrument && !compact
        opacity: Math.max(0, Math.min(1, (rig.ignition - .45) / .3))
        Text {
            text: "WINDOW REGISTER / " + windows.length
            textFormat: Text.PlainText; color: Theme.signal
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1
        }
        Repeater {
            model: rig.windows.slice(0, 4)
            delegate: Item {
                required property var modelData
                width: parent.width; height: Theme.du(rig.level === 3 ? 30 : 42)
                Rectangle { width: parent.width; height: 1; color: Theme.grid }
                Text {
                    y: Theme.du(10); width: parent.width - Theme.du(48); elide: Text.ElideRight
                    text: rig.level === 3 ? modelData.appId.toUpperCase() : modelData.title
                    textFormat: Text.PlainText; color: Theme.text
                    font.family: Theme.mono; font.pixelSize: Theme.fontSm
                }
                Text {
                    anchors.right: parent.right; y: Theme.du(10)
                    text: "W" + modelData.workspaceId; textFormat: Text.PlainText
                    color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open("navigator") }
            }
        }
    }

    // Insane adds two readable telemetry tapes down the inner right field.
    Column {
        x: parent.width * .52; y: parent.height * .61; width: parent.width * .20
        spacing: Theme.du(12); visible: !instrument && rig.level === 3 && !compact
        MetricTape {
            width: parent.width; label: "CPU / TOTAL"; reading: rig.cpu
            values: { Telemetry.sampleSeq; return Telemetry.cpuHistory.values().slice(-36); }
        }
        MetricTape {
            width: parent.width; label: "MEMORY / USED"; reading: rig.mem; ink: Theme.text
            values: { Telemetry.sampleSeq; return Telemetry.memHistory.values().slice(-36); }
        }
    }

    // Saturated adds capacity, audio route and media data outside the register.
    Column {
        x: parent.width * .55; y: parent.height * .765
        width: parent.width * .39; spacing: Theme.du(11)
        visible: !rig.instrument && rig.level === 2 && !rig.compact
        Rectangle { width: parent.width; height: 1; color: Theme.grid }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: "RAM / " + T.formatBytes(Telemetry.memory ? Telemetry.memory.usedBytes : null) + " USED   /   " + T.formatBytes(Telemetry.memory ? Telemetry.memory.availableBytes : null) + " AVAILABLE"
            textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: "AUDIO / " + (Audio.ready && Audio.sink ? Audio.label(Audio.sink).toUpperCase() : "N/A") + "   /   " + (Media.title || "NO MEDIA")
            textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
    }

    // Insane exposes the actual command taxonomy inside the circular hub.
    Column {
        x: parent.width * .29; y: parent.height * .35; width: parent.width * .14
        spacing: Theme.du(9); visible: !rig.instrument && rig.level === 3 && !rig.compact
        Text { text: "CONTROL MATRIX"; textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
        Repeater {
            model: ["apps", "windows", "audio", "media", "system", "routines"]
            delegate: Item {
                required property string modelData
                readonly property int entries: { Registry.revision; return Registry.list().filter(c => c.category === modelData).length; }
                width: parent.width; height: Theme.du(25)
                Rectangle { width: parent.width; height: 1; color: Theme.grid }
                Text { y: Theme.du(7); text: modelData.toUpperCase(); textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
                Text { y: Theme.du(7); anchors.right: parent.right; text: parent.entries; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
            }
        }
        Text { text: "REGISTERED COMMANDS"; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
    }
    Column {
        x: parent.width * .29; y: parent.height * .64; width: parent.width * .14
        spacing: Theme.du(12); visible: !rig.instrument && rig.level === 3 && !rig.compact
        Text { text: "CAPACITY / RAM"; textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
        Text { text: T.formatBytes(Telemetry.memory ? Telemetry.memory.availableBytes : null) + " FREE"; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.mono; font.pixelSize: Theme.fontMd }
        Text { text: "CPU TEMP / " + T.formatTemp(Telemetry.temps.cpu); textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
        Text { text: "NOTICES / " + (Ui.notices.length + Notifications.count); textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
    }
    Column {
        x: parent.width * .105; y: parent.height * .29; width: parent.width * .22
        spacing: Theme.du(12)
        visible: rig.instrument && Ui.activeBay === "command" && rig.level > 1 && !rig.compact
        Text {
            text: "COMMAND BUS / " + rig.windows.length + " WINDOWS"
            textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        Text {
            text: "CPU " + rig.cpu + "    RAM " + rig.mem
            textFormat: Text.PlainText; color: Theme.text; font.family: Theme.mono; font.pixelSize: Theme.fontMd
        }
        Text {
            visible: rig.level === 3
            text: { Registry.revision; return Registry.list().length + " REGISTERED COMMANDS"; }
            textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
    }

    // An opaque straight bus cuts the circular field to keep traces legible.
    Rectangle {
        x: parent.width * .05; y: parent.height * .88
        width: parent.width * .90; height: parent.height * .12
        color: Theme.bg; visible: !rig.compact
    }
    // The ground and every bay share the same low, straight instrument bus.
    Row {
        x: parent.width * .055; y: parent.height * .895
        width: parent.width * .885
        spacing: parent.width * .022
        visible: !compact
        opacity: Math.max(0, Math.min(1, (rig.ignition - .65) / .35))
        MetricTape {
            width: parent.width * .25; height: Theme.du(82)
            label: "CPU LOAD"; reading: rig.cpu
            values: { Telemetry.sampleSeq; return Telemetry.cpuHistory.values().slice(-36); }
        }
        MetricTape {
            width: parent.width * .25; height: Theme.du(82)
            label: "MEMORY"; reading: rig.mem; ink: Theme.text
            values: { Telemetry.sampleSeq; return Telemetry.memHistory.values().slice(-36); }
        }
        Column {
            width: parent.width * .19; spacing: Theme.du(10)
            Rectangle { width: parent.width; height: 1; color: Theme.grid }
            Text { text: "OUTPUT / SOUND"; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
            Text {
                text: !Audio.volumeKnown ? "N/A" : Audio.muted ? "MUTED" : Audio.volumePercent + "%"
                textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.displaySans; font.pixelSize: Theme.du(25)
            }
            Text { text: Media.playing ? "PLAYING" : "NO PLAYBACK"; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
        }
        Column {
            width: parent.width * .20; spacing: Theme.du(10)
            Rectangle { width: parent.width; height: 1; color: Theme.grid }
            Text { text: "ACTIVE ROUTE / " + rig.ws; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
            Text { text: rig.instrument ? (Ui.activeBay || "CLOSING").toUpperCase() : "DESKTOP"; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.mono; font.pixelSize: Theme.du(22) }
            Text { text: "F1 HELP / ESC RETURN"; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
        }
    }

    Text {
        x: parent.width * .055; y: parent.height * .84
        visible: !instrument && !compact
        text: "WORKSPACE ARC / SELECT A NUMBER TO SWITCH"
        textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
    }
    WorkspaceOrbit { anchors.fill: parent; instrument: rig.instrument; visible: !rig.compact }

    // Compact ground retains one strong workspace hub and an explicit entry.
    Column {
        x: parent.width * .55; y: parent.height * .43; width: parent.width * .39
        visible: rig.compact && !rig.instrument; spacing: Theme.du(18)
        Text { text: "AEROLITH"; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(34) }
        Text { width: parent.width; text: "LIMB / " + Theme.variantName.toUpperCase(); textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
        Text { text: rig.cpu + " CPU\n" + rig.mem + " MEMORY"; textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontMd; lineHeight: 1.8 }
        Text {
            text: "OPEN COMMAND →"; textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.open("command") }
        }
    }
    Text {
        x: parent.width * .055; y: parent.height * .815
        visible: !rig.instrument && Theme.bootProgress < 1
        text: "REGISTERING LIMB / " + Math.round(Theme.bootProgress * 100) + "%"
        textFormat: Text.PlainText; color: Theme.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm
    }
}
