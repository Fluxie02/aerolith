#!/usr/bin/env bash
set -u
for intensity in saturated insane; do
 for variant in small reduced low; do
  env CONFIG="build/ui006/$intensity-$variant.json" RES=1280x720 HYPR_MOCK=0 ROUTINES=build/ui006/broken-routines.json tools/headless/run.sh build/ui006/sweep.sh "build/ui006/$intensity-$variant" >"build/ui006/$intensity-$variant.txt" 2>&1
  echo "$intensity $variant exit=$?"
 done
 env CONFIG="build/ui006/$intensity-small.json" RES=1280x720 AUDIO=1 MEDIA=1 ROUTINES=tests/fixtures/routines.json tools/headless/run.sh build/ui006/edge-states.sh "build/ui006/$intensity-edges" >"build/ui006/$intensity-edges.txt" 2>&1
 echo "$intensity edges exit=$?"
done
