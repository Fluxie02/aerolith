pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/tour.mjs" as T

// State only. The future UI uses output.screen and never chooses its own output.
Singleton {
    id: root

    readonly property var steps: T.STEPS
    readonly property var output: Displays.primary
    readonly property bool completed: T.isCompleted(Store.tour)
    readonly property int step: progress.step
    readonly property bool active: progress.active && mayShow
    property var progress: ({ active: false, step: 0 })
    property bool started: false
    property bool settled: false

    readonly property var context: ({
        ready: settled && Config.loaded && Store.ready && !!output
            && !!ShellState.outputStates[output.name]
            && (!Displays.available || !!output.monitorName),
        enabled: Config.data.tour.enabled,
        output: output,
        locked: Ui.locked,
        fullscreen: output ? ShellState.stateFor(output.name).fullscreen : false,
        completed: completed,
        started: started
    })
    readonly property bool mayShow: T.mayShowNow(context)
    readonly property bool autoStart: T.shouldAutoStart(context)
    onAutoStartChanged: if (autoStart) Qt.callLater(root.tryAutoStart)

    function tryAutoStart() {
        if (autoStart) start();
    }

    function change(action) {
        progress = T.transition({ active: active, step: step, completed: completed }, action);
        if (progress.completed && !completed) Store.completeTour(T.VERSION);
    }
    function start() {
        if (!mayShow) return false;
        started = true;
        change("start");
        return true;
    }
    function next() { if (active) change("next"); }
    function back() { if (active) change("back"); }
    function skip() { if (Store.ready) change("skip"); }
    function finish() { if (Store.ready) change("finish"); }

    // ShellState/Displays request their initial Hyprland snapshots asynchronously
    // (including a 30 ms coalescing refresh). Let those and LockHost initialise
    // before the first eligibility check; all later changes use bindings only.
    Timer {
        interval: 250
        running: true
        repeat: false
        onTriggered: { root.settled = true; root.tryAutoStart(); }
    }

    IpcHandler {
        target: "tour"
        function state(): string {
            return JSON.stringify({ active: root.active, step: root.step,
                stepId: root.steps[root.step], completed: root.completed });
        }
        function next(): void { root.next(); }
        function back(): void { root.back(); }
        function skip(): void { root.skip(); }
        function start(): void { root.start(); }
    }

    Component.onCompleted: Registry.register({
        id: "tour.start",
        title: "Show the tour again",
        category: "shell",
        keywords: ["tour", "welcome", "first run"],
        available: () => Ui.locked ? "Session is locked"
            : !root.mayShow ? "Waiting for the primary desktop to be ready" : true,
        run: () => root.start() ? Registry.ok("Tour started") : Registry.fail("Tour is unavailable")
    })
}
