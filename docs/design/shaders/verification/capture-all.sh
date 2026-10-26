#!/usr/bin/env bash
# Reproduce native fallback stills/event frames. Requires aerolith-dev.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
cd "$repo"
root=build/E01
mkdir -p "$root/base"
git archive 9b60683e5b23779edf66741ccadbe11d4daf79dd shell | tar -x -C "$root/base"
cp docs/design/shaders/verification/capture.sh "$root/capture.sh"
python3 - <<'PY'
from pathlib import Path
import shutil,json
root=Path('build/E01')
for direction in ['piyti','thears']:
 for intensity in ['saturated','insane']:
  name=f'{direction}-{intensity}'
  (root/f'{name}.json').write_text(json.dumps({'schemaVersion':1,'theme':{'intensity':intensity,'motion':'full'}}))
  for phase,source in [('before',root/'base/shell'),('after',Path('shell'))]:
   target=root/'visual-shells'/f'{phase}-{name}'
   shutil.copytree(source,target,dirs_exist_ok=True)
   p=target/'core/Theme.qml'
   s=p.read_text().replace('property string applicationDirection: Config.applicationDirection',f'property string applicationDirection: "{direction}"')
   p.write_text(s)
PY
for profile in piyti-saturated piyti-insane thears-saturated thears-insane; do
  for phase in before after; do
    AUDIO=1 CONFIG="$root/$profile.json" SHELL_PATH="$root/visual-shells/$phase-$profile" \
      tools/headless/run.sh "$root/capture.sh" "$root/captures/$phase-$profile" \
      > "$root/capture-$phase-$profile.txt" 2>&1
  done
done
