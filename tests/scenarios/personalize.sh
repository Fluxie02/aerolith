# shellcheck shell=bash
# Real input, real Config transaction, probes only in a throwaway shell copy.
fail() { echo "FAIL: $*"; exit 1; }
qs -p "$SHELL_DIR" kill
wait "$QS_PID" || true
mv "$OUT/qs.log" "$OUT/startup-qs.log"
cp -r "$SHELL_DIR" "$HOME/personalize-shell"
SHELL_DIR="$HOME/personalize-shell"
python3 - "$SHELL_DIR" "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
from pathlib import Path
import json, sys
root=Path(sys.argv[1]); config=Path(sys.argv[2])
seed=json.loads(config.read_text()) if config.exists() else {}
seed.setdefault('theme',{}).update(scheme='limb',density='standard')
config.write_text(json.dumps(seed))
p=root/'core/Config.qml'
s=p.read_text().replace('    id: root\n','    id: root\n    property int testWrites: 0\n',1)
s=s.replace('        onSaved: {','        onSaved: {\n            root.testWrites++;',1); p.write_text(s)
p=root/'shell.qml'
s=p.read_text().replace('import QtQuick\n','import QtQuick\nimport Quickshell.Io\n',1)
s=s.replace('        active: !!Ui.overlayScreen', '        id: personalizeTestDeck\n        active: !!Ui.overlayScreen',1)
s=s.replace('model: Displays.stripScreens','id: personalizeTestStrips\n        model: Displays.stripScreens',1)
probe='''
    IpcHandler {
        target: "personalizeTest"
        function snapshot(): string {
            const deck = personalizeTestDeck.item;
            const parts = [];
            let editor = null;
            function walk(item) {
                if (!item) return;
                if (item.objectName === "personalizePane") editor = item;
                if (item.objectName) {
                    const point = item.mapToItem(null, 0, 0);
                    parts.push({name:item.objectName, x:point.x, y:point.y, w:item.width, h:item.height,
                        visible:item.visible, enabled:item.enabled, focus:item.focus, activeFocus:item.activeFocus,
                        text:item.text === undefined ? "" : item.text, editing:item.editing === true});
                }
                for (const child of item.children || []) walk(child);
            }
            if (deck) walk(deck.contentItem);
            return JSON.stringify({loaded:Config.loaded, active:Config.previewActive, dirty:Config.previewDirty,
                applying:Config.previewApplying, writes:Config.testWrites, data:Config.data, committed:Config.committedData,
                desktop:editor ? editor.desktop : false, theme:Theme.scheme, density:Theme.cfg.density, signal:String(Theme.signal), parts:parts,
                strips:personalizeTestStrips.instances.map(l => ({output:l.modelData.name,signal:l.item ? String(l.item.profile.signal) : "", profile:l.item ? l.item.profile.profile : "", height:l.item ? l.item.height : 0})),
                output:deck && deck.screen ? deck.screen.name : "HEADLESS-1", focus:deck && deck.contentItem.Window.window && deck.contentItem.Window.window.activeFocusItem ? String(deck.contentItem.Window.window.activeFocusItem) : "", bay:Ui.activeBay, error:Config.previewError});
        }
        function reveal(name: string): void {
            const deck = personalizeTestDeck.item;
            function find(item, name) {
                if (!item) return null;
                if (item.objectName === name && item.visible) return item;
                for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
                return null;
            }
            const item = deck ? find(deck.contentItem, name) : null;
            const scroll = deck ? find(deck.contentItem, "personalizeScroll") : null;
            if (item && scroll) {
                const point = item.mapToItem(scroll.contentItem,0,0);
                // Only reveal descendants of the controls scroll.
                let ancestor = item.parent;
                while (ancestor && ancestor !== scroll.contentItem) ancestor = ancestor.parent;
                if (ancestor) scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, point.y));
            }
        }
        function lockDraft(): void { Ui.locked = true; Ui.locked = false; }
    }
'''
p.write_text(s.replace('    id: shell\n','    id: shell\n'+probe,1))
PY
qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &
QS_PID=$!
PIDS+=("$QS_PID")
probe() { qs -p "$SHELL_DIR" ipc call personalizeTest "$@"; }
# Keep list args safe if future fixtures add batched probe input (config.sh).
b64() { printf %s "$1" | base64 -w0; }
snapshot() { probe snapshot >"$OUT/personalize.json"; }
shot() { local output; output=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["output"])' "$OUT/personalize.json"); grim -o "$output" "$OUT/$1.png"; }
check() {
  for _ in $(seq 80); do
    if snapshot 2>/dev/null && python3 - "$OUT/personalize.json" "$1" <<'PY' 2>"$OUT/check-error.txt"
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2]), {k:s[k] for k in ("bay","active","dirty","desktop","writes","theme","density","error")}
PY
    then return 0; fi
    sleep .1
  done
  cat "$OUT/check-error.txt"
  fail "$1"
}
# Wait for an actual input result before retrying a virtual key. These uses
# are idempotent transitions (open dialog, return, or focus a dialog action).
ui_key() {
  local keyname=$1 expression=$2
  for attempt in 1 2 3; do
    sleep .3
    key "$keyname"
    for poll in 1 2 3 4 5 6; do
      snapshot
      if python3 - "$OUT/personalize.json" "$expression" <<'PYKEY' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert eval(sys.argv[2])
PYKEY
      then return 0; fi
      sleep .2
    done
  done
  fail "key $keyname did not reach: $expression"
}
ui_click() {
  probe reveal "$1"
  sleep .2
  snapshot
  local point cx cy
  point=$(python3 - "$OUT/personalize.json" "$1" "${SCALE:-1}" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); p=next(p for p in s['parts'] if p['name']==sys.argv[2] and p['visible'])
assert p['enabled'],p
scale=float(sys.argv[3]); print(round((p['x']+p['w']/2)*scale),round((p['y']+p['h']/2)*scale))
PY
  ) || fail "No clickable $1"
  read -r cx cy <<<"$point"
  local output
  output=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["output"])' "$OUT/personalize.json")
  swaymsg input type:pointer map_to_output "$output" >/dev/null
  click "$cx" "$cy"
}
section() {
  snapshot
  if python3 - "$OUT/personalize.json" "$1" <<'PY' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert any(p['name']=='personalizeSection_'+sys.argv[2] and p['visible'] for p in s['parts'])
PY
  then ui_click "personalizeSection_$1"; else ui_click "personalizeCompactSection_$1"; fi
}
check 's["loaded"]'
ipc open settings >/dev/null
check 's["active"] and not s["dirty"]'
# Actually traverse the mode switch before editing.
ui_click allSettingsMode
check 'not s["active"] and not any(p["name"]=="personalizePane" and p["visible"] for p in s["parts"])'
ui_click personalizeMode
check 's["active"] and any(p["name"]=="personalizePane" and p["visible"] for p in s["parts"])'
shot 01-personalize
cp "$XDG_CONFIG_HOME/aerolith/config.json" "$OUT/baseline.json"
ui_click scheme_bathyal
check "s['dirty'] and s['theme']=='bathyal' and s['committed']['theme']['scheme']=='limb' and len(s['strips'])==${OUTPUTS:-1} and all(o['signal']==s['signal'] if o['profile']=='standard' else bool(o['signal']) for o in s['strips'])"
ui_key Tab 'any(p["name"]=="personalizeAdvanced" and p["focus"] for p in s["parts"])'
check 'all(a["y"] >= v["y"]-1 and a["y"]+a["h"] <= v["y"]+v["h"]+1 for a in s["parts"] if a["name"]=="personalizeAdvanced" and a["visible"] for v in s["parts"] if v["name"]=="personalizeScroll" and v["visible"])'
section 1
ui_click personalizeField_theme.density
key Right
check 's["density"]=="comfortable" and s["writes"]==0 and all(o["height"]==s["strips"][0]["height"] for o in s["strips"])'
cmp "$OUT/baseline.json" "$XDG_CONFIG_HOME/aerolith/config.json" || fail 'preview wrote disk'
ui_click personalizeCancel
check 's["theme"]=="limb" and s["density"]=="standard" and not s["dirty"] and s["writes"]==0'
# The named-output profile picker stages a structured map path, then rolls back.
section 4
output_target=HEADLESS-1
[ "${OUTPUTS:-1}" = 2 ] && output_target=HEADLESS-2
ui_click "personalizeOutput_$output_target"
snapshot
original_profile=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["data"]["display"]["outputs"].get(sys.argv[2],{}).get("profile","standard"))' "$OUT/personalize.json" "$output_target")
expected_profile=oled
[ "$original_profile" = oled ] && expected_profile=standard
ui_click "personalizeField_display_outputs_${output_target}_profile"
key Right
check "s['data']['display']['outputs']['$output_target']['profile']=='$expected_profile' and s['writes']==0"
ui_click personalizeCancel
check "s['data']['display']['outputs'].get('$output_target',{}).get('profile','standard')=='$original_profile' and s['writes']==0"
section 1
# Escape cancels a font field before it can leave Personalize.
ui_click personalizeField_theme.fontSans
ui_key Return 'any(p["name"]=="personalizeField_theme.fontSans" and p["editing"] for p in s["parts"])'
# Like network.sh's text entry: keep select/clear/type in one keyboard
# invocation, and retype only through the real field if injection was lost.
for attempt in 1 2 3; do
  sleep .3
  wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace -- 'Noto Sans'
  sleep .3
  snapshot
  if python3 - "$OUT/personalize.json" <<'PYFONT' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert any(p['name']=='personalizeEditor_theme.fontSans' and p['text']=='Noto Sans' for p in s['parts'])
PYFONT
  then break; fi
done
check 'any(p["name"]=="personalizeEditor_theme.fontSans" and p["text"]=="Noto Sans" for p in s["parts"])'
ui_key Escape 'not any(p["name"]=="personalizeField_theme.fontSans" and p["editing"] for p in s["parts"])'
check 's["data"]["theme"]["fontSans"]=="Inter" and not any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
section 0
ui_click scheme_iris
section 1
ui_click personalizeField_theme.density
key Right
check 's["theme"]=="iris" and s["density"]=="comfortable"'
ui_click personalizeApply
check 'not s["active"] and not s["applying"] and s["writes"]==1 and s["theme"]=="iris"'
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); assert s['theme']['scheme']=='iris' and s['theme']['density']=='comfortable',s
PY
# A real hex entry is rejected without changing the last safe draft.
# The one-shot recovery exists only while a scale/visibility draft is active.
section 1
ui_click personalizeField_theme.uiScale
key Right
check 's["active"] and s["data"]["theme"]["uiScale"]==1.05 and any(p["name"]=="personalizeKeepPreview" and p["visible"] for p in s["parts"])'
sleep 21
check 's["data"]["theme"]["uiScale"]==1 and s["writes"]==1 and not any(p["name"]=="personalizeKeepPreview" and p["visible"] for p in s["parts"])'
ui_click personalizeCancel
section 0
ui_click personalizeAdvanced
ui_click paletteHex_text
# Keep text and Enter in one virtual keyboard lifetime. A refused edit is
# idempotent; retrying through the field never queues a save.
for attempt in 1 2 3; do
  sleep .4
  wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace '#222222' -k Return
  sleep .4
  snapshot
  if python3 - "$OUT/personalize.json" <<'PYHEX' 2>/dev/null
import json,sys
s=json.load(open(sys.argv[1])); assert any('requires 4.5:1' in p['text'] for p in s['parts'] if p['name']=='personalizeFeedback')
PYHEX
  then break; fi
done
check 'any("text on" in p["text"] and ":1" in p["text"] and "requires 4.5:1" in p["text"] for p in s["parts"] if p["name"]=="personalizeFeedback") and "text" not in s["data"]["theme"]["palette"]'
shot 02-contrast-refusal
key Escape
ui_click personalizeCancel
# Dirty leave offers all three actions; Keep editing retains the draft.
section 1
ui_click personalizeField_theme.density
key Right
check 's["dirty"] and s["density"]=="compact"'
ui_key Escape 'any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
check 'any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"]) and s["dirty"]'
shot 03-dirty-leave
check 'any(p["name"]=="personalizeKeepEditing" and p["focus"] for p in s["parts"])'
ui_key Tab 'any(p["name"]=="personalizeLeaveApply" and p["focus"] for p in s["parts"])'
check 'any(p["name"]=="personalizeLeaveApply" and p["focus"] for p in s["parts"])'
ui_click personalizeKeepEditing
check 's["dirty"] and not any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
# View desktop exposes the real shell under a fixed recovery bar.
ui_click personalizeDesktop
check 's["desktop"]'
sleep .5
shot 04-view-desktop
click 100 100
check 's["desktop"] and s["dirty"] and s["writes"]==1'
ui_key Escape 'not s["desktop"]'
sleep .5
snapshot
# Return via the bar restores editor focus. No preview writes.
check 's["dirty"] and s["writes"]==1 and not s["desktop"]'
# Lock never persists the draft.
probe lockDraft
check 'not s["active"] and not s["dirty"] and s["theme"]=="iris" and s["writes"]==1'
# Dirty mode switches exercise Discard and asynchronous Apply-on-leave too.
section 1
ui_click personalizeField_theme.density
key Right
check 's["dirty"]'
ui_click allSettingsMode
check 'any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
ui_click personalizeLeaveDiscard
check 'not s["active"] and s["density"]=="comfortable" and s["writes"]==1 and not any(p["name"]=="personalizePane" and p["visible"] for p in s["parts"])'
ui_click personalizeMode
section 1
ui_click personalizeField_theme.density
key Right
check 's["dirty"] and s["density"]=="compact"'
ui_click allSettingsMode
check 'any(p["name"]=="personalizeLeaveDialog" and p["visible"] for p in s["parts"])'
ui_click personalizeLeaveApply
check 'not s["active"] and not s["applying"] and s["density"]=="compact" and s["writes"]==2 and not any(p["name"]=="personalizePane" and p["visible"] for p in s["parts"])'
ipc close >/dev/null
sleep .3
alive || fail 'quickshell died'
if grep -En 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot read|Binding loop|Unable to assign|Cannot assign|is not a type|Type .* unavailable|Error loading QML' "$OUT/qs.log" "$OUT/startup-qs.log"; then fail 'QML errors'; fi
echo 'personalize: ok (real input, all-output preview, Cancel, one-write Apply, contrast refusal, dirty leave, View desktop, lock discard)'
