# AI Bridge scenario with a fake Claude CLI (tests/fixtures/fake-providers).
# Needs AI=1 AUDIO=1. Verifies: explicit request, lockdown flags, proposal
# review, approval of one proposal only, and removal of the module at runtime.
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
python3 -c 'import json,sys; s=json.loads(sys.argv[1]); assert s["ai"] is True, s' "$(ipc status)" || fail "AI commands not registered"
[ ! -s "$FAKE_LOG" ] || fail "provider was contacted before any request"

ipc open command; sleep 0.8
typ "ai please lower the volume"; sleep 0.5; key Return; sleep 3
shot a1-answer
grep -q "answer received (2 proposals)" "$OUT/qs.log" || fail "no answer with 2 proposals"
python3 - "$FAKE_LOG" <<'PY' || fail "provider invocation not locked down"
import json, sys
call = [json.loads(l) for l in open(sys.argv[1]) if l.strip()][-1]
a = call["argv"]
assert a[a.index("--tools") + 1] == "", a
assert "please lower the volume" in call["stdin"] and "please lower the volume" not in " ".join(a)
assert "DESKTOP CONTEXT" not in call["stdin"], "context must be off by default"
PY

before_ws=$(mock '{"op":"state"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["active_workspace"])')
key Tab; sleep 0.3; key a; sleep 2
shot a2-approved
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.25" || fail "approved proposal (volume 25) not applied: $(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
after_ws=$(mock '{"op":"state"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["active_workspace"])')
[ "$before_ws" = "$after_ws" ] || fail "an unapproved proposal ran"
ipc close; sleep 0.5

# Remove the AI module while the shell runs: commands disappear, core keeps working.
rm -rf "$SHELL_DIR/modules/ai"; sleep 2
python3 -c 'import json,sys; s=json.loads(sys.argv[1]); assert s["ai"] is False, s' "$(ipc status)" || fail "AI commands still registered after removal"
ipc open command; sleep 0.8; typ "vol 40"; sleep 0.5; shot a3-after-removal; key Return; sleep 1.5
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" || fail "core shell broken after AI removal"
alive || fail "quickshell died"
echo "ai: ok"
