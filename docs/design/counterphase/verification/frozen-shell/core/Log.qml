pragma Singleton

import QtQuick
import Quickshell

// Levelled logging into the Quickshell log (see `qs log`). Messages are
// prefixed with a subsystem tag. Never pass credentials or full provider
// output here.
Singleton {
    id: root

    readonly property var levels: ({ debug: 0, info: 1, warn: 2, error: 3 })
    property string level: "info"

    function enabled(lvl) {
        return levels[lvl] >= (levels[level] === undefined ? 1 : levels[level]);
    }

    function debug(tag, msg) {
        if (enabled("debug"))
            console.log("[aerolith:" + tag + "] " + msg);
    }
    function info(tag, msg) {
        if (enabled("info"))
            console.info("[aerolith:" + tag + "] " + msg);
    }
    function warn(tag, msg) {
        if (enabled("warn"))
            console.warn("[aerolith:" + tag + "] " + msg);
    }
    function error(tag, msg) {
        console.error("[aerolith:" + tag + "] " + msg);
    }
}
