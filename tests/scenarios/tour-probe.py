"""Add measured target/registry probes to tour.sh's throwaway shell only.

Runs after docs/design/network-tour/fixture.py. Never adds production IPC.
"""
from pathlib import Path
import sys

root = Path(sys.argv[1])
p = root / "shell.qml"
s = p.read_text().replace("model: Displays.groundScreens", "id: groundOutputs\n        model: Displays.groundScreens", 1)
needle = 'return JSON.stringify({primary:Config.display.primary,'
assert needle in s, "visualTest fixture changed"
s = s.replace(needle, '''
            function groundSurface(loader) {
                const w = loader.item;
                if (!w) return null;
                let parts = []; walk(w.contentItem, w, parts);
                return { output: w.screen.name, parts: parts };
            }
            function workspaceItems(item, found) {
                if (!item) return;
                if (item.toString().indexOf("WorkspaceOrbit") === 0)
                    found.push({ kind: "ring", cells: item.cells, stations: item.stations });
                if (item.toString().indexOf("WorkspaceTape") === 0)
                    found.push({ kind: "tape", cells: item.cells });
                for (const child of item.children || []) workspaceItems(child, found);
            }
            const groundWindows = groundOutputs.instances.map(l => l.item).filter(w => !!w);
            const stripWindows = stripOutputs.instances.map(l => l.item).filter(w => !!w);
            const workspaceViews = [];
            for (const w of groundWindows.concat(stripWindows)) workspaceItems(w.contentItem, workspaceViews);
            const registered = groundWindows.concat(stripWindows).map(w => ({
                output: w.screen.name,
                anchors: Tour.steps.map(name => ({ name: name, rect: Anchors.lookup(w.screen.name, name) }))
            }));
            return JSON.stringify({bay: Ui.activeBay, anchors: registered, groundTargets: groundOutputs.instances.map(groundSurface).filter(w => !!w), workspaceViews: workspaceViews, primary:Config.display.primary,''', 1)
# Add a narrowly scoped private mutation to verify ancestor moves, scale, hiding,
# and remapping event updates rather than merely checking initial geometry.
needle = '        function picker(output: string, kind: string): void {'
assert needle in s
s = s.replace(needle, '''        function overflow(): void {
            function visit(item) {
                if (!item) return false;
                if (item.objectName === "workspaceOverflow") { item.choose(); return true; }
                for (const child of item.children || []) if (visit(child)) return true;
                return false;
            }
            for (const l of groundOutputs.instances) if (l.item && visit(l.item.contentItem)) return;
        }
        function target(action: string): void {
            function visit(item) {
                if (!item) return;
                if (item.objectName === "hatchEntrance") {
                    if (action === "hide") item.visible = false;
                    else if (action === "show") item.visible = true;
                    else if (action === "move") item.parent.x += 13;
                    else if (action === "unmove") item.parent.x -= 13;
                    else if (action === "scale") item.scale = .9;
                    else if (action === "unscale") item.scale = 1;
                }
                for (const child of item.children || []) visit(child);
            }
            for (const l of groundOutputs.instances) if (l.item) visit(l.item.contentItem);
        }
''' + needle, 1)
# The original fixture measures only origin plus untransformed size. These tests
# also exercise actual transformed target bounds inside their own surface.
s = s.replace('const p = item.mapToItem(surface.contentItem, 0, 0);',
              'const p = item.mapToItem(surface.contentItem, 0, 0, item.width, item.height);')
s = s.replace('w:item.width, h:item.height,', 'w:p.width, h:p.height, text:item.objectName === "tourExplanation" ? item.text : "",')
p.write_text(s)

p = root / "modules/strip/FlightStrip.qml"
s = p.read_text().replace('    // Datum line on the inner edge.',
    '    Item { objectName: "stripSurfaceBounds"; anchors.fill: parent }\n    // Datum line on the inner edge.', 1)
p.write_text(s)
