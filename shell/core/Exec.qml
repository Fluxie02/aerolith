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
            property string stdoutText: ""
            property string stderrText: ""

            function finish(r) {
                if (done)
                    return;
                done = true;
                killTimer.stop();
                const cb = resolve;
                Qt.callLater(() => proc.destroy());
                cb(r);
            }

            function complete() {
                finish({
                    code: exitCode,
                    stdout: stdoutText,
                    stderr: stderrText,
                    timedOut: false
                });
            }

            // An empty marker consumes arbitrary chunks immediately, including
            // output without newlines. Keep draining after the buffer is full.
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => proc.stdoutText += data.slice(0, Math.max(0, proc.maxOutput - proc.stdoutText.length))
            }
            stderr: SplitParser {
                splitMarker: ""
                onRead: data => proc.stderrText += data.slice(0, Math.max(0, proc.maxOutput - proc.stderrText.length))
            }
            onExited: (code, status) => {
                exitCode = code;
                exitedFlag = true;
                // Process flushes both parsers before emitting exited.
                complete();
            }
            onRunningChanged: {
                // FailedToStart emits runningChanged(false), but no exited.
                if (!running && !exitedFlag && !done)
                    proc.finish({
                        code: -1,
                        stdout: "",
                        stderr: "could not start " + command[0],
                        timedOut: false
                    });
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
                timeoutMs: opts.timeoutMs || 10000,
                maxOutput: opts.maxOutput === undefined ? 65536 : Math.max(0, Math.min(65536, opts.maxOutput))
            });
            p.running = true;
        });
    }
}
