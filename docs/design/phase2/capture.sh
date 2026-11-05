# shellcheck shell=bash
# Private, deterministic visual evidence. All instrumentation is applied only
# to the disposable container copy. Run through tools/headless/run.sh.
fail() { echo "FAIL: $*"; exit 1; }
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
cp -r "$SHELL_DIR" "$HOME/phase2-shell"
SHELL_DIR="$HOME/phase2-shell"
python3 "$SRC/docs/design/network-tour/fixture.py" "$SHELL_DIR" --behavior
python3 "$SRC/tests/scenarios/tour-probe.py" "$SHELL_DIR"
python3 - "$SHELL_DIR" "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
from pathlib import Path
import json, sys
root = Path(sys.argv[1])
p = root / 'components/Instrumentation.qml'
s = p.read_text().replace('id: rig', 'id: rig\n    objectName: "phase2Rig"', 1)
s = s.replace('T.formatPercent(Telemetry.cpu.total)', '"25%"')
s = s.replace('T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)', '"50%"')
s = s.replace('Telemetry.cpu.cores', '[0, 25, 50, 75]')
s = s.replace('NowPlaying { profile:', 'NowPlaying { objectName: "phase2Media"; profile:')
p.write_text(s)
p = root / 'components/ChordSlot.qml'
p.write_text(p.read_text().replace('id: chord', 'id: chord\n    objectName: \"phase2Chord\"', 1))
p = root / 'modules/deck/DeckView.qml'
p.write_text(p.read_text().replace('id: view', 'id: view\n    objectName: "phase2Deck"', 1))
p = root / 'shell.qml'; s = p.read_text().replace('        Deck {', '        id: phase2DeckLoader\n        Deck {', 1)
s = s.replace('const r = rect(item, surface);', '''const r = rect(item, surface);
                    if (item.objectName === "phase2Rig") { r.compact = item.compact; r.geometry = item.geometry; }
                    if (item.objectName === "workspaceOrbit") r.compact = item.compact;
                    if (item.objectName === "phase2Deck" || item.objectName === "phase2Chord") r.compact = item.compactScreen;
                    if (item.objectName === "groundWindowRegister") { r.contentHeight = item.contentHeight; r.contentY = item.contentY; }''', 1)
s = s.replace('return {output:w.screen.name, profile:w.profile.profile, parts:parts, popup:popup};', 'return {output:w.screen.name, compact:w.compact, profile:w.profile.profile, parts:parts, popup:popup};')
s = s.replace('profile:tourSurface.item.profile.profile, parts:parts, target:', 'profile:tourSurface.item.profile.profile, compact:tourSurface.item.compact, parts:parts, target:')
needle = 'return JSON.stringify({bay: Ui.activeBay,'
s = s.replace(needle, '''let deckParts = []; if (phase2DeckLoader.item && phase2DeckLoader.item.visible) walk(phase2DeckLoader.item.contentItem, phase2DeckLoader.item, deckParts);
            return JSON.stringify({deckParts:deckParts, scale:Theme.scale, unit:Theme.unit, gap:Theme.gap, stripHeight:Theme.stripHeight, stripEdge:Config.strip.edge, bay: Ui.activeBay,''', 1)
s = s.replace('        function picker(output: string, kind: string): void {', '''        function scrollWindows(): void {
            function visit(item) {
                if (!item) return;
                if (item.objectName === "groundWindowRegister") item.contentY = Math.max(0, item.contentHeight - item.height);
                for (const child of item.children || []) visit(child);
            }
            for (const l of groundOutputs.instances) if (l.item) visit(l.item.contentItem);
        }
        function picker(output: string, kind: string): void {''', 1)
p.write_text(s)
p = Path(sys.argv[2]); config = json.loads(p.read_text()) if p.exists() else {}
config.setdefault('theme', {})['motion'] = 'off'
config.setdefault('tour', {})['enabled'] = False
p.write_text(json.dumps(config))
PY
qs -p "$SHELL_DIR" >"$OUT/capture-qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
ready=0
for _ in $(seq 60); do
  if qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/ground.json" 2>/dev/null; then ready=1; break; fi
  sleep .1
done
[ "$ready" = 1 ] || fail 'evidence shell not ready'
sleep 3
qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/ground.json"
shot ground
qs -p "$SHELL_DIR" ipc call visualTest scrollWindows
sleep .2
qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/windows-scrolled.json"
ipc open command
sleep 1
qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/deck.json"
ipc close
sleep .5
qs -p "$SHELL_DIR" ipc call tour start
qs -p "$SHELL_DIR" ipc call tour next
sleep 1
qs -p "$SHELL_DIR" ipc call visualTest snapshot >"$OUT/tour.json"
shot tour-ring
qs -p "$SHELL_DIR" ipc call tour skip
python3 - "$OUT" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1]); s = json.loads((out/'ground.json').read_text())
parts = s['groundTargets'][0]['parts']
rig = next(p for p in parts if p['name'] == 'phase2Rig')
ring = next(p for p in parts if p['name'] == 'workspaceOrbit')
assert rig['compact'] == ring['compact'] == s['strips'][0]['compact'], s
scale = s['scale']; lane = s['stripHeight']; gap = s['gap']
assert rig['compact'] == (rig['w']/scale < 1500 or (rig['h']-lane)/scale < 850)
stations = [p for p in parts if p['name'].startswith('workspaceStation-') or p['name'] == 'workspaceOverflow']
if rig['compact']:
    top = min(p['y'] for p in stations) - round(4*s['unit'])
    bottom = max(p['y']+p['h'] for p in stations) + round(4*s['unit'])
    apps = next(p for p in parts if p['name'] == 'appBar')
    assert top >= (lane if s['stripEdge'] == 'top' else 0) + 2*gap
    assert bottom <= rig['h'] - (lane if s['stripEdge'] == 'bottom' else 0) - 2*gap
    assert bottom <= apps['y'] - 2*gap
if rig['w'] > 2*(rig['h']-lane):
    media = next(p for p in parts if p['name'] == 'phase2Media')
    apps = next(p for p in parts if p['name'] == 'appBar')
    assert media['w'] <= round(420*scale) and apps['w'] <= round(1120*scale)
viewport = next(p for p in parts if p['name'] == 'groundWindowRegister')
if viewport['visible']:
    assert viewport['y']+viewport['h'] <= rig['geometry']['bearings'][1]['y'] - 2*gap + .01
    assert viewport['contentHeight'] > viewport['h'], viewport
scrolled = json.loads((out/'windows-scrolled.json').read_text())
scrolled_view = next(p for p in scrolled['groundTargets'][0]['parts'] if p['name']=='groundWindowRegister')
if viewport['visible']:
    assert abs(scrolled_view['contentY'] - (viewport['contentHeight'] - viewport['h'])) < .5
sdeck = json.loads((out/'deck.json').read_text())
assert next(p for p in sdeck['deckParts'] if p['name'] == 'phase2Deck')['compact'] == rig['compact']
assert all(p['compact'] == rig['compact'] for p in sdeck['deckParts'] if p['name'] == 'phase2Chord')
tour = json.loads((out/'tour.json').read_text())['tour']
assert tour['compact'] == rig['compact']
anchor = next(a['rect'] for o in s['anchors'] for a in o['anchors'] if a['name']=='ring')
for key in ['x','y','width','height']:
    assert abs(tour['target'][key]-anchor[key]) < .5
print('phase2 capture: fit, strip/ground/deck/tour classification and measured ring anchor agree')
PY
alive || fail 'capture shell died'
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/capture-qs.log"; then fail 'QML errors'; fi
