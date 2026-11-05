pragma Singleton
import QtQuick
import Quickshell
import "../lib/anchors.mjs" as Logic

Singleton {
    id: registry
    property var records: ({})
    property int generation: 0
    function claim(output, name) {
        const token = ++generation;
        records = Logic.claim(records, output, name, token);
        return token;
    }
    function update(output, name, token, rect, origin) {
        records = Logic.update(records, output, name, token, rect ? Logic.outputRect(rect, origin) : null);
    }
    function release(output, name, token) {
        records = Logic.release(records, output, name, token);
    }
    function lookup(output, name) { return Logic.lookup(records, output, name); }
}
