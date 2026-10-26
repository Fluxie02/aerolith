#!/usr/bin/env bash
for intensity in saturated insane; do
 env CONFIG="build/ui006/$intensity-small.json" RES=1280x720 AI=1 AUDIO=1 tools/headless/run.sh build/ui006/ai-states.sh "build/ui006/$intensity-ai-states-verified" >"build/ui006/$intensity-ai-states-verified.txt" 2>&1
 echo "$intensity AI states verified exit=$?"
done
env CONFIG=build/ui006/insane-normal.json AI=1 AUDIO=1 tools/headless/run.sh tests/scenarios/ai.sh build/ui006/insane-ai-verified >build/ui006/insane-ai-verified.txt 2>&1
echo "insane AI required verified exit=$?"
