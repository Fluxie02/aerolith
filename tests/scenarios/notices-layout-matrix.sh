#!/usr/bin/env bash
# D03 visual geometry regression. Disposable shell copies add an IPC probe;
# production hosts/services need no diagnostic state or lifecycle changes.
# Usage: tests/scenarios/notices-layout-matrix.sh [output-dir] [cells...]
# Cell: direction-intensity-size-motion-edge (size: 1080, 720, 720large).
# D03_AI=1 includes the installed AI console and its extra rail tab.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo"
out=${1:-build/headless/D03-layout}
[ "$#" = 0 ] || shift
mkdir -p "$out"
out=$(realpath "$out")
case "$out/" in "$repo/build/"*) ;; *) echo 'output must be inside repository build/' >&2; exit 2 ;; esac
scratch=$(mktemp -d "$repo/build/d03-shell.XXXXXX")
chmod 755 "$scratch"
trap 'rm -rf -- "$scratch"' EXIT
if [ "$#" = 0 ]; then
  for direction in piyti thears; do
    for intensity in saturated insane; do
      for size in 1080 720 720large; do
        set -- "$@" "$direction-$intensity-$size-full-top"
      done
    done
  done
  set -- "$@" piyti-insane-720large-reduced-bottom piyti-saturated-720-off-top thears-insane-720large-lowEffects-bottom
fi
for cell in "$@"; do
  IFS=- read -r direction intensity size motion edge <<<"$cell"
  case "$size" in
    1080) res=1920x1080; scale=1 ;;
    720) res=1280x720; scale=1.25 ;;
    720large) res=1280x720; scale=1.5 ;;
    *) echo "unknown size: $size" >&2; exit 2 ;;
  esac
  cp -a "${D03_SHELL_SOURCE:-shell}" "$scratch/$cell"
  python3 - "$scratch/$cell" "$direction" "$intensity" "$scale" "$motion" "$edge" "$out/$cell.json" <<'PY'
import json, sys
from pathlib import Path
shell, direction, intensity, scale, motion, edge, config = sys.argv[1:]
p = Path(shell) / 'core/Theme.qml'
s = p.read_text()
old = 'property string applicationDirection: "piyti"'
assert s.count(old) == 1, 'inspect installation-only direction seam'
p.write_text(s.replace(old, 'property string applicationDirection: "' + direction + '"'))
cfg = json.loads(Path('tests/fixtures/notify-config.json').read_text())
cfg['theme'] = dict(intensity=intensity, uiScale=float(scale),
                    motion='full' if motion == 'lowEffects' else motion,
                    lowEffects=motion == 'lowEffects')
cfg['strip'] = dict(edge=edge)
Path(config).write_text(json.dumps(cfg, indent=2) + '\n')

# The probe reads actual view geometry, including the old layout. Inject only
# into the disposable copy; keep diagnostics out of production QML and IPC.
p = Path(shell) / 'modules/deck/DeckView.qml'
s = p.read_text().replace('import QtQuick', 'import Quickshell.Io\nimport QtQuick', 1)
probe = r'''
    IpcHandler {
        target: "d03-layout"
        function snapshot(): string {
            function bounds(item) {
                var a = item.mapToItem(view, 0, 0);
                return {x:a.x, y:a.y, width:item.width, height:item.height};
            }
            var notice = null;
            for (var i = 0; i < view.children.length; i++) {
                var child = view.children[i];
                if (child.hasContent !== undefined && child.notices !== undefined)
                    notice = child;
            }
            if (!notice) return JSON.stringify({error:"NoticeStack missing"});
            var cards = [], scroll = null;
            function visit(item) {
                if (item.message !== undefined && item.severity !== undefined)
                    cards.push(bounds(item));
                if (item.contentY !== undefined && item.contentHeight !== undefined)
                    scroll = item;
                for (var j = 0; j < item.children.length; j++) visit(item.children[j]);
            }
            visit(notice);
            var bays = [];
            if (frameA.visible) bays.push(bounds(frameA));
            if (frameB.visible) bays.push(bounds(frameB));
            return JSON.stringify({bay:Ui.activeBay, direction:Theme.applicationDirection,
                intensity:Theme.intensity, scale:Theme.scale, motion:Config.theme.motion,
                lowEffects:Theme.lowEffects, stripEdge:Config.strip.edge,
                screen:{width:view.width, height:view.height}, rail:bounds(railRow),
                notices:bounds(notice), cards:cards, bays:bays,
                scroll:scroll ? {height:scroll.height, contentHeight:scroll.contentHeight,
                    contentY:scroll.contentY, interactive:scroll.interactive} : null});
        }
        function scrollToEnd(): void {
            function visit(item) {
                if (item.contentY !== undefined && item.contentHeight !== undefined)
                    item.contentY = Math.max(0, item.contentHeight - item.height);
                for (var j = 0; j < item.children.length; j++) visit(item.children[j]);
            }
            for (var i = 0; i < view.children.length; i++)
                if (view.children[i].hasContent !== undefined) visit(view.children[i]);
        }
    }
'''
p.write_text(s.rstrip()[:-1] + probe + '\n}\n')

p = Path(shell) / 'modules/notices/NoticeColumn.qml'
s = p.read_text().replace('import QtQuick', 'import Quickshell.Io\nimport QtQuick', 1)
probe = r'''
    IpcHandler {
        target: "d03-column"
        function snapshot(): string {
            return JSON.stringify({visible:column.visible, width:column.width,
                height:column.height, screenHeight:Ui.screen.height,
                availableHeight:Ui.screen.height - Theme.stripHeight - 2 * Theme.pad});
        }
    }
'''
p.write_text(s.rstrip()[:-1] + probe + '\n}\n')
PY
  echo "D03: $cell"
  CONFIG="$out/$cell.json" SHELL_PATH="${scratch#"$repo/"}/$cell" RES="$res" \
    AUDIO=1 MEDIA=0 AI="${D03_AI:-0}" INSTALL= PKGS= HYPR_MOCK_ARGS="--mode $res" \
    tools/headless/run.sh tests/scenarios/notices-layout.sh "$out/$cell" \
    >"$out/$cell-result.txt" 2>&1 || { cat "$out/$cell-result.txt"; exit 1; }
  cat "$out/$cell-result.txt"
done
