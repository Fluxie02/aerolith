"""Multi-output IPC ownership, focus and hotplug in the headless mock."""
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location(
    "mm1_mock", Path(__file__).resolve().parents[2] / "tools/mock-hyprland/mock_hyprland.py")
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


def test_outputs_have_independent_workspaces_and_fullscreen(tmp_path):
    mock = module.Mock(str(tmp_path), None, lua=True)
    mock.emit = lambda *_: None
    mock.control({"op": "rename_monitor", "name": "DP-1", "newName": "HEADLESS-1"})
    assert mock.control({"op": "add_monitor", "name": "HEADLESS-2", "workspace": 4}) == {"ok": True}
    mock.control({"op": "focus_monitor", "name": "HEADLESS-2"})
    game = mock.control({"op": "open", "class": "game", "title": "Game"})["address"]
    mock.control({"op": "fullscreen", "address": game, "mode": 2})
    mons = mock.query("monitors", "")
    assert [m["activeWorkspace"]["id"] for m in mons] == [1, 4]
    assert [m["focused"] for m in mons] == [False, True]
    clients = mock.query("clients", "")
    assert clients[0]["workspace"]["id"] == 4
    assert clients[0]["monitor"] == mons[1]["id"]
    assert clients[0]["at"][0] >= mons[1]["x"]
    assert mock.query("activewindow", "")["monitor"] == mons[1]["id"]
    mock.control({"op": "focus_monitor", "name": "HEADLESS-1"})
    mock.control({"op": "focus_workspace", "workspace": 2})
    assert [m["activeWorkspace"]["id"] for m in mock.query("monitors", "")] == [2, 4]
    assert next(w for w in mock.query("workspaces", "") if w["id"] == 4)["monitor"] == "HEADLESS-2"
    mock.control({"op": "focus_window", "address": game})
    assert mock.state.focused_monitor == "HEADLESS-2"
    mock.control({"op": "remove_monitor", "name": "HEADLESS-2"})
    assert mock.state.focused_monitor == "HEADLESS-1"
    assert len(mock.query("monitors", "")) == 1
    assert mock.query("clients", "")[0]["monitor"] == 0
    assert mock.state.active_by_monitor == {"HEADLESS-1": 2}


def test_duplicate_or_invalid_monitor_operations_do_not_mutate(tmp_path):
    mock = module.Mock(str(tmp_path), None, lua=True)
    events = []
    mock.emit = lambda *args: events.append(args)
    for msg in [{"op": "add_monitor", "name": "DP-1"},
                {"op": "add_monitor", "name": "DP-2", "workspace": 1},
                {"op": "rename_monitor", "name": "missing", "newName": "DP-2"},
                {"op": "focus_monitor", "name": "missing"},
                {"op": "remove_monitor", "name": "DP-1"}]:
        assert mock.control(msg) == {"ok": False}
    assert len(mock.state.monitors) == 1
    assert events == []


def test_closing_last_client_on_unfocused_output_keeps_visible_workspace(tmp_path):
    mock = module.Mock(str(tmp_path), None, lua=True)
    events = []
    mock.emit = lambda *args: events.append(args)
    mock.control({"op": "add_monitor", "name": "DP-2", "workspace": 4})
    mock.control({"op": "focus_monitor", "name": "DP-2"})
    client = mock.control({"op": "open", "class": "test", "title": "test"})["address"]
    mock.control({"op": "focus_monitor", "name": "DP-1"})
    events.clear()
    mock.control({"op": "close", "address": client})
    assert not any(name.startswith("destroyworkspace") for name, _ in events)
    assert mock.state.active_by_monitor["DP-2"] == 4
