# shellcheck shell=bash
# Sourced by session.sh. Use notices-layout-matrix.sh to add the test-only probe.
fail() { echo "FAIL: $*"; exit 1; }
column_geometry() { qs -p "$SHELL_DIR" ipc call d03-column snapshot >>"$OUT/column-geometry.jsonl"; }
geometry() {
  qs -p "$SHELL_DIR" ipc call d03-layout snapshot >>"$OUT/geometry.jsonl"
  column_geometry
}
popup() {
  python3 "$SRC/tools/headless/notify_client.py" --summary "Build finished <b>plain text</b>" \
    --body "D03 / popup $1. Readable beside every bay, with no covered controls." --wait 0.1 \
    >>"$OUT/notify-client.txt" 2>>"$OUT/notify-client.log"
}
sleep 3
# Order reproduces the reported Help/Settings collision first.
for bay in help settings command navigator systems signal routines ai; do
  popup "$bay"
  ipc run audio.volume.set '{"level":42}' >/dev/null
  ipc open "$bay" >/dev/null
  sleep 0.08
  geometry
  sleep 0.4
  geometry
  case "$bay" in help|settings) shot "$bay" ;; esac
done

# Start clean, then fill both service caps (3 popups + 5 shell notices).
ipc close
sleep 5.5
ipc open settings >/dev/null
for n in 1 2 3; do popup "$n"; done
for n in 1 2 3 4 5; do
  ipc run shell.notify "{\"message\":\"Notice $n / distinct, ordered, bounded\"}" >/dev/null
done
sleep 0.2
geometry
shot multiple
qs -p "$SHELL_DIR" ipc call d03-layout scrollToEnd
sleep 0.15
geometry
shot multiple-scrolled
ipc close
sleep 0.3
shot standalone
qs -p "$SHELL_DIR" ipc call d03-column snapshot >"$OUT/standalone-geometry.json"
ipc open help >/dev/null
sleep 0.1
geometry
ipc close
sleep 0.1
ipc open settings >/dev/null
sleep 0.1
geometry
alive || fail 'quickshell died'

python3 - "$OUT" <<'PY'
import json, sys
from pathlib import Path
out = Path(sys.argv[1])
rows = [json.loads(s) for s in (out / 'geometry.jsonl').read_text().splitlines() if s.strip()]
assert len(rows) == 20, f'incomplete geometry evidence: {len(rows)} snapshots'
def intersects(a, b):
    return (min(a['x']+a['width'], b['x']+b['width']) > max(a['x'], b['x']) + 1
        and min(a['y']+a['height'], b['y']+b['height']) > max(a['y'], b['y']) + 1)
for i, r in enumerate(rows):
    assert 'error' not in r, r
    n, screen = r['notices'], r['screen']
    assert r['cards'], f'{i}: no cards; this would not test the overlap'
    assert n['width'] > 200 * r['scale'], f'{i}: unreadably narrow notice lane'
    assert n['x'] >= 0 and n['y'] >= 0, f'{i}: notice off screen'
    assert n['x']+n['width'] <= screen['width']+1, f'{i}: notice outside output width'
    assert n['y']+n['height'] <= screen['height']+1, f'{i}: stack outside output height'
    assert not intersects(n, r['rail']), f"{i} {r['bay']}: notices overlap rail: {n} / {r['rail']}"
    for bay in r['bays']:
        assert not intersects(n, bay), f"{i} {r['bay']}: notices overlap bay controls: {n} / {bay}"
    cards = sorted(r['cards'], key=lambda c:c['y'])
    for a, b in zip(cards, cards[1:]):
        assert a['y']+a['height'] <= b['y']+1, f'{i}: cards overlap each other'
assert len(rows[16]['cards']) == 8, 'both service caps must be represented'
scroll = rows[17]['scroll']
assert scroll, 'bounded viewport missing'
if scroll['contentHeight'] > scroll['height']:
    assert scroll['interactive'], 'overflow must remain scrollable'
    assert scroll['contentY'] > 0, 'overflow test must reach the last cards'
    assert abs(scroll['contentY'] - (scroll['contentHeight'] - scroll['height'])) <= 1, 'last card inaccessible'
elif rows[17]['screen']['height'] == 720:
    raise AssertionError('compact fixture must exercise overflow')
columns = [json.loads(s) for s in (out / 'column-geometry.jsonl').read_text().splitlines() if s.strip()]
assert len(columns) == len(rows) and all(not c['visible'] for c in columns), 'two notice surfaces visible with Deck mapped'
standalone = json.loads((out / 'standalone-geometry.json').read_text())
assert standalone['visible'], 'standalone column did not restore after closing Deck'
assert 0 < standalone['height'] <= standalone['availableHeight'] + 1, 'standalone stack extends outside usable output'
print(f'notices-layout: ok ({len(rows)} geometry snapshots, all 8 bays, 8 cards, overflow and reopen)')
PY
if grep -nEi 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log"; then
  fail 'QML errors in qs.log'
fi
