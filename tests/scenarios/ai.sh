# shellcheck shell=bash
# AI Bridge scenario with a fake Claude or Codex CLI (AI_PROVIDER).
# Needs AI=1 AUDIO=1. Verifies: explicit request, lockdown flags, proposal
# review, approval of one proposal only, and removal of the module at runtime.
fail() { echo "FAIL: $*"; exit 1; }
sleep 3
python3 -c 'import json,sys; s=json.loads(sys.argv[1]); assert s["ai"] is True, s' "$(ipc status)" || fail "AI commands not registered"
[ ! -s "$FAKE_LOG" ] || fail "provider was contacted before any request"

# Type only once the Command Core is mapped (a fixed 0.8 s wait lost the
# keys under load: no request was ever sent), then wait for the answer.
deck_mapped() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("deckMapped"))' "$(ipc status 2>/dev/null)" 2>/dev/null; }
ipc open command >/dev/null
for _ in $(seq 50); do [ "$(deck_mapped)" = True ] && break; sleep 0.1; done
[ "$(deck_mapped)" = True ] || fail "the Command Core did not open"
sleep 0.5
# Injected keys can drop under load (each wtype call uploads a keymap and Qt
# may lose events after it), turning the text into something that is not an
# AI request. Retype until exactly one request is sent; a physical keyboard
# is unaffected and every assertion below stays the same.
sent=0
for attempt in 1 2 3; do
  typ "ai please lower the volume"; sleep 0.5; key Return
  if wait_for_log "request sent to" 4 2>/dev/null; then sent=1; break; fi
  echo "ai: attempt $attempt sent no request (keys dropped); retyping"
  wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace
  sleep 0.3
done
[ "$sent" = 1 ] || fail "no AI request was sent in 3 typing attempts"
[ "$(grep -c "request sent to" "$OUT/qs.log")" = 1 ] || fail "more than one AI request was sent"
wait_for_log "answer received" 10 || fail "no answer to the request"
sleep 0.5
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
# Tab to the proposals and approve the first in one wtype call: one keymap
# upload instead of two, so the pair is not split by a dropped key.
wtype -k Shift_L -k Tab -s 300 -k a
wait_for_log "user approved proposal" 5 || fail "the approval keys were not received"
for _ in $(seq 30); do wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.25" && break; sleep 0.1; done
shot a2-approved
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.25" || fail "approved proposal (volume 25) not applied: $(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
after_ws=$(mock '{"op":"state"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["active_workspace"])')
[ "$before_ws" = "$after_ws" ] || fail "an unapproved proposal ran"
ipc close
for _ in $(seq 30); do [ "$(deck_mapped)" = False ] && break; sleep 0.1; done

# Remove the AI module while the shell runs: commands disappear, core keeps working.
rm -rf "$SHELL_DIR/modules/ai"
ai_on() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("ai"))' "$(ipc status 2>/dev/null)" 2>/dev/null; }
for _ in $(seq 50); do [ "$(ai_on)" = False ] && break; sleep 0.1; done
[ "$(ai_on)" = False ] || fail "AI commands still registered after removal"
# The removal reloads the shell; type only into a mapped Command Core and
# retype if keys dropped (the volume check is unchanged).
ipc open command >/dev/null
for _ in $(seq 50); do [ "$(deck_mapped)" = True ] && break; sleep 0.1; done
[ "$(deck_mapped)" = True ] || fail "the Command Core did not open after AI removal"
sleep 0.5
for attempt in 1 2 3; do
  typ "vol 40"; sleep 0.5; [ "$attempt" = 1 ] && shot a3-after-removal; key Return
  for _ in $(seq 20); do wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" && break; sleep 0.1; done
  wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" && break
  echo "ai: attempt $attempt after removal did not apply (keys dropped); retyping"
  ipc open command >/dev/null; sleep 0.5
  wtype -k Shift_L -M ctrl -k a -m ctrl -k BackSpace
done
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "0.40" || fail "core shell broken after AI removal"
alive || fail "quickshell died"
echo "ai: ok"
