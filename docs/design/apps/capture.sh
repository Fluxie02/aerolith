# UI-010 scenario sourced by tools/headless/session.sh. No host installation.
sleep 3
export QT_QPA_PLATFORM=wayland
swaymsg 'client.focused #ceebac #1b282b #edf3f5 #ceebac #ceebac' > "$OUT/decoration.json"
swaymsg 'for_window [app_id="aerolith-palette-preview"] floating enable' > "$OUT/placement.json"

preview() {
  local stage=$1 shot_name=$2
  AEROLITH_PREVIEW_STAGE="$stage" /src/build/ui010/palette-preview \
    /src/themes/qt/aerolith.conf /src/themes/qt/aerolith.qss "$OUT/palette.json" \
    > "$OUT/preview-$stage.log" 2>&1 &
  local preview_pid=$!
  PIDS+=("$preview_pid")
  # Rendering states are fixture-controlled. These are not keyboard test claims.
  for attempt in $(seq 50); do
    swaymsg -t get_tree > "$OUT/mapping-$stage.json"
    if python3 - "$OUT/mapping-$stage.json" <<'PY'
import json,sys

def mapped(node):
    return node.get('app_id') == 'aerolith-palette-preview' or any(mapped(child) for key in ('nodes','floating_nodes') for child in node.get(key, []))

sys.exit(0 if mapped(json.load(open(sys.argv[1]))) else 1)
PY
    then break; fi
    sleep .2
  done
  swaymsg '[app_id="aerolith-palette-preview"] resize set width 850 height 680' > "$OUT/size-$stage.json"
  swaymsg '[app_id="aerolith-palette-preview"] move position 950 185' > "$OUT/position-$stage.json"
  swaymsg '[app_id="aerolith-palette-preview"] focus' > "$OUT/focus-$stage.json"
  sleep 2
  kill -0 "$preview_pid"
  swaymsg -t get_tree > "$OUT/tree-$stage.json"
  shot "$shot_name"
  kill "$preview_pid"
  wait "$preview_pid" || true
  sleep .5
}

preview controls 01-qt-palette-with-shell
preview selection 02-qt-entry-selection
preview files 03-qt-file-picker
alive
echo 'UI-010 preview: ok (Qt 6 Fusion, QSS, fixture-controlled focus/selection/file picker)'
