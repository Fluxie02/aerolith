#!/usr/bin/env bash
# Host-side B05 runner. Output stays in the checkout; no installation or
# product edits. Usage: tests/scenarios/fullscreen-matrix.sh [build/B05/matrix]
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo"
out=${1:-build/B05/matrix}
mkdir -p "$out"
out=$(realpath "$out")
case "$out/" in "$repo/"*) ;; *) echo "output must be inside the repository" >&2; exit 2 ;; esac
scratch=$(mktemp -d "$repo/build/b05-shell.XXXXXX")
# The container's unprivileged pilot user must traverse the disposable copy.
chmod 755 "$scratch"
trap 'rm -rf -- "$scratch"' EXIT
cp -a shell "$scratch/thears"
python3 - "$scratch/thears/core/Theme.qml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'property string applicationDirection: "piyti"'
assert s.count(old) == 1, 'installation-only direction seam changed; inspect Theme.qml'
p.write_text(s.replace(old, 'property string applicationDirection: "thears"'))
PY
git rev-parse HEAD >"$out/commit.txt"
printf 'direction\tintensity\texit\trss_1_kib\trss_10_kib\trss_20_kib\n' >"$out/results.tsv"
failed=0
for direction in piyti thears; do
  shell_path=shell
  [ "$direction" = thears ] && shell_path=${scratch#"$repo/"}/thears
  for intensity in saturated insane; do
    cell=$direction-$intensity
    config="$out/$cell.json"
    python3 - "$intensity" "$config" <<'PY'
import json, sys
from pathlib import Path
cfg = json.loads(Path('tests/fixtures/notify-config.json').read_text())
cfg['theme'] = {'intensity': sys.argv[1]}
cfg['navigator'] = {'thumbnails': True}
Path(sys.argv[2]).write_text(json.dumps(cfg, indent=2) + '\n')
PY
    echo "B05: $cell (20 cycles, notifications, open bays, thumbnails, focus)"
    result=0
    CONFIG="$config" SHELL_PATH="$shell_path" AUDIO=1 HYPR_MOCK=1 \
      MEDIA=0 AI=0 INSTALL= PKGS= \
      tools/headless/run.sh tests/scenarios/fullscreen.sh "$out/$cell" \
      >"$out/$cell.log" 2>&1 || result=$?
    python3 - "$out/results.tsv" "$out/$cell/rss-summary.json" "$direction" "$intensity" "$result" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[2])
rss = json.loads(p.read_text())['rss_kib'] if p.exists() else {}
with open(sys.argv[1], 'a') as f:
    f.write('\t'.join([*sys.argv[3:6], *(str(rss.get(str(n), 'unavailable')) for n in (1, 10, 20))]) + '\n')
PY
    if [ "$result" != 0 ]; then
      echo "B05: $cell failed (exit $result); see $out/$cell.log"
      failed=1
      # B05 explicitly stops on lifecycle failures for Opus to review.
      break 2
    fi
  done
done
cat "$out/results.tsv"
exit "$failed"
