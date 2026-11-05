"""B05 control operations must preserve Hyprland's floating-focus IPC shape."""

import importlib.util
from pathlib import Path
import sys


spec = importlib.util.spec_from_file_location(
    "b05_mock_hyprland",
    Path(__file__).resolve().parents[2] / "tools/mock-hyprland/mock_hyprland.py",
)
mock_module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mock_module
spec.loader.exec_module(mock_module)


def test_floating_focus_preserves_fullscreen_and_emits_window_events(tmp_path):
    mock = mock_module.Mock(str(tmp_path), None, lua=True)
    events = []
    mock.emit = lambda name, data: events.append((name, data))
    game = mock.control({"op": "open", "class": "game", "title": "Game", "workspace": 1})["address"]
    dialog = mock.control({"op": "open", "class": "dialog", "title": "Dialog", "workspace": 1, "floating": True})["address"]
    assert mock.control({"op": "focus_window", "address": game}) == {"ok": True}
    assert mock.control({"op": "fullscreen", "address": game, "mode": 2}) == {"ok": True}

    for address, cls, title in [(dialog, "dialog", "Dialog"), (game, "game", "Game")]:
        events.clear()
        assert mock.control({"op": "focus_window", "address": address}) == {"ok": True}
        assert events == [("activewindow", f"{cls},{title}"), ("activewindowv2", address[2:])]
        active = mock.query("activewindow", "")
        assert active["address"] == address
        assert active["focusHistoryID"] == 0
        clients = {c["address"]: c for c in mock.query("clients", "")}
        assert clients[game]["fullscreen"] == 2
        assert clients[dialog]["fullscreen"] == 0
        assert clients[dialog]["floating"] is True
        assert mock.query("workspaces", "")[0]["hasfullscreen"] is True
        assert clients[game if address == dialog else dialog]["focusHistoryID"] > 0


def test_missing_focus_target_does_not_emit_or_change_state(tmp_path):
    mock = mock_module.Mock(str(tmp_path), None, lua=True)
    events = []
    mock.emit = lambda name, data: events.append((name, data))
    assert mock.control({"op": "focus_window", "address": "0xdead"}) == {"ok": False}
    assert events == []
    assert mock.state.active_addr == ""


def test_open_on_new_unfocused_workspace_announces_creation_before_window(tmp_path):
    mock = mock_module.Mock(str(tmp_path), None, lua=True)
    events = []
    mock.emit = lambda name, data: events.append((name, data))
    address = mock.control({"op": "open", "class": "higher", "title": "Higher", "workspace": 33})["address"]
    assert events == [
        ("createworkspace", "33"),
        ("createworkspacev2", "33,33"),
        ("openwindow", f"{address[2:]},33,higher,Higher"),
    ]
    assert mock.state.active_ws == 1
    workspace = next(w for w in mock.query("workspaces", "") if w["id"] == 33)
    assert workspace["windows"] == 1
    assert next(c for c in mock.query("clients", "") if c["address"] == address)["workspace"]["id"] == 33

    # Opening another client there must not announce the workspace twice.
    events.clear()
    second = mock.control({"op": "open", "class": "second", "title": "Second", "workspace": 33})["address"]
    assert events == [("openwindow", f"{second[2:]},33,second,Second")]
    assert next(w for w in mock.query("workspaces", "") if w["id"] == 33)["windows"] == 2


def test_hotplug_announces_default_workspace_before_monitor(tmp_path):
    mock = mock_module.Mock(str(tmp_path), None, lua=True)
    events = []
    mock.emit = lambda name, data: events.append((name, data))
    assert mock.control({"op": "add_monitor", "name": "DP-2", "workspace": 5}) == {"ok": True}
    assert events == [
        ("createworkspace", "5"),
        ("createworkspacev2", "5,5"),
        ("monitoradded", "DP-2"),
        ("monitoraddedv2", "1,DP-2,Mock Display 1920x1080"),
    ]
    workspace = next(w for w in mock.query("workspaces", "") if w["id"] == 5)
    monitor = next(m for m in mock.query("monitors", "") if m["name"] == "DP-2")
    assert workspace["monitor"] == monitor["name"]
    assert monitor["activeWorkspace"]["id"] == 5
    assert mock.state.active_ws == 1
