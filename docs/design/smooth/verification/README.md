# UI-016 verification

Verification is in progress. Final source has not been frozen and required final runtime scenarios have not run. This status file is replaced with final measured results when the task completes.

The original UI-013 idle CPU budgets are approximately 2% of one core for Saturated and 4% for Insane. Their reference measurements use 120 seconds of initial idle and 30 seconds each of Systems, Command and idle after use, with software rendering. UI-016 performance/timing measurements are owned by the separate timing harness and run without these verification tests or containers competing for CPU.

Completed preparation checks (before final production changes):

| Command | Exit | Result |
| --- | ---: | --- |
| `node tests/js/run-node.mjs` | 0 | 118 passed, 0 failed |
| `python3 -m pytest -q tests/py` | 0 | 71 passed, 1 skipped |

Exact invocations, output, timestamps and elapsed times are retained under `unit-baseline/`. The reusable driver is `scripts/verify.py`; run its `freeze` action only after root Astra authorizes the final source freeze. It snapshots production without changing production files or existing tools/tests. A THEARS compatibility copy changes only the installation-direction default. Each scenario result records exact command and environment. Retained `qs.txt` files copy the harness's ignored `qs.log` files verbatim.

The single read-only review of Claude-owned systems is in `SYSTEMS-REVIEW.md`. A disposable mid-exit inspection fixture is prepared for the source-backed live motion-disable finding; its run is pending the measurement-exclusive window.
