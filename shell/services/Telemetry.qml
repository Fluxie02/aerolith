pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/telemetry.mjs" as T

// System telemetry with demand-driven sampling.
//
//   nobody watching        -> no timer runs, nothing is read
//   Flight Strip (alert)   -> /proc/stat, /proc/meminfo, CPU temp every stripIntervalMs
//   Systems Bay open       -> + network, PSI, GPU, frequency, storage at panelIntervalMs
//   process list visible   -> + `ps` at max(detailIntervalMs, 2000)
//
// Files are read through FileView (no process per sample). The only
// subprocesses are `ps` and `df` while the Systems Bay is open, and one
// long-running `nvidia-smi` stream on NVIDIA systems while it is open.
// Metrics the system does not provide stay null and display as N/A.
Singleton {
    id: root

    // Consumers raise demand while visible (reference counted).
    property int panelDemand: 0
    property int detailDemand: 0
    readonly property bool stripDemand: Config.strip.visible && Config.strip.telemetry !== "off"
    readonly property bool panelActive: panelDemand > 0
    readonly property bool detailActive: detailDemand > 0
    readonly property var cfg: Config.telemetry
    readonly property int interval: T.samplingInterval({
        strip: stripDemand,
        panel: panelActive,
        detail: detailActive
    }, {
        stripMs: cfg.stripIntervalMs,
        panelMs: cfg.panelIntervalMs,
        detailMs: cfg.detailIntervalMs
    }, cfg.performanceMode)

    // Latest values
    property var cpu: ({
            total: null,
            cores: []
        })
    property var memory: null
    property var pressure: null
    property var net: null
    property var gpu: null
    property string gpuStatus: "not sampled"
    property real cpuFreqMHz: NaN
    property real cpuFreqMaxMHz: NaN
    property var temps: ({
            cpu: null,
            gpu: null,
            nvme: null
        })
    property var disks: []
    property var processes: []
    property string processSort: "cpu"
    property int sampleSeq: 0
    property real lastSampleAt: 0
    property int samplesTaken: 0

    // Bounded histories (plain JS objects; sampleSeq signals updates)
    property var cpuHistory: T.createHistory(cfg.historySamples)
    property var memHistory: T.createHistory(cfg.historySamples)
    property var rxHistory: T.createHistory(cfg.historySamples)
    property var txHistory: T.createHistory(cfg.historySamples)
    property var gpuHistory: T.createHistory(cfg.historySamples)

    // States for annunciators
    readonly property string cpuState: T.classify(cpu.total, cfg.cpuCautionPercent, 101)
    readonly property string memState: T.classify(memory ? memory.percent : null, cfg.memoryCautionPercent, 101)
    readonly property string tempState: T.classify(temps.cpu, cfg.temperatureCautionC, cfg.temperatureCriticalC)
    readonly property bool alert: cpuState === "caution" || memState === "caution" || tempState === "caution" || tempState === "critical"

    function acquire(kind) {
        if (kind === "detail")
            detailDemand++;
        else
            panelDemand++;
    }
    function release(kind) {
        if (kind === "detail")
            detailDemand = Math.max(0, detailDemand - 1);
        else
            panelDemand = Math.max(0, panelDemand - 1);
    }

    property var prevStat: null
    property var prevNet: null
    property real prevNetAt: 0
    property var prevPs: null
    property real prevPsAt: 0

    Timer {
        id: ticker
        interval: Math.max(250, root.interval)
        running: root.interval > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    function sample() {
        lastSampleAt = Date.now();
        statFile.reload();
        memFile.reload();
        if (tempPaths.cpu !== "")
            cpuTempFile.reload();
        if (!panelActive)
            return;
        netFile.reload();
        psiFile.reload();
        cpuinfoFile.reload();
        if (tempPaths.gpu !== "")
            gpuTempFile.reload();
        if (tempPaths.nvme !== "")
            nvmeTempFile.reload();
        sampleGpu();
        if (Date.now() - lastDfAt > 30000 && !dfProc.running) {
            lastDfAt = Date.now();
            dfProc.running = true;
        }
    }
    property real lastDfAt: 0

    // CPU and memory
    FileView {
        id: statFile
        path: "/proc/stat"
        preload: false
        printErrors: false
        onLoaded: {
            const cur = T.parseProcStat(text());
            if (!cur)
                return;
            const u = T.cpuUsage(root.prevStat, cur);
            root.prevStat = cur;
            root.cpu = u;
            root.cpuHistory.push(u.total);
            root.samplesTaken++;
            root.sampleSeq++;
        }
    }
    FileView {
        id: memFile
        path: "/proc/meminfo"
        preload: false
        printErrors: false
        onLoaded: {
            const m = T.memoryUsage(T.parseMeminfo(text()));
            root.memory = m;
            root.memHistory.push(m ? m.percent : null);
        }
    }
    FileView {
        id: psiFile
        path: "/proc/pressure/memory"
        preload: false
        printErrors: false
        onLoaded: root.pressure = T.parsePressure(text())
        onLoadFailed: root.pressure = null
    }
    FileView {
        id: netFile
        path: "/proc/net/dev"
        preload: false
        printErrors: false
        onLoaded: {
            const cur = T.parseNetDev(text());
            const now = Date.now();
            const r = T.netRates(root.prevNet, cur, now - root.prevNetAt);
            root.prevNet = cur;
            root.prevNetAt = now;
            root.net = r;
            root.rxHistory.push(r ? r.rxBps : null);
            root.txHistory.push(r ? r.txBps : null);
        }
    }
    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        preload: false
        printErrors: false
        onLoaded: {
            const mhz = text().split("\n").filter(l => l.indexOf("cpu MHz") === 0).map(l => Number(l.split(":")[1]));
            if (mhz.length === 0) {
                root.cpuFreqMHz = NaN;
                root.cpuFreqMaxMHz = NaN;
                return;
            }
            root.cpuFreqMHz = mhz.reduce((a, b) => a + b, 0) / mhz.length;
            root.cpuFreqMaxMHz = Math.max.apply(null, mhz);
        }
    }

    // Temperatures: hwmon sensors are discovered once, then read directly.
    property var tempPaths: ({
            cpu: "",
            gpu: "",
            nvme: ""
        })
    Process {
        id: hwmonProbe
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); for t in \"$h\"/temp*_input; do [ -e \"$t\" ] || continue; l=$(cat \"${t%_input}_label\" 2>/dev/null); printf '%s\\t%s\\t%s\\n' \"$n\" \"$l\" \"$t\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sensors = text.split("\n").filter(l => l.length > 0).map(l => {
                    const f = l.split("\t");
                    return {
                        name: f[0],
                        label: f[1],
                        path: f[2]
                    };
                });
                const pick = T.pickHwmon(sensors);
                root.tempPaths = {
                    cpu: pick.cpu || "",
                    gpu: pick.gpu || "",
                    nvme: pick.nvme || ""
                };
                Log.debug("telemetry", "temperature sensors " + JSON.stringify(root.tempPaths));
            }
        }
    }
    function setTemp(key, text) {
        const v = T.parseSysfsInt(text);
        const t = Object.assign({}, temps);
        t[key] = v === null ? null : v / 1000;
        temps = t;
    }
    FileView {
        id: cpuTempFile
        path: root.tempPaths.cpu
        preload: false
        printErrors: false
        onLoaded: root.setTemp("cpu", text())
    }
    FileView {
        id: gpuTempFile
        path: root.tempPaths.gpu
        preload: false
        printErrors: false
        onLoaded: root.setTemp("gpu", text())
    }
    FileView {
        id: nvmeTempFile
        path: root.tempPaths.nvme
        preload: false
        printErrors: false
        onLoaded: root.setTemp("nvme", text())
    }

    // GPU: vendor detected from sysfs PCI ids (AMD 0x1002, Intel 0x8086,
    // NVIDIA 0x10de). Discrete AMD/NVIDIA cards are preferred over Intel.
    property string gpuVendor: ""
    property string gpuDevice: ""
    Process {
        id: gpuProbe
        running: true
        command: ["sh", "-c", "for d in /sys/class/drm/card[0-9]*/device; do [ -e \"$d/vendor\" ] && printf '%s %s\\n' \"$(cat \"$d/vendor\")\" \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const want = root.cfg.gpu;
                const ids = {
                    "0x1002": "amd",
                    "0x8086": "intel",
                    "0x10de": "nvidia"
                };
                const found = text.split("\n").filter(l => l.length > 0).map(l => {
                    const f = l.split(" ");
                    return {
                        vendor: ids[f[0]] || "",
                        path: f[1]
                    };
                }).filter(g => g.vendor !== "");
                let pick = null;
                const order = want === "auto" ? ["nvidia", "amd", "intel"] : [want];
                for (let k = 0; k < order.length && !pick; k++)
                    for (let i = 0; i < found.length; i++)
                        if (found[i].vendor === order[k]) {
                            pick = found[i];
                            break;
                        }
                if (want === "off") {
                    root.gpuStatus = "disabled in configuration";
                } else if (!pick) {
                    root.gpuStatus = "no supported GPU found";
                } else {
                    root.gpuVendor = pick.vendor;
                    root.gpuDevice = pick.path;
                    root.gpuStatus = "ok";
                }
            }
        }
    }

    function sampleGpu() {
        if (gpuVendor === "amd") {
            amdBusy.reload();
            amdVramUsed.reload();
            amdVramTotal.reload();
        } else if (gpuVendor === "intel") {
            intelFreq.reload();
        }
        // NVIDIA streams on its own while the bay is open (see nvidiaSmi).
    }

    function setGpu(patch) {
        const g = Object.assign({
            vendor: gpuVendor,
            name: "",
            utilPercent: null,
            vramUsedBytes: null,
            vramTotalBytes: null,
            tempC: null,
            powerW: null,
            clockMHz: null
        }, gpu || {}, patch);
        gpu = g;
    }

    FileView {
        id: amdBusy
        path: root.gpuVendor === "amd" ? root.gpuDevice + "/gpu_busy_percent" : ""
        preload: false
        printErrors: false
        onLoaded: {
            const v = T.parseSysfsInt(text());
            root.setGpu({
                utilPercent: v
            });
            root.gpuHistory.push(v);
        }
        onLoadFailed: root.setGpu({
            utilPercent: null
        })
    }
    FileView {
        id: amdVramUsed
        path: root.gpuVendor === "amd" ? root.gpuDevice + "/mem_info_vram_used" : ""
        preload: false
        printErrors: false
        onLoaded: root.setGpu({
            vramUsedBytes: T.parseSysfsInt(text())
        })
    }
    FileView {
        id: amdVramTotal
        path: root.gpuVendor === "amd" ? root.gpuDevice + "/mem_info_vram_total" : ""
        preload: false
        printErrors: false
        onLoaded: root.setGpu({
            vramTotalBytes: T.parseSysfsInt(text())
        })
    }
    FileView {
        id: intelFreq
        // gpuDevice is /sys/class/drm/cardN/device; the counter lives on cardN.
        path: root.gpuVendor === "intel" ? root.gpuDevice.replace(/\/device$/, "") + "/gt_cur_freq_mhz" : ""
        preload: false
        printErrors: false
        onLoaded: root.setGpu({
            clockMHz: T.parseSysfsInt(text())
        })
    }

    Process {
        id: nvidiaSmi
        running: root.gpuVendor === "nvidia" && root.panelActive
        command: ["nvidia-smi", "--query-gpu=" + T.NVIDIA_QUERY.join(","), "--format=csv,noheader,nounits", "-lms", String(Math.max(500, root.cfg.panelIntervalMs))]
        stdout: SplitParser {
            onRead: line => {
                const g = T.parseNvidiaSmi(line);
                if (!g)
                    return;
                root.gpu = g;
                root.gpuHistory.push(g.utilPercent);
                root.gpuStatus = "ok";
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.panelActive)
                root.gpuStatus = "nvidia-smi exited with status " + code + " (is nvidia-utils installed?)";
        }
    }

    // Storage
    Process {
        id: dfProc
        command: ["df", "-P", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: root.disks = T.parseDf(text)
        }
    }

    // Processes, only while the process list is visible.
    Timer {
        interval: Math.max(2000, root.cfg.detailIntervalMs)
        running: root.detailActive
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!psProc.running)
            psProc.running = true
    }
    Process {
        id: psProc
        command: ["ps", "-eo", "pid=,times=,rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = T.parsePs(text);
                const now = Date.now();
                root.processes = T.topProcesses(root.prevPs, cur, now - root.prevPsAt, 12, root.processSort);
                root.prevPs = cur;
                root.prevPsAt = now;
            }
        }
    }
    onDetailActiveChanged: if (!detailActive) {
        prevPs = null;
        processes = [];
    }

    Component.onCompleted: {
        Registry.register({
            id: "telemetry.performance-mode",
            title: "Toggle telemetry performance mode",
            category: "system",
            keywords: ["gaming", "telemetry", "sampling", "performance"],
            description: "Halve all sampling rates",
            run: () => {
                const next = !root.cfg.performanceMode;
                const err = Config.setValue("telemetry.performanceMode", next);
                return err ? Registry.fail(err) : Registry.ok("Performance mode " + (next ? "on" : "off") + " (saved to config)");
            }
        });
    }
}
