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
