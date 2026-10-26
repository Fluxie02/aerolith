"""Filesystem layout.

Two modes:
- user: installed from a source checkout with install.sh; the shell is
  copied to ~/.local/share/aerolith/shell and AEROLITH owns every file.
- system: the shell comes from the Arch package (/usr/share/aerolith, owned
  by pacman, marked by a PACKAGED file). `aerolith install` then only writes
  this user's files (config, Hyprland fragment, ai.json) and never touches
  the packaged tree.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _xdg(var: str, default: str) -> Path:
    v = os.environ.get(var)
    return Path(v) if v and os.path.isabs(v) else Path(os.path.expanduser(default))


PACKAGED_MARKER = "PACKAGED"


@dataclass(frozen=True)
class Layout:
    home: Path
    data: Path  # ~/.local/share/aerolith
    config: Path  # ~/.config/aerolith
    state: Path  # ~/.local/state/aerolith
    bindir: Path  # ~/.local/bin
    hypr: Path  # ~/.config/hypr
    systemd_user: Path  # ~/.config/systemd/user
    system: Path | None = None  # packaged tree (/usr/share/aerolith) in system mode

    @property
    def mode(self) -> str:
        return "system" if self.system else "user"

    @property
    def shell(self) -> Path:
        return (self.system or self.data) / "shell"

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
    def installation_file(self) -> Path:
        return self.config / "installation.json"

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


def system_root() -> Path | None:
    """The pacman-installed tree, when this code runs from one.

    AEROLITH_SYSTEM_ROOT overrides the location (tests, other prefixes); the
    tree must still carry the PACKAGED marker."""
    override = os.environ.get("AEROLITH_SYSTEM_ROOT")
    root = Path(override) if override else Path(__file__).resolve().parents[2]
    if (root / PACKAGED_MARKER).is_file() and (root / "shell" / "shell.qml").is_file():
        return root
    return None


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
        system=system_root(),
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
