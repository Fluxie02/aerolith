#!/usr/bin/env bash
set -euo pipefail
for intensity in saturated insane; do
 SHELL_PATH=build/ui009/verified-shell CONFIG=build/ui009/$intensity-full.json AUDIO=1 MEDIA=1 tools/headless/run.sh tests/scenarios/perf.sh "build/ui009/verified-$intensity-perf" > "build/ui009/verified-$intensity-perf-result.txt" 2>&1
 echo "$intensity perf: passed"
done
