"""Tests for the Claude Code / Codex coordination hub.

Run: python -m pytest tools/agent-sync/tests
"""
from __future__ import annotations

import json
import sys
import threading
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import agent_sync  # noqa: E402
from agent_sync import Blackboard, HubError  # noqa: E402


@pytest.fixture
def hub(tmp_path: Path) -> Blackboard:
    return Blackboard(tmp_path)


def test_creates_default_hub(hub: Blackboard) -> None:
    data = hub.read()
    assert data["system_state"] == "Astra_Design_Phase"
    assert data["workflow"]["current_owner"] == "Astra"


def test_committed_hub_is_valid() -> None:
    repo = Path(__file__).resolve().parents[3]
    data = Blackboard(repo).read()
    assert data["system_state"] in agent_sync.STATES


def test_rejects_invalid_state(tmp_path: Path) -> None:
    (tmp_path / agent_sync.HUB_NAME).write_text(json.dumps({"system_state": "Nope"}))
    with pytest.raises(HubError):
        Blackboard(tmp_path)


def test_fills_missing_sections(tmp_path: Path) -> None:
    (tmp_path / agent_sync.HUB_NAME).write_text(json.dumps({"system_state": "Testing_Phase"}))
    hub = Blackboard(tmp_path)
    hub.publish("Claude", "tests_passed", ["tests/x.py"], "ok")
    assert hub.read()["system_state"] == "Astra_Design_Phase"


@pytest.mark.parametrize(
    ("agent", "event", "state", "owner"),
    [
        ("Astra", "design_complete", "Claude_Performance_Audit", "Claude"),
        ("Claude", "performance_audit_complete", "Astra_Design_Phase", "Astra"),
        ("Claude", "integration_complete", "Astra_Design_Audit", "Astra"),
        ("Astra", "design_audit_complete", "Testing_Phase", "Claude"),
        ("Claude", "tests_passed", "Astra_Design_Phase", "Astra"),
    ],
)
def test_transitions(hub: Blackboard, agent: str, event: str, state: str, owner: str) -> None:
    hub.publish(agent, event, ["shell/a.qml"], "done", task_id="T-1")
    data = hub.read()
    assert data["system_state"] == state
    assert data["workflow"]["current_owner"] == owner


def test_wrong_agent_does_not_transition(hub: Blackboard) -> None:
    hub.publish("Claude", "design_complete", [], "not mine")
    assert hub.read()["system_state"] == "Astra_Design_Phase"


def test_design_complete_queues_request(hub: Blackboard) -> None:
    hub.publish("Astra", "design_complete", ["shell/a.qml"], "new look", task_id="UI-1")
    requests = hub.read()["communication_channel"]["astra_to_claude_requests"]
    assert requests[-1]["task_id"] == "UI-1"
    assert requests[-1]["status"] == "pending"


def test_rejects_paths_outside_repo(hub: Blackboard) -> None:
    with pytest.raises(HubError):
        hub.publish("Claude", "note", ["../secret"], "x")
    with pytest.raises(HubError):
        hub.acquire("Claude", ["/etc/passwd"], None)


def test_locks_block_other_agent(hub: Blackboard) -> None:
    hub.acquire("Astra", ["shell/a.qml"], "UI-1")
    ok, message = hub.check_lock("Claude", "shell/a.qml")
    assert not ok and "Astra" in message
    assert hub.check_lock("Astra", "shell/a.qml")[0]
    with pytest.raises(HubError, match="LOCK DENIED"):
        hub.acquire("Claude", ["shell/a.qml", "shell/b.qml"], "IPC-1")
    hub.release("Astra", task_id="UI-1")
    assert hub.check_lock("Claude", "shell/a.qml")[0]
    assert hub.read()["active_file_locks"]["locked_by"] == "None"


def test_partial_release(hub: Blackboard) -> None:
    hub.acquire("Claude", ["a.py", "b.py"], "T")
    hub.release("Claude", ["a.py"])
    assert hub.read()["active_file_locks"]["files"] == ["b.py"]


def test_expired_lock_is_ignored(hub: Blackboard, monkeypatch: pytest.MonkeyPatch) -> None:
    hub.acquire("Astra", ["a.qml"], None, ttl=30)
    real_time = agent_sync.time.time
    monkeypatch.setattr(agent_sync.time, "time", lambda: real_time() + 60)
    assert hub.check_lock("Claude", "a.qml")[0]
    hub.acquire("Claude", ["a.qml"], None)


def test_concurrent_publishes_are_not_lost(tmp_path: Path) -> None:
    Blackboard(tmp_path)

    def worker(i: int) -> None:
        # A separate Blackboard per thread mimics separate CLI processes.
        Blackboard(tmp_path).publish("Claude", "note", [f"f{i}.py"], f"n{i}")

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    changed = Blackboard(tmp_path).read()["changed_files_since_last_completion"]
    assert len(changed) == 20


def test_cli_check_exit_codes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    repo = ["--repo", str(tmp_path)]
    assert agent_sync.cli([*repo, "lock", "--agent", "Astra", "--files", "a.qml"]) == 0
    assert agent_sync.cli([*repo, "check", "--agent", "Claude", "--file", "a.qml"]) == 2
    assert "BLOCKED" in capsys.readouterr().out
    assert agent_sync.cli([*repo, "check", "--agent", "Astra", "--file", "a.qml"]) == 0
