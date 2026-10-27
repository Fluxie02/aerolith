# Visual stand-in for the shared scratch contract, not a systems integration test.
source "$SRC/docs/design/redesign-2/scripts/helpers.sh"
start_visual_fixture
capture_state closed-empty
click_hatch
expect_open true
capture_state open-empty
click_hatch
expect_open false
probe contents parked >/dev/null
capture_state closed-parked
click_hatch
expect_open true
capture_state open-parked
click_hatch
expect_open false
capture_state closed-again

for motion in reduced off; do
  probe theme motion "$motion" >/dev/null
  click_hatch
  expect_open true
  capture_state "$motion-open"
  click_hatch
  expect_open false
  capture_state "$motion-closed"
done
python3 - "$OUT" <<'PY'
import json, sys
from pathlib import Path
out = Path(sys.argv[1])
for motion in ['reduced', 'off']:
    opened = json.loads((out / f'{motion}-open.json').read_text())
    closed = json.loads((out / f'{motion}-closed.json').read_text())
    assert not opened['motion'] and not closed['motion'], (opened, closed)
    assert opened['policy'] == closed['policy'] == motion, (opened, closed)
    assert opened['leftX'] < 0 < opened['rightX'], opened
    assert closed['leftX'] == 0, closed
final = json.loads((out / 'closed-again.json').read_text())
assert final['count'] == 4 and final['toggles'] == 4, final
PY
audit_visual_logs
echo 'hatch visuals: ok (empty, parked, click delivery, open/close, reduced/off)'
