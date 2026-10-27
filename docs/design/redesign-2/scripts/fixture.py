"""Instrument a disposable shell copy; never edit the production services.

This is visual evidence only. The unique registry command and IPC controls
stand in for Sol's scratch interface; they do not dispatch to Hyprland.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / "components/Hatch.qml"
source = path.read_text()
source = source.replace("import QtQuick", "import Quickshell.Io\nimport QtQuick", 1)
replacements = {
    "Compositor.scratchWindows || []": "evidenceWindows",
    'Compositor.available && typeof Compositor.scratchWindows !== "undefined"': "true",
    "Compositor.scratchOpen === true": "evidenceOpen",
    '"scratch.toggle"': '"visual.hatch.toggle"',
}
for old, new in replacements.items():
    assert old in source, old
    source = source.replace(old, new)
probe = '''
    property var evidenceWindows: []
    property bool evidenceOpen: false
    property int evidenceToggles: 0
    Component.onCompleted: {
      if (!hatch.visible || Registry.get("visual.hatch.toggle")) return;
      Registry.register({
        id: "visual.hatch.toggle", title: "Visual hatch fixture", category: "workspaces", record: false,
        run: function() {
            hatch.evidenceOpen = !hatch.evidenceOpen;
            hatch.evidenceToggles++;
            return Registry.ok("", {quiet: true});
        }
      }, "visual-hatch-fixture");
    }
    IpcHandler {
        target: "hatch-evidence"
        enabled: hatch.exposed
        function theme(key: string, value: string): string {
            return JSON.stringify(Config.setValue("theme." + key, value));
        }
        function trigger(): string {
            hatch.toggle();
            return snapshot();
        }
        function contents(mode: string): string {
            hatch.evidenceWindows = mode === "empty" ? [] : [
                {address:"0xf001", title:"Project notes", appId:"org.gnome.TextEditor", workspaceId:-99},
                {address:"0xf002", title:"Build output — terminal", appId:"foot", workspaceId:-99},
                {address:"0xf003", title:"<b>Literal window title</b>", appId:"browser", workspaceId:-99},
                {address:"0xf004", title:"Fourth parked window", appId:"Code", workspaceId:-99}
            ];
            return snapshot();
        }
        function snapshot(): string {
            const p = entrance.mapToItem(null, entrance.width / 2, aperture.y + aperture.height / 2);
            return JSON.stringify({open:hatch.opened, count:hatch.parkedWindows.length,
                known:hatch.known, canToggle:hatch.canToggle, motion:hatch.motionAllowed,
                direction:Theme.applicationDirection, scheme:Theme.scheme, intensity:Theme.intensity,
                policy:Theme.cfg.motion,
                toggles:hatch.evidenceToggles, x:p.x, y:p.y,
                width:entrance.width, height:aperture.height,
                leftX:leaves.itemAt(0).x, rightX:leaves.itemAt(1).x});
        }
    }
'''
assert "    id: hatch\n" in source
source = source.replace("    id: hatch\n", "    id: hatch\n" + probe, 1)
assert "                    model: 2\n" in source
source = source.replace("                    model: 2\n", "                    id: leaves\n                    model: 2\n", 1)
path.write_text(source)
