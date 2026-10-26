# shellcheck shell=bash
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
# A writable fake CLI changes only fixture responses, never source/service code.
python3 - "$HOME/.local/bin/claude" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]);s=p.read_text()
s=s.replace('mode = os.environ.get("FAKE_MODE", "ok")','mode = open(os.path.expanduser("~/ai-mode")).read().strip()')
s=s.replace('envelope = {"reply":', 'envelope = {"reply":',1)
a=s.index('envelope = ');b=s.index('\nprint(json.dumps',a)
s=s[:a]+'''envelope = {"reply": "<b>Literal model output</b> & <img src=x>\\n" + "A detailed response stays in the response register. " * 45, "proposals": [
 {"action":"audio.volume.set","argsJson":"{\\"level\\":25}","reason":"<b>Literal proposal</b> & review each action separately."} for _ in range(5)]}'''+s[b:]
p.write_text(s)
PY
echo slow >"$HOME/ai-mode"
ipc open ai; sleep .7; shot q0-ready
typ 'slow request'; sleep .3; key Return; sleep 1.2; shot q1-busy
key Escape; sleep 1; shot q2-cancelled
echo ok >"$HOME/ai-mode"
ipc close; ipc open ai; sleep .7; typ 'long reply'; sleep .3; key Return; sleep 3
wait_for_log 'answer received (5 proposals)' 5 || fail 'long response missing'
shot q3-long-literal
key Tab
for i in $(seq 4); do key Down; done
sleep .3; shot q4-last-proposal
key d; sleep .3; shot q5-dismissed
# Errors use the same register with a visible fault code and recovery copy.
echo noauth >"$HOME/ai-mode"
key Tab; sleep .2; ipc close; sleep .4; ipc open ai; sleep 1; typ 'authentication test'; sleep .5; key Return; sleep 3
wait_for_log 'request failed: not_authenticated' 5 || fail 'authentication fault was not exercised'
shot q6-auth-fault
alive || fail 'quickshell died'
echo 'ai-states: ok'
