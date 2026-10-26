# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
ipc open ai; sleep 1; shot c0-ready
[ ! -s "$FAKE_LOG" ] || fail "provider contacted before send"
typ 'please pause the music'; key Return; sleep 3
wait_for_log 'answer received (1 proposals)' 5 || fail 'no Codex reply'
shot c1-answer
python3 - "$FAKE_LOG" <<'PY'
import json,sys
c=json.loads(open(sys.argv[1]).readlines()[-1]); a=c['argv']
assert a[0]=='exec' and a[a.index('--sandbox')+1]=='read-only'
assert '--ephemeral' in a and '--disable' in a
assert 'please pause the music' in c['stdin'] and 'please pause the music' not in ' '.join(a)
assert 'DESKTOP CONTEXT' not in c['stdin']
PY
before=$(playerctl -p mpv status)
key Tab; key d; sleep .4; shot c2-dismissed
[ "$(playerctl -p mpv status)" = "$before" ] || fail 'dismiss ran action'
ipc close; ipc open ai; sleep .8
typ 'pause now'; key Return; sleep 3; key Tab; key a; sleep 2
[ "$(playerctl -p mpv status)" = Paused ] || fail 'approval did not pause'
shot c3-approved
alive || fail 'quickshell died'
echo 'codex-console: ok'
