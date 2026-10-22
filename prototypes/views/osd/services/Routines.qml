pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/routines.mjs" as RL

// Routine engine host: loads ~/.config/aerolith/routines.json, validates it
// against the live command registry, and runs routines with per-step
// progress, cancellation between steps and reversal of steps that report a
// genuine inverse. Routines never contain code; see lib/routines.mjs.
Singleton {
    id: root

    property var routines: []
    property var errors: []
    property bool fileMissing: false
    property string rawText: ""

    // Live run state for the Routine Console.
    property string runningId: ""
    property var progress: []
    property var lastReport: null
    property var handle: null
    readonly property bool running: runningId !== ""

    function revalidate() {
        let doc;
        if (rawText.trim() === "") {
            doc = RL.emptyDocument();
        } else {
            try {
                doc = JSON.parse(rawText);
            } catch (e) {
                routines = [];
                errors = [{
                        routine: null,
                        step: null,
                        message: "routines.json is not valid JSON: " + e.message
                    }];
                return;
            }
        }
        const r = RL.validateRoutines(doc, Registry.api, Registry.context());
        routines = r.routines;
        errors = r.errors;
        for (let i = 0; i < errors.length; i++)
            Log.warn("routines", (errors[i].routine ? errors[i].routine + (errors[i].step ? " step " + errors[i].step : "") + ": " : "") + errors[i].message);
    }

    function find(id) {
        for (let i = 0; i < routines.length; i++)
            if (routines[i].id === id)
                return routines[i];
        return null;
    }

    function preview(id) {
        const r = find(id);
        return r ? RL.preview(r, Registry.api, Registry.context()) : null;
    }

    // Start a run. Returns a Promise of the run report.
    function start(id, confirmed) {
        const r = find(id);
        if (!r)
            return Promise.resolve({
                ok: false,
                message: "No routine " + id
            });
        if (running)
            return Promise.resolve({
                ok: false,
                message: "Routine " + runningId + " is still running"
            });
        runningId = id;
        progress = [];
        const h = RL.run(r, Registry.api, Registry.context(), {
            confirmed: confirmed === true,
            onStep: s => root.progress = root.progress.concat([s])
        });
        handle = h;
        return h.promise.then(rep => {
            runningId = "";
            handle = null;
            if (!rep.needsConfirmation)
                lastReport = rep;
            return rep;
        });
    }

    function cancel() {
        if (handle)
            handle.cancel();
    }

    function revertLast() {
        if (!lastReport || !lastReport.undo || lastReport.undo.length === 0)
            return Promise.resolve(Registry.fail("Nothing to revert"));
        const rep = lastReport;
        return RL.revert(rep, Registry.api, Registry.context()).then(rv => {
            lastReport = null;
            return rv.ok ? Registry.ok("Reverted " + rep.name) : Registry.fail("Revert of " + rep.name + " partly failed");
        });
    }

    function summary(rep) {
        if (rep.needsConfirmation)
            return Registry.fail(rep.name + " needs confirmation", {
                needsConfirmation: true
            });
        const failed = rep.steps.filter(s => !s.ok && !s.skipped).length;
        if (rep.cancelled)
            return Registry.fail(rep.name + " cancelled");
        return rep.ok ? Registry.ok(rep.name + ": " + rep.steps.length + " steps done") : Registry.fail(rep.name + ": " + failed + " step(s) failed");
    }

    FileView {
        id: file
        path: Paths.routinesFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.fileMissing = false;
            root.rawText = text();
            root.revalidate();
        }
        onLoadFailed: {
            root.fileMissing = true;
            root.rawText = "";
            root.revalidate();
        }
    }

    // Re-check when commands appear (e.g. a service registers late) so a
    // routine referencing it becomes valid without restarting.
    Connections {
        target: Registry
        function onRevisionChanged() {
            revalidateTimer.restart();
        }
    }
    Timer {
        id: revalidateTimer
        interval: 300
        onTriggered: root.revalidate()
    }

    property var unregisterExec: null
    function syncExecCommand() {
        const allowed = Config.routines.allowCommandSteps;
        if (allowed && !unregisterExec) {
            unregisterExec = Registry.register({
                id: "shell.exec",
                title: "Run program",
                category: "system",
                hidden: true,
                sensitive: true,
                aiAllowed: false,
                description: "Run a program directly (no shell). Enabled by routines.allowCommandSteps.",
                params: [
                    {
                        name: "argv",
                        type: "strings",
                        required: true,
                        maxItems: 64
                    }
                ],
                routine: true,
                describe: args => "runs: " + args.argv.join(" "),
                run: args => Exec.run(args.argv, {
                        timeoutMs: 60000
                    }).then(r => r.code === 0 ? Registry.ok(args.argv[0] + " finished") : Registry.fail(args.argv[0] + " failed (" + (r.timedOut ? "timed out" : "status " + r.code) + ")", {
                            detail: r.stderr.trim().slice(0, 300)
                        }))
            });
        } else if (!allowed && unregisterExec) {
            unregisterExec();
            unregisterExec = null;
        }
    }
    Connections {
        target: Config
        function onReloaded() {
            root.syncExecCommand();
        }
    }

    Component.onCompleted: {
        syncExecCommand();
        Registry.register({
            id: "routine.run",
            title: "Run routine",
            category: "routines",
            alias: "rt",
            keywords: ["routine", "macro", "automation"],
            params: [
                {
                    name: "routine",
                    type: "enum",
                    required: true,
                    choices: () => root.routines.map(r => r.id)
                }
            ],
            available: () => root.running ? "A routine is already running" : true,
            run: args => root.start(args.routine, false).then(rep => {
                if (rep.needsConfirmation) {
                    Ui.open("routines");
                    Ui.selectedRoutine = args.routine;
                }
                return root.summary(rep);
            })
        });
        Registry.register({
            id: "routine.open",
            title: "Preview routine",
            category: "routines",
            hidden: true,
            record: false,
            params: [
                {
                    name: "routine",
                    type: "string",
                    required: true,
                    maxLength: 48
                }
            ],
            run: args => {
                Ui.selectedRoutine = args.routine;
                Ui.open("routines");
                return Registry.ok("Routine console");
            }
        });
        Registry.register({
            id: "routine.revert",
            title: "Revert last routine",
            category: "routines",
            keywords: ["undo", "routine"],
            available: () => root.lastReport && root.lastReport.undo && root.lastReport.undo.length > 0 ? true : "No reversible routine run",
            run: () => root.revertLast()
        });
        Registry.register({
            id: "shell.notify",
            title: "Show a notice",
            category: "shell",
            hidden: true,
            params: [
                {
                    name: "message",
                    type: "string",
                    required: true,
                    maxLength: 200
                }
            ],
            routine: true,
            run: args => {
                Ui.notify(args.message, "info");
                return Registry.ok("Notice shown", {
                    quiet: true
                });
            }
        });
        Registry.register({
            id: "shell.delay",
            title: "Wait",
            category: "shell",
            hidden: true,
            params: [
                {
                    name: "ms",
                    type: "int",
                    min: 0,
                    max: 30000,
                    required: true
                }
            ],
            routine: true,
            timeoutMs: 35000,
            run: args => Wait.delay(args.ms).then(() => Registry.ok("Waited " + args.ms + " ms"))
        });
        Registry.registerProvider({
            id: "routines",
            kind: "routine",
            items: () => root.routines.map(r => ({
                        id: r.id,
                        title: r.name,
                        subtitle: r.description || r.steps.length + " steps",
                        keywords: ["routine", r.id],
                        category: "routines",
                        commandId: "routine.open",
                        args: {
                            routine: r.id
                        },
                        badge: r.steps.some(s => s.sensitive) ? "CONFIRM" : ""
                    }))
        });
    }
}
