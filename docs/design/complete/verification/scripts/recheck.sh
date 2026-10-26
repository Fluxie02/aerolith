#!/usr/bin/env bash
set -u
for intensity in saturated insane; do
 for scenario in full signal; do
  env CONFIG="build/ui006/$intensity-normal.json" AUDIO=1 MEDIA=1 MPV_AO=pipewire ROUTINES=tests/fixtures/routines.json tools/headless/run.sh "tests/scenarios/$scenario.sh" "build/ui006/$intensity-$scenario-final" >"build/ui006/$intensity-$scenario-final.txt" 2>&1
  echo "$intensity $scenario final exit=$?"
 done
 env CONFIG="build/ui006/$intensity-normal.json" AI=1 AUDIO=1 AI_PROVIDER=codex tools/headless/run.sh tests/scenarios/ai.sh "build/ui006/$intensity-codex-required" >"build/ui006/$intensity-codex-required.txt" 2>&1
 echo "$intensity codex required exit=$?"
done
