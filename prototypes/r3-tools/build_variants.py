"""UI-004: snapshot production, then add only prototype presentation files.

Run from repository root. Every prototype contains its own complete shell.
The source hashes record the exact production snapshot used for this round.
"""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = ROOT / 'prototypes/r3-tools'
snapshot = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((ROOT / 'shell').rglob('*')) if p.is_file()}
manifest = ROOT / 'docs/design/round3/baseline-sha256.json'
if manifest.exists():
    assert json.loads(manifest.read_text()) == snapshot, 'Production snapshot changed; inspect before rebuilding.'
else:
    manifest.write_text(json.dumps(snapshot, indent=2) + '\n')

for level, name in enumerate(['dense', 'saturated', 'insane'], 1):
    dest = ROOT / ('prototypes/r3-' + name)
    shutil.copytree(ROOT / 'shell', dest, dirs_exist_ok=True)
    for component in ['InstrumentField', 'Instrumentation', 'MetricTape', 'WorkspaceOrbit']:
        shutil.copyfile(TEMPLATES / (component + '.qml'), dest / 'components' / (component + '.qml'))
    shutil.copyfile(TEMPLATES / 'Ground.qml', dest / 'modules/ground/Ground.qml')
    theme = dest / 'core/Theme.qml'
    s = theme.read_text().replace('    // Colour roles', '''    // UI-004 presentation parameters; not new user configuration keys.
    readonly property int variantLevel: LEVEL
    readonly property string variantName: "NAME"
    property bool bootPlayed: false
    property real bootProgress: 1
    readonly property int ignitionDuration: slow * (variantLevel === 1 ? 6 : variantLevel === 2 ? 8 : 10)
    function ignite() {
        if (bootPlayed) return;
        bootPlayed = true;
        if (travel) { bootProgress = 0; ignition.restart(); }
    }
    onTravelChanged: if (!travel) { ignition.stop(); bootProgress = 1; }
    NumberAnimation {
        id: ignition; target: root; property: "bootProgress"
        to: 1; duration: root.ignitionDuration; easing.type: Easing.OutCubic
    }

    // Colour roles'''.replace('LEVEL', str(level)).replace('NAME', name.title()))
    theme.write_text(s)
    deck = dest / 'modules/deck/DeckView.qml'
    s = deck.read_text().replace('CircularField {', 'InstrumentField {')
    s = s.replace('    MouseArea { anchors.fill: parent; onClicked: Ui.close() }', '''    MouseArea { anchors.fill: parent; onClicked: Ui.close() }
    Instrumentation { anchors.fill: parent; instrument: true }
''')
    s = s.replace('        x: parent.width * .08; y: parent.height - Theme.du(50)', '        x: parent.width * .055; y: parent.height * .84')
    s = s.replace('        text: "AEROLITH   /   LIMB";', '        text: "LIMB / " + Theme.variantName.toUpperCase();')
    deck.write_text(s)
    # Keep bays and their keyboard/service logic unchanged. Increase material
    # solidity so the dense instrument behind never competes with their text.
    token = dest / 'lib/tokens.mjs'
    s = token.read_text().replace('panel: 0.86,', 'panel: 0.97,')
    token.write_text(s)
    (dest / 'README.md').write_text(
        f'# Limb {name.title()} / UI-004\n\n'
        'Complete production-shell snapshot plus visual-only prototype changes.\n'
        f'Run from the repository root with `SHELL_PATH=prototypes/r3-{name}`\n'
        '`AUDIO=1 MEDIA=1 MPV_AO=pipewire CONFIG=prototypes/r3-tools/config.json`\n'
        f'`tools/headless/run.sh prototypes/r3-tools/capture.sh build/r3/{name}-capture`.\n\n'
        'No idle animation loop. Existing strip telemetry drives readouts; no added demand.\n'
        'First-start reveal is latched in Theme for the life of the process; reduced/off/lowEffects skip it.\n'
        'Canvas and QML regenerate from CPU-side properties after unmapping.\n'
        'Fullscreen unmapping remains the systems host\'s responsibility.\n'
        'See `docs/design/round3/VARIANTS.md` and `VALIDATION.md`.\n')
    print(f'Built {dest.relative_to(ROOT)}: {len(snapshot)} production files, level {level}')
