import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services
import "../../lib/telemetry.mjs" as T

// SYS-03 · Systems Bay: live telemetry. Opening the bay raises sampling
// demand; closing it (the bay is unloaded) drops it back, so nothing here
// costs anything while hidden.
FocusScope {
    id: bay

    readonly property var cfg: Config.telemetry
    readonly property int seq: Telemetry.sampleSeq

    Component.onCompleted: {
        Telemetry.acquire("panel");
        Telemetry.acquire("detail");
    }
    Component.onDestruction: {
        Telemetry.release("panel");
        Telemetry.release("detail");
    }

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
        }
    }

    function gpuValue(field) {
        return Telemetry.gpu ? Telemetry.gpu[field] : null;
    }

    Bezel {
        anchors.centerIn: parent
        width: Math.min(Theme.px(1360), parent.width - Theme.pad * 4)
        height: Math.min(Theme.px(820), parent.height - Theme.pad)
        designation: "SYS-03"
        title: "Systems Bay"
        status: "SAMPLE " + Telemetry.interval + " MS" + (bay.cfg.performanceMode ? " · PERF MODE" : "") + " · " + Telemetry.samplesTaken + " SAMPLES"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.pad

            // Primary readouts
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad * 2.5
                Readout {
                    label: "CPU"
                    value: T.formatPercent(Telemetry.cpu.total)
                    status: Telemetry.cpuState
                    valueSize: Theme.fontXl
                }
                Readout {
                    label: "Clock avg / max"
                    value: isNaN(Telemetry.cpuFreqMHz) ? "N/A" : (Telemetry.cpuFreqMHz / 1000).toFixed(2) + " / " + (Telemetry.cpuFreqMaxMHz / 1000).toFixed(2)
                    unit: "GHz"
                }
                Readout {
                    label: "Memory"
                    value: Telemetry.memory ? T.formatBytes(Telemetry.memory.usedBytes) + " / " + T.formatBytes(Telemetry.memory.totalBytes) : "N/A"
                    status: Telemetry.memState
                }
                Readout {
                    label: "Swap"
                    value: Telemetry.memory && Telemetry.memory.swapTotalBytes ? T.formatPercent(Telemetry.memory.swapPercent) : "N/A"
                }
                Readout {
                    label: "Mem pressure 10s"
                    value: Telemetry.pressure && Telemetry.pressure.some ? Telemetry.pressure.some.avg10.toFixed(2) : "N/A"
                    unit: "%"
                    status: Telemetry.pressure && Telemetry.pressure.some && Telemetry.pressure.some.avg10 > 10 ? "caution" : ""
                }
                Readout {
                    label: "GPU " + (Telemetry.gpuVendor || "")
                    value: T.formatPercent(bay.gpuValue("utilPercent"))
                }
                Readout {
                    label: "VRAM"
                    value: bay.gpuValue("vramUsedBytes") === null ? "N/A" : T.formatBytes(bay.gpuValue("vramUsedBytes")) + (bay.gpuValue("vramTotalBytes") ? " / " + T.formatBytes(bay.gpuValue("vramTotalBytes")) : "")
                }
                Readout {
                    label: "Temp CPU / GPU / NVMe"
                    value: T.formatTemp(Telemetry.temps.cpu) + " " + T.formatTemp(Telemetry.temps.gpu !== null ? Telemetry.temps.gpu : bay.gpuValue("tempC")) + " " + T.formatTemp(Telemetry.temps.nvme)
                    status: Telemetry.tempState === "unknown" ? "" : Telemetry.tempState
                }
                Readout {
                    label: "Net ↓ / ↑"
                    value: Telemetry.net ? T.formatRate(Telemetry.net.rxBps) + " " + T.formatRate(Telemetry.net.txBps) : "N/A"
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            Text {
                visible: Telemetry.gpuStatus !== "ok"
                text: "GPU telemetry: " + Telemetry.gpuStatus + (Telemetry.gpuVendor === "intel" ? " · utilisation needs perf privileges; frequency only" : "")
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }

            // Traces
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(130)
                columns: 4
                columnSpacing: Theme.pad
                TracePanel {
                    title: "CPU %"
                    values: {
                        bay.seq;
                        return Telemetry.cpuHistory.values();
                    }
                    seq: bay.seq
                    caution: bay.cfg.cpuCautionPercent
                }
                TracePanel {
                    title: "MEMORY %"
                    values: {
                        bay.seq;
                        return Telemetry.memHistory.values();
                    }
                    seq: bay.seq
                    caution: bay.cfg.memoryCautionPercent
                }
                TracePanel {
                    title: "NET ↓ " + (Telemetry.net ? T.formatRate(Telemetry.net.rxBps) : "")
                    values: {
                        bay.seq;
                        return Telemetry.rxHistory.values();
                    }
                    seq: bay.seq
                    autoMax: true
                }
                TracePanel {
                    title: "GPU %"
                    values: {
                        bay.seq;
                        return Telemetry.gpuHistory.values();
                    }
                    seq: bay.seq
                    traceColor: Theme.nominal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.pad * 2

                // Left: cores, storage, battery
                ColumnLayout {
                    Layout.preferredWidth: parent.width * 0.42
                    Layout.fillHeight: true
                    spacing: Theme.pad

                    Label {
                        text: "Core bus · " + Telemetry.cpu.cores.length + " logical CPUs"
                    }
                    CoreBus {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(64)
                        cores: Telemetry.cpu.cores
                        caution: bay.cfg.cpuCautionPercent
                    }

                    Label {
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
                                text: modelData.mount
                                elide: Text.ElideMiddle
                                color: Theme.text
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                            }
                            TapeGauge {
                                Layout.fillWidth: true
                                value: modelData.percent === null ? NaN : modelData.percent
                                caution: 90
                                status: modelData.percent > 95 ? "critical" : modelData.percent > 90 ? "caution" : "nominal"
                            }
                            Text {
                                Layout.preferredWidth: Theme.px(150)
                                horizontalAlignment: Text.AlignRight
                                text: T.formatBytes(modelData.usedBytes) + " / " + T.formatBytes(modelData.sizeBytes)
                                color: Theme.textDim
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                            }
                        }
                    }
                    Label {
                        visible: Telemetry.disks.length === 0
                        text: "Reading filesystems…"
                    }

                    Label {
                        visible: Power.hasBattery
                        text: "Battery"
                    }
                    RowLayout {
                        visible: Power.hasBattery
                        Layout.fillWidth: true
                        TapeGauge {
                            Layout.fillWidth: true
                            value: Power.batteryPercent
                            status: Power.batteryPercent < 10 ? "critical" : Power.batteryPercent < 20 ? "caution" : "nominal"
                        }
                        Text {
                            text: Math.round(Power.batteryPercent) + "% · " + (Power.charging ? "charging" : T.formatDuration(Power.timeToEmpty) + " left")
                            color: Theme.textDim
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
                    Layout.fillHeight: true
                    spacing: Theme.px(2)
                    Label {
                        text: "Top processes · sorted by " + (Telemetry.processSort === "cpu" ? "CPU (1 core = 100%)" : "memory")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        ProcCell {
                            text: "PID"
                            w: 70
                            dim: true
                        }
                        ProcCell {
                            text: "COMMAND"
                            Layout.fillWidth: true
                            dim: true
                        }
                        ProcCell {
                            text: "CPU"
                            w: 70
                            dim: true
                            alignRight: true
                        }
                        ProcCell {
                            text: "RSS"
                            w: 100
                            dim: true
                            alignRight: true
                        }
                    }
                    Ruler {
                        Layout.fillWidth: true
                    }
                    Repeater {
                        model: Telemetry.processes
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            ProcCell {
                                text: modelData.pid
                                w: 70
                                dim: true
                            }
                            ProcCell {
                                text: modelData.comm
                                Layout.fillWidth: true
                            }
                            ProcCell {
                                text: modelData.cpuPercent === null ? "—" : modelData.cpuPercent.toFixed(0) + "%"
                                w: 70
                                alignRight: true
                                tone: modelData.cpuPercent !== null && modelData.cpuPercent > 80 ? Theme.caution : Theme.text
                            }
                            ProcCell {
                                text: T.formatBytes(modelData.rssBytes)
                                w: 100
                                alignRight: true
                            }
                        }
                    }
                    Label {
                        visible: Telemetry.processes.length === 0
                        text: "Sampling processes…"
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            StatusLine {
                Layout.fillWidth: true
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
                        key: "ESC",
                        action: "close"
                    }
                ]
                message: "reads /proc + sysfs" + (Telemetry.gpuVendor === "nvidia" ? " · nvidia-smi stream" : "") + " · ps every " + Math.max(2000, bay.cfg.detailIntervalMs) + " ms · df every 30 s"
            }
        }
    }

    component TracePanel: ColumnLayout {
        property string title: ""
        property var values: []
        property int seq: 0
        property real caution: NaN
        property bool autoMax: false
        property color traceColor: Theme.signal
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.px(3)
        Label {
            text: parent.title
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg
            border.color: Theme.grid
            border.width: Theme.border
            Trace {
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
        property int w: 0
        property bool dim: false
        property bool alignRight: false
        property color tone: Theme.text
        Layout.preferredWidth: w > 0 ? Theme.px(w) : -1
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        color: dim ? Theme.textDim : tone
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
        elide: Text.ElideRight
    }
}
