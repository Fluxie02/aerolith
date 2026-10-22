# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
# Exercise the actual terminal entry point, including its atomic config write.
PYTHONPATH="$SRC/installer" python3 -m aerolith_install intensity insane
sleep .4; shot 01-terminal-insane
PYTHONPATH="$SRC/installer" python3 -m aerolith_install intensity saturated
sleep .4; shot 02-terminal-saturated
# Compact layout, fallback fonts, motion off and opaque effects.
python3 - "$XDG_CONFIG_HOME/aerolith/config.json" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);s=json.loads(p.read_text());s['theme'].update(uiScale=1.25,density='compact',fontSans='Noto Sans',fontMono='Noto Sans Mono',motion='off',lowEffects=True);p.write_text(json.dumps(s)+'\n')
PY
swaymsg output HEADLESS-1 mode 1280x720 >/dev/null
sleep .6; shot 03-small-saturated
ipc open command; sleep .5; shot 04-small-saturated-command
ipc run settings.intensity '{"intensity":"insane"}'
sleep .4; shot 05-small-insane-command
ipc close; sleep .3; shot 06-small-insane
alive || fail 'quickshell died'
echo 'terminal-small: ok'
