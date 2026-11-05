pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core
import "../lib/welcome.mjs" as W

// Service contract only. Astra supplies the lazy output-profiled surface.
Singleton {
    id: root

    property bool requested: false
    property string outputName: ""
    property bool settled: false
    property bool startupChecked: false
    readonly property var output: Displays.output(outputName) || Displays.primary
    readonly property bool firstRunPending: W.firstRunPending(Store.ready, Store.hadState, Store.welcome, Store.tour)
    readonly property bool showOnStartup: Config.data.welcome.showOnStartup
    readonly property bool ready: settled && Store.ready && Config.loaded && !!output
        && !!ShellState.outputStates[output.name] && (!Displays.available || !!output.monitorName)
    readonly property bool active: requested && W.mayShow({ready: ready, output: output,
        locked: Ui.locked, fullscreen: output ? ShellState.stateFor(output.name).fullscreen : false})
    readonly property bool holdsTourAutoStart: firstRunPending || requested
        || (!startupChecked && showOnStartup) || !Store.welcome.handedOff
    readonly property bool startupReady: ready && !startupChecked
    onStartupReadyChanged: if (startupReady) Qt.callLater(root.checkStartup)

    property var startup: ({ method: null, enabled: null, state: "unknown", error: null })
    property bool startupBusy: false
    property var diagnostics: ({ running: false, ok: null, checks: [], error: null })
    readonly property var info: ({ version: SystemInfo.version, dialect: Compositor.dialect || null,
        gpu: Telemetry.gpu && Telemetry.gpu.name ? Telemetry.gpu.name : Telemetry.gpuVendor || null,
        outputs: Displays.outputs.map(o => ({name: o.name,
            mode: o.monitorName ? outputMode(o) : null,
            scale: o.scale || null, profile: o.profile || null})),
        configErrors: Config.errors, configWarnings: Config.warnings })
    readonly property var checklist: W.checklist({configLoaded: Config.loaded, fileBroken: Config.fileBroken,
        fileMissing: Config.fileMissing, configErrors: Config.errors, outputsReady: settled,
        primary: Displays.primary, startup: startup, tourCompleted: Store.welcome.tourFinished === null
            ? (Store.tour.completed ? null : false) : Store.welcome.tourFinished})
    property var docAvailability: ({})
    readonly property var docs: W.DOCS.map(d => ({id: d.id, title: d.title,
        path: Paths.docsDir + "/" + d.relative, available: docAvailability[d.id] === true}))

    function outputMode(o) {
        const m = Compositor.available ? Hyprland.monitors.values.find(m => m.name === o.monitorName) : null;
        return m && m.width && m.height ? m.width + "x" + m.height
            + (o.refresh ? "@" + o.refresh : "") : null;
    }
    function checkStartup() {
        if (!startupReady) return;
        startupChecked = true;
        if (firstRunPending || showOnStartup) open("startup");
    }
    function open(reason) {
        if (!Store.ready) return false;
        const target = reason === "startup" ? Displays.primary : Displays.focused || Displays.primary;
        outputName = target ? target.name : "";
        Tour.pause();
        requested = true;
        refreshStartup();
        return true;
    }
    function close() {
        requested = false;
        Store.saveWelcome(Object.assign({}, Store.welcome, {seen: true, handedOff: false}));
    }
    function startUsing() { close(); }
    function takeTour() {
        if (!active) return false;
        const savedStep = Tour.completed ? 0 : Store.welcome.tourStep;
        requested = false;
        Store.saveWelcome(Object.assign({}, Store.welcome, {seen: true, handedOff: true, tourStep: savedStep}));
        if (Tour.resume(savedStep)) return true;
        requested = true;
        return false;
    }
    function tourEnded(finished) {
        if (finished) open("tour");
    }
    function cli(args, timeoutMs) {
        // PATH first, then the per-user launcher and packaged binary. Python's
        // layout shares Paths' AEROLITH_CONFIG_DIR/STATE_DIR overrides.
        return Exec.run(["sh", "-c", 'command -v aerolith || { for p in "$@"; do if [ -x "$p" ]; then printf "%s\\n" "$p"; exit 0; fi; done; exit 1; }',
            "welcome-cli", Paths.userCli, Paths.packagedCli], {timeoutMs: 1000}).then(r => {
                const path = r.code === 0 ? r.stdout.trim() : "";
                return path ? Exec.run([path].concat(args), {timeoutMs: timeoutMs})
                    : {code: -1, stdout: "", stderr: "AEROLITH CLI unavailable"};
            });
    }
    function readStartup(result) {
        try {
            const s = JSON.parse(result.stdout).startupState;
            if (result.code !== 0 || !s || ["unknown", "enabled", "disabled"].indexOf(s.state) < 0
                    || (s.enabled !== true && s.enabled !== false && s.enabled !== null)) throw new Error("Invalid startup status");
            startup = s;
        } catch (e) { startup = {method: null, enabled: null, state: "unknown", error: result.stderr || String(e)}; }
    }
    function refreshStartup() {
        if (startupBusy) return;
        startupBusy = true;
        cli(["status", "--json"], 8000).then(r => { readStartup(r); startupBusy = false; });
    }
    function setLaunchOnStartup(enabled) {
        if (typeof enabled !== "boolean" || startupBusy) return false;
        startupBusy = true;
        const args = ["startup", enabled ? "enable" : "disable", "--json"];
        if (startup.method === "hyprland" || startup.method === "systemd") args.push("--method", startup.method);
        cli(args, 25000).then(r => { readStartup(r); startupBusy = false; });
        return true;
    }
    function runDiagnostics() {
        if (diagnostics.running) return false;
        diagnostics = {running: true, ok: null, checks: [], error: null};
        cli(["doctor", "--json"], 35000).then(r => { diagnostics = W.diagnosticsResult(r); });
        return true;
    }
    function openDoc(id) {
        const d = docs.find(d => d.id === id);
        if (!d || !d.available) return false;
        Exec.run(["xdg-open", d.path], {timeoutMs: 5000});
        return true;
    }
    function report() { return W.report(info, diagnostics); }

    // Each doc is read once, lazily on first open. No polling/watchers.
    Instantiator {
        model: W.DOCS
        delegate: FileView {
            required property var modelData
            path: Paths.docsDir + "/" + modelData.relative
            preload: root.requested
            printErrors: false
            onLoaded: root.docAvailability = Object.assign({}, root.docAvailability, {[modelData.id]: true})
            onLoadFailed: root.docAvailability = Object.assign({}, root.docAvailability, {[modelData.id]: false})
        }
    }
    Timer {
        interval: 250
        running: true
        onTriggered: { root.settled = true; root.checkStartup(); }
    }
    IpcHandler {
        target: "welcome"
        function open(): void { root.open("manual"); }
        function close(): void { root.close(); }
        function takeTour(): void { root.takeTour(); }
        function startUsing(): void { root.startUsing(); }
        function runDiagnostics(): void { root.runDiagnostics(); }
        function report(): string { return root.report(); }
        function state(): string {
            return JSON.stringify({active: root.active, output: root.output ? root.output.name : null,
                firstRunPending: root.firstRunPending, showOnStartup: root.showOnStartup,
                checklist: root.checklist, info: root.info, docs: root.docs,
                startup: root.startup, diagnostics: root.diagnostics});
        }
    }
    Component.onCompleted: Registry.register({id: "welcome.open", title: "Welcome", category: "shell",
        keywords: ["onboarding", "start", "help"], run: () => root.open("manual")
            ? Registry.ok("Welcome opened") : Registry.fail("Waiting for shell state")})
}
