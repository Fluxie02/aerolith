# shellcheck shell=bash
# Same perf.sh measurements with a shorter confirmation window after the
# baseline-length run; no changes to production or the performance harness.
export PERF_IDLE_S=30 PERF_OPEN_S=10
source "$SRC/tests/scenarios/perf.sh"
