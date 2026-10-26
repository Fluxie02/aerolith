"""AI Bridge tests (mock providers; see conftest.py)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from aerolith_ai import config as aicfg
from aerolith_ai.__main__ import ask, status
from aerolith_ai.proposals import parse_output
from aerolith_ai.providers import CODEX_DISABLED_FEATURES
from conftest import ROOT, read_log, write_exe

CATALOGUE = [
    {"id": "audio.volume.set", "title": "Set volume", "params": [{"name": "level", "type": "int", "min": 0, "max": 150, "required": True}]},
    {"id": "workspace.focus", "title": "Go to workspace", "params": [{"name": "workspace", "type": "int", "required": True}]},
    {"id": "media.play-pause", "title": "Play / pause", "params": []},
]


def write_ai(home: Path, **over) -> Path:
    data = {"schemaVersion": 1, "provider": "claude", "enabled": True, "timeoutSeconds": 30}
    data.update(over)
    p = home / ".config" / "aerolith" / "ai.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data))
    return p


def request(prompt="lower the volume", context=None) -> str:
    return json.dumps({"version": 1, "prompt": prompt, "actions": CATALOGUE, "context": context or {}})


# --- configuration -----------------------------------------------------------

def test_config_rejects_unknown_provider():
    with pytest.raises(aicfg.ConfigError, match="provider must be one of"):
        aicfg.parse({"provider": "skynet"})


def test_config_refuses_credentials_in_file():
    with pytest.raises(aicfg.ConfigError, match="must not contain credentials"):
        aicfg.parse({"provider": "claude", "claude": {"executable": "/x", "apiKey": "sk-123"}})
    with pytest.raises(aicfg.ConfigError, match="credentials"):
        aicfg.parse({"provider": "custom", "custom": {"executable": "/x", "args": [], "AUTH_TOKEN": "t"}})


def test_config_context_defaults_off_and_rejects_unknown_switches():
    cfg = aicfg.parse({"provider": "codex"})
    assert all(v is False for v in cfg.context.values())
    with pytest.raises(aicfg.ConfigError, match="unknown context switch"):
        aicfg.parse({"provider": "codex", "context": {"clipboard": True}})


def test_config_timeout_and_model_bounds():
    with pytest.raises(aicfg.ConfigError):
        aicfg.parse({"provider": "claude", "timeoutSeconds": 1})
    with pytest.raises(aicfg.ConfigError):
        aicfg.parse({"provider": "claude", "model": "a b"})


def test_custom_executable_must_be_safe(tmp_path):
    exe = write_exe(tmp_path / "prov", "print('{}')\n")
    assert aicfg.check_executable(str(exe), label="x") == str(exe.resolve())
    with pytest.raises(aicfg.ConfigError, match="absolute"):
        aicfg.check_executable("prov", label="x")
    exe.chmod(0o777)
    with pytest.raises(aicfg.ConfigError, match="writable by other users"):
        aicfg.check_executable(str(exe), label="x")
    with pytest.raises(aicfg.ConfigError, match="does not exist"):
        aicfg.check_executable(str(tmp_path / "missing"), label="x")


def test_write_is_user_only(home):
    p = aicfg.write(aicfg.parse({"provider": "codex"}))
    assert oct(p.stat().st_mode & 0o777) == "0o600"
    assert aicfg.load(p).provider == "codex"


# --- request handling ----------------------------------------------------------

def test_none_mode_without_ai_json_is_a_config_error_not_a_crash(home):
    r = ask(request())
    assert r["ok"] is False and r["error"]["code"] == "config_error"


def test_disabled_integration_makes_no_provider_call(home, fake_claude):
    write_ai(home, enabled=False)
    r = ask(request())
    assert r["error"]["code"] == "disabled"
    assert read_log(fake_claude) == []


def test_claude_invocation_is_locked_down(home, fake_claude):
    write_ai(home)
    r = ask(request("please lower the volume"))
    assert r["ok"] is True, r
    call = read_log(fake_claude)[0]
    argv = call["argv"]
    assert argv[0] == "-p"
    i = argv.index("--tools")
    assert argv[i + 1] == "", "all built-in tools must be disabled"
    for flag in ("--no-session-persistence", "--strict-mcp-config", "--disable-slash-commands", "--output-format"):
        assert flag in argv
    assert "please lower the volume" not in " ".join(argv), "the prompt goes over stdin, never argv"
    assert "please lower the volume" in call["stdin"]
    assert "aerolith-ai-" in call["cwd"], "runs in an empty private directory"
    assert not Path(call["cwd"]).exists(), "the private directory is removed afterwards"


def test_only_catalogue_actions_survive(home, fake_claude):
    write_ai(home)
    r = ask(request())
    actions = [p["action"] for p in r["proposals"]]
    assert actions == ["audio.volume.set", "workspace.focus"]
    assert r["proposals"][0]["args"] == {"level": 25}
    assert any("shell.exec" in w for w in r["warnings"])


def test_context_is_filtered_by_ai_json(home, fake_claude):
    write_ai(home, context={"workspaces": True})
    ask(request(context={"workspaces": [1, 2], "windowTitles": ["secret-document.pdf"]}))
    stdin = read_log(fake_claude)[0]["stdin"]
    assert "secret-document.pdf" not in stdin
    assert "DESKTOP CONTEXT" in stdin


def test_no_context_section_when_nothing_enabled(home, fake_claude):
    write_ai(home)
    ask(request(context={"windowTitles": ["x"]}))
    assert "DESKTOP CONTEXT" not in read_log(fake_claude)[0]["stdin"]


def test_claude_not_installed(home):
    write_ai(home)
    r = ask(request())
    assert r["error"]["code"] == "not_installed"


def test_claude_not_signed_in(home, fake_claude, monkeypatch):
    monkeypatch.setenv("FAKE_MODE", "noauth")
    write_ai(home)
    r = ask(request())
    assert r["error"]["code"] == "not_authenticated"


def test_claude_garbage_output_is_an_error(home, fake_claude, monkeypatch):
    monkeypatch.setenv("FAKE_MODE", "garbage")
    write_ai(home)
    r = ask(request())
    assert r["ok"] is False and r["error"]["code"] == "provider_error"


def test_unstructured_answer_is_shown_without_proposals(home, fake_claude, monkeypatch):
    monkeypatch.setenv("FAKE_MODE", "prose")
    write_ai(home)
    r = ask(request())
    assert r["ok"] is True
    assert r["structured"] is False
    assert r["proposals"] == []
    assert "volume down" in r["reply"]


def test_timeout_kills_the_provider(home, fake_claude, monkeypatch):
    monkeypatch.setenv("FAKE_MODE", "slow")
    write_ai(home, timeoutSeconds=5)
    start = time.monotonic()
    r = ask(request())
    assert r["error"]["code"] == "timeout"
    assert time.monotonic() - start < 15
    pid = read_log(fake_claude)[0]["pid"]
    time.sleep(0.2)
    assert not Path(f"/proc/{pid}").exists() or "zombie" in Path(f"/proc/{pid}/status").read_text().lower()


def test_codex_invocation_is_locked_down(home, fake_codex):
    write_ai(home, provider="codex")
    r = ask(request())
    assert r["ok"] is True, r
    assert r["proposals"] == [{"action": "media.play-pause", "args": {}, "reason": "pause it"}]
    argv = read_log(fake_codex)[0]["argv"]
    assert argv[0] == "exec"
    assert argv[argv.index("--sandbox") + 1] == "read-only"
    for flag in ("--ephemeral", "--ignore-user-config", "--skip-git-repo-check", "--output-schema"):
        assert flag in argv
    disabled = [argv[i + 1] for i, a in enumerate(argv) if a == "--disable"]
    assert sorted(disabled) == sorted(CODEX_DISABLED_FEATURES)
    assert argv[-1] == "-", "prompt over stdin"
    assert "--dangerously-bypass-approvals-and-sandbox" not in argv


def test_codex_unknown_feature_flag_fails_closed(home, fake_codex, monkeypatch):
    monkeypatch.setenv("FAKE_MODE", "unknownflag")
    write_ai(home, provider="codex")
    r = ask(request())
    assert r["error"]["code"] == "incompatible_version"


def test_custom_aerolith_v1_provider(home, tmp_path):
    exe = write_exe(
        tmp_path / "myai",
        """
        import json, sys
        req = json.load(sys.stdin)
        assert req["version"] == 1 and req["actions"]
        print(json.dumps({"reply": "custom says hi: " + req["prompt"], "proposals": [{"action": "workspace.focus", "args": {"workspace": 3}}]}))
        """,
    )
    write_ai(home, provider="custom", custom={"name": "local-llm", "executable": str(exe), "args": [], "protocol": "aerolith-v1"})
    r = ask(request("hello"))
    assert r["ok"] is True, r
    assert r["reply"] == "custom says hi: hello"
    assert r["proposals"][0]["args"] == {"workspace": 3}


def test_custom_text_provider_never_yields_proposals(home, tmp_path):
    exe = write_exe(tmp_path / "echoai", "import sys; print('plain answer to: ' + sys.stdin.read().splitlines()[1])\n")
    write_ai(home, provider="custom", custom={"name": "echo", "executable": str(exe), "protocol": "text"})
    r = ask(request("what time is it"))
    assert r["ok"] is True
    assert r["proposals"] == []
    assert "plain answer" in r["reply"]


def test_custom_provider_with_bad_output(home, tmp_path):
    exe = write_exe(tmp_path / "bad", "print('not json')\n")
    write_ai(home, provider="custom", custom={"name": "bad", "executable": str(exe)})
    assert ask(request())["error"]["code"] == "invalid_output"


def test_request_validation(home):
    assert ask("not json")["error"]["code"] == "config_error"
    assert ask(json.dumps({"version": 99, "prompt": "x"}))["error"]["code"] == "config_error"
    assert ask(json.dumps({"version": 1, "prompt": "   "}))["error"]["code"] == "config_error"
    assert ask(json.dumps({"version": 1, "prompt": "x" * 5000}))["error"]["code"] == "config_error"


def test_status_is_local_and_auth_check_is_opt_in(home, fake_claude):
    write_ai(home)
    s = status(check_auth=False)
    assert s["installed"] is True and "authenticated" not in s
    assert not any("auth" in e for e in read_log(fake_claude))
    s = status(check_auth=True)
    assert s["authenticated"] is True


def test_status_reports_missing_provider(home):
    write_ai(home, provider="codex")
    s = status(check_auth=False)
    assert s["installed"] is False and s["problem"]["code"] == "not_installed"


# --- proposal parsing ----------------------------------------------------------

def test_parse_tolerates_fences_and_prose():
    text = 'Here you go:\n```json\n{"reply": "ok", "proposals": []}\n```\nanything'
    p = parse_output(text, set(), 5)
    assert p.structured and p.reply == "ok"


def test_parse_limits_and_bad_args():
    env = {"reply": "r", "proposals": [{"action": "a", "argsJson": "{bad"}, {"action": "a", "args": [1]}] + [{"action": "a", "args": {}}] * 9}
    p = parse_output(json.dumps(env), {"a"}, 3)
    assert len(p.proposals) == 3
    assert any("argsJson" in w for w in p.warnings)
    assert any("must be an object" in w for w in p.warnings)
    assert any("beyond the limit" in w for w in p.warnings)


def test_empty_output():
    p = parse_output("", {"a"}, 3)
    assert p.reply == "" and p.proposals == []


# --- process level -----------------------------------------------------------

def test_launcher_runs_isolated(home, fake_claude, tmp_path):
    write_ai(home)
    # A hostile module in the current directory must not be imported.
    (tmp_path / "json.py").write_text("raise SystemExit('hijacked')\n")
    proc = subprocess.run(
        [str(ROOT / "ai-bridge" / "aerolith-ai-bridge"), "ask"],
        input=request(),
        capture_output=True,
        text=True,
        cwd=tmp_path,
        env={**os.environ, "PYTHONPATH": str(tmp_path)},
        timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout)["ok"] is True


def test_sigterm_cancels_provider(home, fake_claude, monkeypatch, tmp_path):
    monkeypatch.setenv("FAKE_MODE", "slow")
    write_ai(home, timeoutSeconds=120)
    # The request comes from a file: communicate() on Python 3.12 flushes a
    # closed stdin pipe and raises.
    req = tmp_path / "request.json"
    req.write_text(request())
    with req.open() as stdin:
        proc = subprocess.Popen(
            [sys.executable, "-I", str(ROOT / "ai-bridge" / "aerolith-ai-bridge"), "ask"],
            stdin=stdin,
            stdout=subprocess.PIPE,
            text=True,
        )
    for _ in range(100):
        if read_log(fake_claude):
            break
        time.sleep(0.05)
    child = read_log(fake_claude)[0]["pid"]
    proc.terminate()
    out, _ = proc.communicate(timeout=10)
    assert json.loads(out)["error"]["code"] == "cancelled"
    time.sleep(0.3)
    assert not Path(f"/proc/{child}").exists() or "zombie" in Path(f"/proc/{child}/status").read_text().lower()
