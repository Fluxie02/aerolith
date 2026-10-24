"""Create a diagnostic-only harness copy. Source files remain untouched."""
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
build = repo / "build/ui016"
build.mkdir(parents=True, exist_ok=True)
session = (repo / "tools/headless/session.sh").read_text()
session = session.replace('"$SRC/tools/mock-hyprland/mock_hyprland.py"', '"$SRC/build/ui016/mock_hyprland.py"')
session = session.replace('qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &',
    'if [ "$UI016_KIND" = timing ]; then UI016_WAYLAND_DEBUG=1; else UI016_WAYLAND_DEBUG=0; fi\n'
    'WAYLAND_DEBUG=$UI016_WAYLAND_DEBUG QSG_RENDER_TIMING=$UI016_WAYLAND_DEBUG qs -p "$SHELL_DIR" >"$OUT/qs.log" 2>&1 &')
(build / "session.sh").write_text(session)
mock = (repo / "tools/mock-hyprland/mock_hyprland.py").read_text()
mock = mock.replace('"refreshRate": 60.0,', '"refreshRate": float(__import__("os").environ["UI016_HZ"]),')
mock = mock.replace('"name": "DP-1",', '"name": "HEADLESS-1" if "/after" in __import__("os").environ.get("SHELL_PATH", "") else "DP-1",')
(build / "mock_hyprland.py").write_text(mock)
