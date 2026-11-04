import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services
import "../../lib/telemetry.mjs" as T

// SYS-03 · Systems Bay: live telemetry. Opening the bay raises sampling
// demand; closing it drops it back, so nothing here costs anything while
// hidden.
FocusScope {
    id: bay
    property var profile: Theme

    readonly property var cfg: Config.telemetry
    readonly property int seq: Telemetry.sampleSeq

    // The Deck sets `active` false as soon as this bay stops being requested
    // (its pixels may stay briefly for an exit transition); sampling demand
    // follows `active`, so closing drops back to idle sampling at once.
    property bool active: true
    property bool holding: false
    function hold(on) {
        if (on === holding)
            return;
        holding = on;
        if (on) {
            Telemetry.acquire("panel");
            Telemetry.acquire("detail");
        } else {
            Telemetry.release("panel");
            Telemetry.release("detail");
        }
    }
    onActiveChanged: hold(active)
    Component.onCompleted: hold(active)
    Component.onDestruction: hold(false)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_C) {
            Telemetry.processSort = "cpu";
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            Telemetry.processSort = "memory";
            event.accepted = true;
        } else if (event.key === Qt.Key_P) {
            Registry.run("telemetry.performance-mode");
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
            const direction = event.key === Qt.Key_PageDown ? 1 : -1;
            instrumentsView.contentY = Math.max(0, Math.min(instrumentsView.contentHeight - instrumentsView.height,
                instrumentsView.contentY + direction * instrumentsView.height * .8));
            event.accepted = true;
        }
    }

    function gpuValue(field) {
        return Telemetry.gpu ? Telemetry.gpu[field] : null;
    }

    Bezel { profile: bay.profile;
        anchors.fill: parent
        designation: "SYS / 03"
        title: "Systems Bay"
        status: "SAMPLE " + Telemetry.interval + " MS" + (bay.cfg.performanceMode ? " · PERF MODE" : "") + " · " + Telemetry.samplesTaken + " SAMPLES"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        Item {
            anchors.fill: parent
            Flickable {
                id: instrumentsView
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.bottom: systemsStatus.top; anchors.bottomMargin: Theme.du(12)
                contentWidth: width
                contentHeight: Math.max(height, instruments.implicitHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: instruments
                    width: instrumentsView.width
                    spacing: Theme.du(16)

                        // Four equal instruments register value and history on one baseline.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.du(215)
                            spacing: Theme.du(24)
                            TracePanel { profile: bay.profile;
                                title: "CPU LOAD"
                                reading: T.formatPercent(Telemetry.cpu.total)
                                readingColor: bay.profile.signal
                                values: { bay.seq; return Telemetry.cpuHistory.values(); }
                                seq: bay.seq; caution: bay.cfg.cpuCautionPercent
                            }
                            TracePanel { profile: bay.profile;
                                title: "MEMORY"
                                reading: T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)
                                values: { bay.seq; return Telemetry.memHistory.values(); }
                                seq: bay.seq; caution: bay.cfg.memoryCautionPercent
                            }
                            TracePanel { profile: bay.profile;
                                title: "NETWORK / RX"
                                reading: T.formatRate(Telemetry.net ? Telemetry.net.rxBps : null)
                                values: { bay.seq; return Telemetry.rxHistory.values(); }
                                seq: bay.seq; autoMax: true
                            }
                            TracePanel { profile: bay.profile;
                                title: "GPU LOAD"
                                reading: T.formatPercent(bay.gpuValue("utilPercent"))
                                values: { bay.seq; return Telemetry.gpuHistory.values(); }
                                seq: bay.seq
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.du(20)
                            Repeater {
                                model: [
                                    "CLOCK AVG / MAX  " + (isNaN(Telemetry.cpuFreqMHz) ? "N/A" : (Telemetry.cpuFreqMHz / 1000).toFixed(2)) + " / " + (isNaN(Telemetry.cpuFreqMaxMHz) ? "N/A" : (Telemetry.cpuFreqMaxMHz / 1000).toFixed(2)) + " GHz",
                                    "MEM  " + (Telemetry.memory ? T.formatBytes(Telemetry.memory.usedBytes) + " / " + T.formatBytes(Telemetry.memory.totalBytes) : "N/A"),
                                    "SWAP  " + (!Telemetry.memory || Telemetry.memory.swapTotalBytes === null ? "N/A" : Telemetry.memory.swapTotalBytes === 0 ? "NONE" : T.formatPercent(Telemetry.memory.swapPercent)),
                                    "PRESSURE 10s  " + (Telemetry.pressure && Telemetry.pressure.some ? Telemetry.pressure.some.avg10.toFixed(2) + "%" : "N/A"),
                                    "VRAM  " + (bay.gpuValue("vramUsedBytes") === null ? "N/A" : T.formatBytes(bay.gpuValue("vramUsedBytes")) + " / " + T.formatBytes(bay.gpuValue("vramTotalBytes"))),
                                    "TEMP CPU / GPU / NVMe  " + T.formatTemp(Telemetry.temps.cpu) + " / " + T.formatTemp(Telemetry.temps.gpu !== null ? Telemetry.temps.gpu : bay.gpuValue("tempC")) + " / " + T.formatTemp(Telemetry.temps.nvme),
                                    "NET TX  " + T.formatRate(Telemetry.net ? Telemetry.net.txBps : null),
                                    "GPU  " + Telemetry.gpuStatus
                                ]
                                Text {
                                    required property var modelData
                                    text: modelData; textFormat: Text.PlainText
                                    color: bay.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                                }
                            }
                        }
                        Ruler { profile: bay.profile; Layout.fillWidth: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.du(240)
                            spacing: Theme.pad * 2

                            // Left: cores, storage, battery
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 42
                                Layout.fillHeight: true
                                spacing: Theme.pad

                                Label { profile: bay.profile;
                                    text: "Core bus · " + Telemetry.cpu.cores.length + " logical CPUs"
                                }
                                CoreBus { profile: bay.profile;
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(64)
                                    cores: Telemetry.cpu.cores
                                    caution: bay.cfg.cpuCautionPercent
                                }

                                Label { profile: bay.profile;
                                    text: "Storage"
                                }
                                Repeater {
                                    model: Telemetry.disks.slice(0, 5)
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: Theme.gap
                                        Text {
                                            Layout.preferredWidth: Theme.px(120)
                                            textFormat: Text.PlainText
                                            text: modelData.mount
                                            elide: Text.ElideMiddle
                                            color: bay.profile.text
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontXs
                                        }
                                        TapeGauge { profile: bay.profile;
                                            Layout.fillWidth: true
                                            value: modelData.percent === null ? NaN : modelData.percent
                                            caution: 90
                                            status: modelData.percent > 95 ? "critical" : modelData.percent > 90 ? "caution" : "nominal"
                                        }
                                        Text {
                                            Layout.preferredWidth: Theme.px(150)
                                            horizontalAlignment: Text.AlignRight
                                            text: T.formatBytes(modelData.usedBytes) + " / " + T.formatBytes(modelData.sizeBytes)
                                            color: bay.profile.textDim
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontXs
                                        }
                                    }
                                }
                                Label { profile: bay.profile;
                                    visible: Telemetry.disks.length === 0
                                    text: "Reading filesystems…"
                                }

                                Label { profile: bay.profile;
                                    visible: Power.hasBattery
                                    text: "Battery"
                                }
                                RowLayout {
                                    visible: Power.hasBattery
                                    Layout.fillWidth: true
                                    TapeGauge { profile: bay.profile;
                                        Layout.fillWidth: true
                                        value: Power.batteryPercent
                                        status: Power.batteryPercent < 10 ? "critical" : Power.batteryPercent < 20 ? "caution" : "nominal"
                                    }
                                    Text {
                                        text: Math.round(Power.batteryPercent) + "% · " + (Power.charging ? "charging" : T.formatDuration(Power.timeToEmpty) + " left")
                                        color: bay.profile.textDim
                                        font.family: Theme.mono
                                        font.pixelSize: Theme.fontXs
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                            }

                            // Right: processes
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 58
                                Layout.fillHeight: true
                                spacing: Theme.px(2)
                                Label { profile: bay.profile;
                                    text: "Top processes · sorted by " + (Telemetry.processSort === "cpu" ? "CPU (1 core = 100%)" : "memory")
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    ProcCell { profile: bay.profile;
                                        text: "PID"
                                        w: 70
                                        dim: true
                                    }
                                    ProcCell { profile: bay.profile;
                                        text: "COMMAND"
                                        Layout.fillWidth: true
                                        dim: true
                                    }
                                    ProcCell { profile: bay.profile;
                                        text: "CPU"
                                        w: 70
                                        dim: true
                                        alignRight: true
                                    }
                                    ProcCell { profile: bay.profile;
                                        text: "RSS"
                                        w: 100
                                        dim: true
                                        alignRight: true
                                    }
                                }
                                Ruler { profile: bay.profile;
                                    Layout.fillWidth: true
                                }
                                Repeater {
                                    model: Telemetry.processes
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        ProcCell { profile: bay.profile;
                                            text: modelData.pid
                                            w: 70
                                            dim: true
                                        }
                                        ProcCell { profile: bay.profile;
                                            text: modelData.comm
                                            Layout.fillWidth: true
                                        }
                                        ProcCell { profile: bay.profile;
                                            text: modelData.cpuPercent === null ? "—" : modelData.cpuPercent.toFixed(0) + "%"
                                            w: 70
                                            alignRight: true
                                            tone: modelData.cpuPercent !== null && modelData.cpuPercent > 80 ? bay.profile.caution : bay.profile.text
                                        }
                                        ProcCell { profile: bay.profile;
                                            text: T.formatBytes(modelData.rssBytes)
                                            w: 100
                                            alignRight: true
                                        }
                                    }
                                }
                                Label { profile: bay.profile;
                                    visible: Telemetry.processes.length === 0
                                    text: "Sampling processes…"
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                            }
                        }
                }
            }

            ScrollMark { profile: bay.profile; viewport: instrumentsView }

            StatusLine { profile: bay.profile;
                id: systemsStatus
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                hints: [
                    {
                        key: "C",
                        action: "sort cpu"
                    },
                    {
                        key: "M",
                        action: "sort memory"
                    },
                    {
                        key: "P",
                        action: "performance mode"
                    },
                    {
                        key: "PG↑↓",
                        action: "scroll"
                    },
                    {
                        key: "ESC",
                        action: "close"
                    }
                ]
                message: "reads /proc + sysfs" + (Telemetry.gpuVendor === "nvidia" ? " · nvidia-smi stream" : "") + " · ps every " + Math.max(2000, bay.cfg.detailIntervalMs) + " ms · df every 30 s"
            }
        }
    }

    component TracePanel: ColumnLayout {
        id: panel
        property var profile: Theme
        // Equal stretch for every trace regardless of its label width.
        Layout.preferredWidth: 1
        property string title: ""
        property string reading: "N/A"
        property color readingColor: panel.profile.text
        property var values: []
        property int seq: 0
        property real caution: NaN
        property bool autoMax: false
        property color traceColor: panel.profile.signal
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.px(3)
        Label { profile: panel.profile;
            text: parent.title
        }
        Text {
            text: parent.reading; textFormat: Text.PlainText
            color: parent.readingColor; font.family: Theme.mono; font.pixelSize: Theme.du(32); font.weight: Font.Medium
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: panel.profile.bg
            border.color: panel.profile.grid
            border.width: Theme.border
            Text {
                anchors.centerIn: parent; visible: parent.parent.reading === "N/A"
                text: "N/A"; textFormat: Text.PlainText
                color: panel.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
            }
            Trace { profile: panel.profile;
                anchors.fill: parent
                anchors.margins: Theme.border
                values: parent.parent.values
                seq: parent.parent.seq
                caution: parent.parent.caution
                autoMax: parent.parent.autoMax
                color: parent.parent.traceColor
                capacity: Config.telemetry.historySamples
            }
        }
    }

    component ProcCell: Text {
        id: cell
        property var profile: Theme
        textFormat: Text.PlainText
        property int w: 0
        property bool dim: false
        property bool alignRight: false
        property color tone: cell.profile.text
        Layout.preferredWidth: w > 0 ? Theme.px(w) : -1
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        color: dim ? cell.profile.textDim : tone
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
        elide: Text.ElideRight
    }
}
