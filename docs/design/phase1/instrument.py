"""Read-only UI probes in a disposable shell copy; no production IPC additions."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
p = root / "shell.qml"
s = p.read_text().replace('import QtQuick\n', 'import QtQuick\nimport Quickshell.Io\n', 1)
s = s.replace('    LazyLoader {\n        active: !!Ui.overlayScreen', '    LazyLoader {\n        id: evidenceDeck\n        active: !!Ui.overlayScreen', 1)
probe = '''
    IpcHandler {
        target: "phase1Evidence"
        function snapshot(): string {
            function surface(window) {
                if (!window) return null;
                const parts = [];
                function walk(item) {
                    if (!item) return;
                    if (item.visible && (item.objectName || typeof item.text === "string")) {
                        const point = item.mapToItem(window.contentItem, 0, 0);
                        parts.push({name: item.objectName, text: typeof item.text === "string" ? item.text : "",
                            x: point.x, y: point.y, w: item.width, h: item.height, focus: item.activeFocus});
                    }
                    for (const child of item.children || []) walk(child);
                }
                walk(window.contentItem);
                return {width: window.width, height: window.height, parts: parts};
            }
            return JSON.stringify({bay: Ui.activeBay, errors: Config.errors, warnings: Config.warnings,
                tourActive: Tour.active, step: Tour.step, deck: surface(evidenceDeck.item), tour: surface(tourSurface.item)});
        }
    }
'''
p.write_text(s.replace('    ControlSurface {}', probe + '\n    ControlSurface {}'))
