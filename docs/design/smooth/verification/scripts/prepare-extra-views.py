#!/usr/bin/env python3
"""Load standalone visual views in a disposable ordinary overlay, never a lock."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[5]
BASE=ROOT/'build/ui016/verification'
source=ROOT/sys.argv[1] if len(sys.argv)>1 else ROOT/'shell'
target=BASE/'extra-views-shell'
if target.exists():shutil.rmtree(target)
shutil.copytree(source,target)
entry=target/'shell.qml';text=entry.read_text()
text=text.replace('import Quickshell\n','import Quickshell\nimport Quickshell.Io\nimport Quickshell.Wayland\nimport qs.components\nimport "modules/osd"\nimport "modules/lock"\nimport "modules/session"\n',1)
extra='''
    property int previewKind: 0
    property int osdSettles: 0
    IpcHandler {
        target: "ui016views"
        function configure(motion: string, low: bool): string {
            Config.setValue("theme.motion", motion);
            Config.setValue("theme.lowEffects", low);
            return state();
        }
        function setOpen(value: bool): string { previewOsd.presentationOpen = value; return state(); }
        function bounce(): string {
            previewOsd.presentationOpen = false;
            previewOsd.presentationOpen = true;
            return state();
        }
        function closeAndDisable(mode: string): string {
            previewOsd.presentationOpen = false;
            if (mode === "lowEffects") Config.setValue("theme.lowEffects", true);
            else Config.setValue("theme.motion", mode);
            return state();
        }
        function progress(value: real): string { previewCircle.progress = value; return state(); }
        function setKind(kind: int): string { shell.previewKind = kind; return state(); }
        function state(): string {
            return JSON.stringify({motion: Config.theme.motion, lowEffects: Config.theme.lowEffects,
                open: previewOsd.presentationOpen, presenting: previewOsd.presenting,
                settled: shell.osdSettles, circleProgress: previewCircle.progress, kind: shell.previewKind});
        }
    }
    PanelWindow {
        screen: Ui.screen; visible: Ui.screen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore; color: Theme.bg
        WlrLayershell.namespace: "ui016-visual-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Item {
            anchors.fill: parent; visible: shell.previewKind === 0
            OsdView {
                id: previewOsd; x: 100; y: 130
                width: implicitWidth; height: implicitHeight
                value: .42; label: "UI-016 visual fixture"
                onSettled: { shell.osdSettles++; console.warn("UI016_OSD_SETTLED " + shell.osdSettles); }
            }
            CircularField { id: previewCircle; x: 650; y: 110; width: 900; height: 850; instrument: true }
        }
        Loader {
            anchors.fill: parent; active: shell.previewKind === 1
            sourceComponent: Component { LockView { user: "Visual preview"; message: "No authentication in this fixture." } }
        }
        Loader {
            anchors.fill: parent; active: shell.previewKind === 2
            sourceComponent: Component { SessionView { actions: [{id: "logout", label: "Log out", available: true, sensitive: true}, {id: "suspend", label: "Suspend", available: false, reason: "Visual preview"}] } }
        }
    }
'''
text=text.replace('    Component.onCompleted: {',extra+'\n    Component.onCompleted: {',1)
entry.write_text(text)
manifest={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source.rglob('*')) if p.is_file()}
(ROOT/'docs/design/smooth/verification/extra-views-source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Extra visual fixture copied; production and hosts unchanged.')
