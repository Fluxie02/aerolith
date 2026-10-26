# shellcheck shell=bash
# Short final check for Fault after the interrupted queue; uses the existing
# performance scenario unchanged, with its supported duration overrides.
PERF_IDLE_S=20
PERF_OPEN_S=10
source /src/tests/scenarios/perf.sh
