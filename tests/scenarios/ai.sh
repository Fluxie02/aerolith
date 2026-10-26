# shellcheck shell=bash
# AI Bridge scenario with a fake Claude or Codex CLI (AI_PROVIDER).
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
import json, os, sys
call = [json.loads(l) for l in open(sys.argv[1]) if l.strip()][-1]
a = call["argv"]
provider = os.environ.get("AI_PROVIDER", "claude")
if provider == "claude":
    assert a[0] == "-p", a
    assert a[a.index("--tools") + 1] == "", a
    assert a[a.index("--output-format") + 1] == "json", a
    for flag in ("--no-session-persistence", "--strict-mcp-config", "--disable-slash-commands"):
        assert flag in a, a
elif provider == "codex":
    assert a[0] == "exec" and a[-1] == "-", a
    assert a[a.index("--sandbox") + 1] == "read-only", a
    for flag in ("--ephemeral", "--ignore-user-config", "--skip-git-repo-check", "--output-schema"):
        assert flag in a, a
    disabled = [a[i + 1] for i, flag in enumerate(a) if flag == "--disable"]
    assert sorted(disabled) == sorted(("shell_tool", "apps", "plugins", "browser_use", "computer_use", "in_app_browser")), a
    assert a[a.index("-C") + 1] == call["cwd"], a
    assert "--dangerously-bypass-approvals-and-sandbox" not in a, a
else:
    raise AssertionError(f"unsupported scenario provider: {provider}")
assert "aerolith-ai-" in call["cwd"] and not os.path.exists(call["cwd"]), call
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
