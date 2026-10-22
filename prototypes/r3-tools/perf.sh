# shellcheck shell=bash
# Same measurement for production and all variants. No continuously looping
# animation in any variant. Long enough to include 12 slow telemetry samples.
PERF_IDLE_S=60
PERF_OPEN_S=15
source /src/tests/scenarios/perf.sh
