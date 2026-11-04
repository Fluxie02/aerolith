# Real rendered transition samples; no changes to production animation timing.
source "$SRC/docs/design/redesign-2/scripts/helpers.sh"
start_visual_fixture
probe contents parked >/dev/null
capture_state closed
probe trigger >"$OUT/trigger-open.json"
for frame in 1 2 3 4 5; do
  shot "opening-$frame"
done
expect_open true
capture_state open
probe trigger >"$OUT/trigger-close.json"
for frame in 1 2 3 4 5; do
  shot "closing-$frame"
done
expect_open false
capture_state closed-again
audit_visual_logs
echo 'hatch motion capture: ok (judge actual pixels with scripts/motion.py on the host)'
