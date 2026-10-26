#!/usr/bin/env python3
"""Add inspection-only IPC to a disposable snapshot; never changes a host."""
from pathlib import Path
import shutil, sys
ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT/'build/ui016/verification'
source = ROOT/sys.argv[1] if len(sys.argv)>1 else BASE/'final-shell'
target = BASE/'mid-exit-probe-shell'
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target)
entry = target/'shell.qml'
text = entry.read_text()
text = text.replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n', 1)
text = text.replace('    Deck {\n', '    Deck {\n        id: probeDeck\n', 1)
probe = '''
    IpcHandler {
        target: "ui016review"
        function disable(mode: string): string {
            Ui.close();
            const before = {
                exitMs: probeDeck.exitMs,
                mapped: Ui.deckMapped,
                leaving: probeDeck.slotA.leaving || probeDeck.slotB.leaving
            };
            const saved = mode === "lowEffects"
                ? Config.setValue("theme.lowEffects", true)
                : Config.setValue("theme.motion", "off");
            const after = {
                exitMs: probeDeck.exitMs,
                mapped: Ui.deckMapped,
                leaving: probeDeck.slotA.leaving || probeDeck.slotB.leaving
            };
            return JSON.stringify({mode: mode, saved: saved, before: before, after: after});
        }
    }
'''
text = text.replace('    Component.onCompleted: {', probe+'\n    Component.onCompleted: {', 1)
entry.write_text(text)
shutil.copyfile(Path(__file__).with_name('mid-exit-probe.sh'), BASE/'mid-exit-probe.sh')
print('Disposable mid-exit inspection shell prepared; protected Deck.qml unchanged.')
