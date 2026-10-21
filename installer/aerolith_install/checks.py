"""Environment checks. All local; nothing here touches the network."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from .paths import Layout

OK, WARN, FAIL, INFO = "ok", "warn", "fail", "info"

# Arch package that provides each required command.
REQUIRED = {
    "qs": "quickshell",
    "Hyprland": "hyprland",
    "ps": "procps-ng",
}
RECOMMENDED = {
    "wpctl": "wireplumber",
    "pw-metadata": "pipewire",
    "busctl": "systemd",
}
MIN_QUICKSHELL = (0, 3, 0)


@dataclass
class Check:
    name: str
    status: str
    detail: str
    package: str = ""


def _run(argv: list[str], timeout: int = 10) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None


def os_release() -> dict[str, str]:
    out: dict[str, str] = {}
    for p in ("/etc/os-release", "/usr/lib/os-release"):
        try:
            for line in Path(p).read_text().splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    out[k] = v.strip().strip('"')
            break
        except OSError:
            continue
    return out


def is_arch_based() -> bool:
    r = os_release()
    ids = (r.get("ID", "") + " " + r.get("ID_LIKE", "")).lower().split()
    return "arch" in ids or "cachyos" in ids


def quickshell_version() -> tuple[int, ...] | None:
    exe = shutil.which("qs") or shutil.which("quickshell")
    if not exe:
        return None
    r = _run([exe, "--version"])
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", (r.stdout if r else "") or "")
    return tuple(int(x) for x in m.groups()) if m else None


def hyprland_monitors() -> list[dict] | None:
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or not shutil.which("hyprctl"):
        return None
    r = _run(["hyprctl", "-j", "monitors"], 5)
    try:
        data = json.loads(r.stdout) if r else None
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, list) else None


def font_available(family: str) -> bool | None:
    if not shutil.which("fc-list"):
        return None
    r = _run(["fc-list", ":", "family"], 10)
    return bool(r) and family.lower() in r.stdout.lower()


def run_checks(lay: Layout) -> list[Check]:
    out: list[Check] = []
    out.append(Check("operating system", OK if is_arch_based() else WARN,
                     os_release().get("PRETTY_NAME", "unknown") + ("" if is_arch_based() else " (only Arch/CachyOS is supported; continuing is at your own risk)")))
    py = sys.version_info
    out.append(Check("python", OK if py >= (3, 11) else FAIL, f"{py.major}.{py.minor}.{py.micro}" + ("" if py >= (3, 11) else " (3.11 or newer needed)")))
    for cmd, pkg in REQUIRED.items():
        found = shutil.which(cmd)
        out.append(Check(cmd, OK if found else FAIL, found or "not installed", pkg))
    qv = quickshell_version()
    if qv is not None:
        ok = qv >= MIN_QUICKSHELL
        out.append(Check("quickshell version", OK if ok else FAIL, ".".join(map(str, qv)) + ("" if ok else " (0.3.0 or newer needed)"), "quickshell"))
    for cmd, pkg in RECOMMENDED.items():
        found = shutil.which(cmd)
        out.append(Check(cmd, OK if found else WARN, found or "not installed (some features unavailable)", pkg))
    dialect = "lua" if (lay.hypr / "hyprland.lua").is_file() else "hyprlang" if (lay.hypr / "hyprland.conf").is_file() else "none"
    out.append(Check("hyprland config", OK if dialect != "none" else WARN,
                     {"lua": "hyprland.lua (Lua, Hyprland 0.55+)", "hyprlang": "hyprland.conf (hyprlang, deprecated since 0.55)", "none": "no config found in " + str(lay.hypr)}[dialect]))
    mons = hyprland_monitors()
    if mons is None:
        out.append(Check("displays", INFO, "Hyprland is not running here; display check skipped"))
    elif len(mons) == 1:
        out.append(Check("displays", OK, f"one display ({mons[0].get('name')}, {mons[0].get('width')}x{mons[0].get('height')})"))
    else:
        names = ", ".join(str(m.get("name")) for m in mons)
        out.append(Check("displays", WARN, f"{len(mons)} displays ({names}). AEROLITH supports one display and will run on one of them only; set display.output to choose."))
    for fam, pkg in (("Inter", "inter-font"), ("JetBrains Mono", "ttf-jetbrains-mono")):
        have = font_available(fam)
        if have is not None:
            out.append(Check(f"font {fam}", OK if have else WARN, "installed" if have else "missing (a fallback font will be used)", pkg))
    return out


def failed(checks: list[Check]) -> list[Check]:
    return [c for c in checks if c.status == FAIL]


def missing_packages(checks: list[Check]) -> list[str]:
    return sorted({c.package for c in checks if c.status == FAIL and c.package})
