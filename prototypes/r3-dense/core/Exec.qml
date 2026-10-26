pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Run a program and collect its result. Commands are argv lists and are
// never passed through a shell, so arguments cannot be reinterpreted.
Singleton {
    id: root

    Component {
        id: procComponent
        Process {
            id: proc
            property var resolve
            property bool done: false
            property int timeoutMs: 10000
            property int maxOutput: 65536
            property int exitCode: -1
            property bool exitedFlag: false
            property bool outDone: false
            property bool errDone: false

            function finish(r) {
                if (done)
                    return;
                done = true;
                killTimer.stop();
                graceTimer.stop();
                const cb = resolve;
                Qt.callLater(() => proc.destroy());
                cb(r);
            }

            function complete() {
                finish({
                    code: exitCode,
                    stdout: out.text.slice(0, maxOutput),
                    stderr: err.text.slice(0, maxOutput),
                    timedOut: false
                });
            }

            function tryComplete() {
                if (exitedFlag && outDone && errDone)
                    complete();
            }

            stdout: StdioCollector {
                id: out
                onStreamFinished: {
                    proc.outDone = true;
                    proc.tryComplete();
                }
            }
            stderr: StdioCollector {
                id: err
                onStreamFinished: {
                    proc.errDone = true;
                    proc.tryComplete();
                }
            }
            onExited: (code, status) => {
                exitCode = code;
                exitedFlag = true;
                tryComplete();
                graceTimer.start();
            }

            // Output streams normally finish with the process; don't wait
            // forever if one never reports.
            property Timer graceTimer: Timer {
                interval: 250
                onTriggered: proc.complete()
            }

            // Runs unconditionally: if the program never starts, `exited` may
            // never fire, and the promise must still resolve.
            property Timer killTimer: Timer {
                interval: proc.timeoutMs
                running: true
                onTriggered: {
                    const started = proc.running;
                    if (started)
                        proc.signal(15);
                    proc.finish({
                        code: -1,
                        stdout: "",
                        stderr: started ? "timed out" : "could not start " + proc.command[0],
                        timedOut: started
                    });
                }
            }
        }
    }

    // run(["busctl", ...], { timeoutMs }) -> Promise<{ code, stdout, stderr, timedOut }>
    // A program that cannot be started resolves with code -1.
    function run(argv, options) {
        const opts = options || {};
        return new Promise(resolve => {
            if (!Array.isArray(argv) || argv.length === 0 || argv.some(a => typeof a !== "string")) {
                resolve({
                    code: -1,
                    stdout: "",
                    stderr: "invalid command",
                    timedOut: false
                });
                return;
            }
            const p = procComponent.createObject(root, {
                command: argv,
                resolve: resolve,
                timeoutMs: opts.timeoutMs || 10000
            });
            p.running = true;
        });
    }
}
