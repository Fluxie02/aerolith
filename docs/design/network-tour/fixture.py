"""Private headless fixture: instruments a disposable copy, never production IPC."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
p = root / 'modules/strip/FlightStrip.qml'
s = p.read_text().replace('objectName: "flightStrip"', 'objectName: "flightStrip"\n    readonly property var testPicker: picker === "network" ? networkPickerLoader.item : picker === "bluetooth" ? bluetoothPickerLoader.item : null')
s = s.replace('        // Identity mark: opens the Command Core.\n        Item {', '        // Identity mark: opens the Command Core.\n        Item {\n            objectName: \"stripSearchButton\"')
p.write_text(s)
p = root / 'services/Idle.qml'
s = p.read_text().replace('id: root', 'id: root\n    property int testIdle: 0', 1).replace('monitor.isIdle', '(testIdle < 0 ? monitor.isIdle : testIdle === 1)')
p.write_text(s)
p = root / 'shell.qml' 
s = p.read_text().replace('import QtQuick\n', 'import QtQuick\nimport Quickshell.Io\n', 1).replace('model: Displays.stripScreens', 'id: stripOutputs\n        model: Displays.stripScreens')
probe = '''
    IpcHandler {
        target: "visualTest"
        function snapshot(): string {
            function rect(item, surface) {
                const p = item.mapToItem(surface.contentItem, 0, 0);
                return {name:item.objectName, x:p.x, y:p.y, w:item.width, h:item.height, visible:item.visible, opacity:item.opacity};
            }
            function walk(item, surface, found) {
                if (!item) return;
                if (item.objectName) {
                    const r = rect(item, surface);
                    if (item.objectName === "networkPasswordInput") r.length = item.text.length;
                    found.push(r);
                }
                for (const child of item.children || []) walk(child, surface, found);
            }
            const strips = stripOutputs.instances.map(l => l.item).filter(w => !!w).map(w => {
                let parts = []; walk(w.contentItem, w, parts);
                let popup = null;
                if (w.testPicker) {
                    let controls = []; walk(w.testPicker.contentItem, w.testPicker, controls);
                    popup = {output:w.testPicker.screen.name, name:w.testPicker.objectName, rows:w.testPicker.rows, controls:controls};
                }
                return {output:w.screen.name, profile:w.profile.profile, parts:parts, popup:popup};
            });
            let tour = null;
            if (tourSurface.item) {
                let parts = []; walk(tourSurface.item.contentItem, tourSurface.item, parts);
                tour = {step:Tour.step, output:tourSurface.item.screen.name, profile:tourSurface.item.profile.profile, parts:parts, target:tourSurface.item.target};
            }
            return JSON.stringify({primary:Config.display.primary, timeout:Idle.timeout, strips:strips, tour:tour, scan:Network._scanDemand, discovery:Bluetooth._discoveryDemand, discovering:Bluetooth.discovering, network:Network.networks, devices:Bluetooth.devices});
        }
        function picker(output: string, kind: string): void {
            const strip = stripOutputs.instances.map(l => l.item).filter(w => w && w.screen.name === output)[0];
            if (strip) strip.picker = kind;
        }
    }
'''
p.write_text(s.replace('    ControlSurface {}', probe + '\n    ControlSurface {}'))
