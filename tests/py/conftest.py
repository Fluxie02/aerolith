"""Shared fixtures for the Python test suite.

Everything here runs against a throwaway HOME and fake executables on PATH.
These are mock tests: they prove AEROLITH's side of each contract (what it
runs, with which flags, how it reacts to each outcome), not the behaviour of
the real Claude Code, Codex, pacman or Hyprland binaries.
"""

from __future__ import annotations

import json
import os
import stat
import sys
import textwrap
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ai-bridge"))
sys.path.insert(0, str(ROOT / "installer"))


def write_exe(path: Path, body: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/usr/bin/env -S python3 -I\n" + textwrap.dedent(body), encoding="utf-8")
    path.chmod(0o755)
    return path


@pytest.fixture
def home(tmp_path, monkeypatch):
    h = tmp_path / "home"
    (h / ".config").mkdir(parents=True)
    (h / ".local" / "state").mkdir(parents=True)
    (h / ".local" / "bin").mkdir(parents=True)
    bindir = tmp_path / "bin"
    bindir.mkdir()
    monkeypatch.setenv("HOME", str(h))
    monkeypatch.setenv("XDG_CONFIG_HOME", str(h / ".config"))
    monkeypatch.setenv("XDG_STATE_HOME", str(h / ".local" / "state"))
    monkeypatch.setenv("XDG_DATA_HOME", str(h / ".local" / "share"))
    monkeypatch.setenv("CODEX_HOME", str(h / ".codex"))
    monkeypatch.delenv("AEROLITH_CONFIG_DIR", raising=False)
    monkeypatch.delenv("HYPRLAND_INSTANCE_SIGNATURE", raising=False)
    monkeypatch.delenv("AEROLITH_SYSTEM_ROOT", raising=False)
    # Only our fakes plus the basics: no real provider can be reached.
    monkeypatch.setenv("PATH", f"{bindir}:/usr/bin:/bin")
    return h


@pytest.fixture
def bindir(home):
    return Path(os.environ["PATH"].split(":")[0])


FAKE_CLAUDE = r'''
import json, os, sys, time
log = os.environ.get("FAKE_LOG")
mode = os.environ.get("FAKE_MODE", "ok")
argv = sys.argv[1:]
if argv[:1] == ["--version"]:
    print("2.1.306 (Claude Code)"); sys.exit(0)
if argv[:2] == ["auth", "status"]:
    if log:
        open(log, "a").write(json.dumps({"auth": True}) + "\n")
    print(json.dumps({"loggedIn": mode != "noauth", "authMethod": "oauth_token"})); sys.exit(0)
stdin = sys.stdin.read()
if log:
    open(log, "a").write(json.dumps({"argv": argv, "stdin": stdin, "cwd": os.getcwd(), "pid": os.getpid()}) + "\n")
if mode == "slow":
    time.sleep(60)
if mode == "noauth":
    print(json.dumps({"type": "result", "subtype": "success", "is_error": True, "result": "Not logged in · Please run /login"})); sys.exit(1)
if mode == "garbage":
    print("segfault-ish nonsense"); sys.exit(3)
if mode == "prose":
    print(json.dumps({"type": "result", "is_error": False, "result": "Sure, just turn the volume down."})); sys.exit(0)
envelope = {"reply": "Setting a calmer volume.", "proposals": [
    {"action": "audio.volume.set", "argsJson": "{\"level\": 25}", "reason": "quieter"},
    {"action": "shell.exec", "argsJson": "{\"argv\": [\"rm\", \"-rf\", \"/\"]}", "reason": "evil"},
    {"action": "workspace.focus", "args": {"workspace": 2}, "reason": "go"}]}
print(json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "```json\n" + json.dumps(envelope) + "\n```"}))
'''

FAKE_CODEX = r'''
import json, os, sys
log = os.environ.get("FAKE_LOG")
mode = os.environ.get("FAKE_MODE", "ok")
argv = sys.argv[1:]
if argv[:1] == ["--version"]:
    print("codex-cli 0.163.0"); sys.exit(0)
if argv[:2] == ["login", "status"]:
    print("Logged in using ChatGPT"); sys.exit(0 if mode != "noauth" else 1)
stdin = sys.stdin.read()
if log:
    open(log, "a").write(json.dumps({"argv": argv, "stdin": stdin, "cwd": os.getcwd()}) + "\n")
if mode == "unknownflag":
    sys.stderr.write("Error: Unknown feature flag: shell_tool\n"); sys.exit(1)
if mode == "noauth":
    sys.stderr.write("Error: Not logged in. Run codex login\n"); sys.exit(1)
out = argv[argv.index("-o") + 1]
open(out, "w").write(json.dumps({"reply": "Done thinking.", "proposals": [
    {"action": "media.play-pause", "argsJson": "", "reason": "pause it"}]}))
'''


@pytest.fixture
def fake_claude(bindir, tmp_path, monkeypatch):
    log = tmp_path / "claude.log"
    monkeypatch.setenv("FAKE_LOG", str(log))
    write_exe(bindir / "claude", FAKE_CLAUDE)
    return log


@pytest.fixture
def fake_codex(bindir, tmp_path, monkeypatch):
    log = tmp_path / "codex.log"
    monkeypatch.setenv("FAKE_LOG", str(log))
    write_exe(bindir / "codex", FAKE_CODEX)
    return log


def read_log(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def mode_exe(path: Path) -> None:
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
