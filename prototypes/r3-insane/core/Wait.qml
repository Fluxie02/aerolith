pragma Singleton

import QtQuick
import Quickshell

// Promise helpers for confirming that a requested change actually happened.
// Services use until() so a command only reports success after the system
// reflects the change (e.g. PipeWire accepted a new default device).
Singleton {
    id: root

    Component {
        id: pollComponent
        Timer {
            property var predicate
            property var resolve
            property real deadline: 0
            interval: 50
            repeat: true
            running: true
            onTriggered: {
                let done = false;
                try {
                    done = predicate() === true;
                } catch (e) {
                    done = false;
                }
                if (done || Date.now() >= deadline) {
                    stop();
                    resolve(done);
                    destroy();
                }
            }
        }
    }

    // Resolves true as soon as predicate() returns true, or false after
    // timeoutMs. Never rejects.
    function until(predicate, timeoutMs) {
        return new Promise(resolve => {
            let immediate = false;
            try {
                immediate = predicate() === true;
            } catch (e) {
                immediate = false;
            }
            if (immediate) {
                resolve(true);
                return;
            }
            pollComponent.createObject(root, {
                predicate: predicate,
                resolve: resolve,
                deadline: Date.now() + (timeoutMs || 1000)
            });
        });
    }

    Component {
        id: delayComponent
        Timer {
            property var resolve
            running: true
            onTriggered: {
                resolve(true);
                destroy();
            }
        }
    }

    function delay(ms) {
        return new Promise(resolve => delayComponent.createObject(root, {
                interval: Math.max(0, ms),
                resolve: resolve
            }));
    }
}
