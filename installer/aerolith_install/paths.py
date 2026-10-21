"""Filesystem layout for a per-user installation."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _xdg(var: str, default: str) -> Path:
    v = os.environ.get(var)
    return Path(v) if v and os.path.isabs(v) else Path(os.path.expanduser(default))


@dataclass(frozen=True)
class Layout:
    home: Path
    data: Path  # ~/.local/share/aerolith
    config: Path  # ~/.config/aerolith
    state: Path  # ~/.local/state/aerolith
    bindir: Path  # ~/.local/bin
    hypr: Path  # ~/.config/hypr
    systemd_user: Path  # ~/.config/systemd/user

    @property
    def shell(self) -> Path:
        return self.data / "shell"

    @property
    def ai_module(self) -> Path:
        return self.shell / "modules" / "ai"

    @property
    def cli(self) -> Path:
        return self.data / "cli"

    @property
    def manifest(self) -> Path:
        return self.state / "manifest.json"

    @property
    def backups(self) -> Path:
        return self.state / "backups"

    @property
    def config_file(self) -> Path:
        return self.config / "config.json"

    @property
    def routines_file(self) -> Path:
        return self.config / "routines.json"

    @property
    def ai_file(self) -> Path:
        return self.config / "ai.json"

    @property
    def hypr_fragment_dir(self) -> Path:
        return self.hypr / "aerolith"

    @property
    def launcher(self) -> Path:
        return self.bindir / "aerolith"

    @property
    def service(self) -> Path:
        return self.systemd_user / "aerolith.service"


def layout() -> Layout:
    home = Path(os.path.expanduser("~"))
    data_home = _xdg("XDG_DATA_HOME", "~/.local/share")
    config_home = _xdg("XDG_CONFIG_HOME", "~/.config")
    state_home = _xdg("XDG_STATE_HOME", "~/.local/state")
    return Layout(
        home=home,
        data=data_home / "aerolith",
        config=config_home / "aerolith",
        state=state_home / "aerolith",
        bindir=home / ".local" / "bin",
        hypr=config_home / "hypr",
        systemd_user=config_home / "systemd" / "user",
    )


def source_root() -> Path | None:
    """The AEROLITH source tree this code runs from, if it is one."""
    here = Path(__file__).resolve().parents[2]
    if (here / "shell" / "shell.qml").is_file() and (here / "installer").is_dir():
        return here
    system = Path("/usr/share/aerolith")
    if (system / "shell" / "shell.qml").is_file():
        return system
    return None


def tilde(p: Path | str) -> str:
    s = str(p)
    home = os.path.expanduser("~")
    return "~" + s[len(home) :] if s == home or s.startswith(home + "/") else s
