"""Environment checks. All local; nothing here touches the network."""

from __future__ import annotations

import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
from contextlib import contextmanager
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


class DiagnosticTimeout(Exception):
    pass


@contextmanager
def time_budget(seconds: float):
    """Bound a read-only doctor probe, including Python IO and child commands.

    The CLI runs on Linux's main thread. Preserve an enclosing budget when a
    helper invokes another bounded check. subprocess.run reaps on exceptions.
    """
    if seconds <= 0:
        raise DiagnosticTimeout("overall diagnostic budget exhausted")
    def expired(signum, frame):
        raise DiagnosticTimeout("diagnostic check timed out")
    old_handler = signal.getsignal(signal.SIGALRM)
    old_timer = signal.setitimer(signal.ITIMER_REAL, 0)
    started = time.monotonic()
    signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, min(seconds, old_timer[0]) if old_timer[0] else seconds)
    try:
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, old_handler)
        if old_timer[0]:
            signal.setitimer(signal.ITIMER_REAL, max(0.000001, old_timer[0] - (time.monotonic() - started)), old_timer[1])


def collect(name, probe, *, timeout: float, deadline: float) -> Check | None:
    try:
        with time_budget(min(timeout, deadline - time.monotonic())):
            return probe()
    except Exception as exc:
        # A malformed external reply must still leave a partial JSON report.
        # KeyboardInterrupt/SystemExit remain outside the diagnostic envelope.
        return Check(name, FAIL, str(exc))


def running_hyprland_version() -> str | None:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        return None
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(2)
            sock.connect(str(Path(runtime) / "hypr" / signature / ".socket.sock"))
            sock.sendall(b"j/version")
            chunks = bytearray()
            while len(chunks) < 65536:
                chunk = sock.recv(min(4096, 65536 - len(chunks)))
                if not chunk:
                    data = json.loads(chunks)
                    v = data.get("version") if isinstance(data, dict) else None
                    return v if isinstance(v, str) and v.strip() else None
                chunks.extend(chunk)
    except (OSError, ValueError):
        pass
    return None


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


def hyprland_version() -> tuple[int, ...] | None:
    exe = shutil.which("Hyprland") or shutil.which("hyprland")
    if not exe:
        return None
    r = _run([exe, "--version"])
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", (r.stdout if r else "") or "")
    return tuple(int(x) for x in m.groups()) if m else None


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


def installed_locker() -> str | None:
    return next((name for name in ("hyprlock", "swaylock") if shutil.which(name)), None)


def notifications_owner() -> str:
    """Inspect acquired names only: never activate a notification daemon.

    A failed bus query is unknown, not evidence that the name is unowned.
    """
    r = _run(["busctl", "--user", "--no-pager", "--no-legend", "--acquired", "list"], 5)
    if r is None or r.returncode != 0:
        return "unknown"
    for line in r.stdout.splitlines():
        fields = line.split()
        if fields and fields[0] == "org.freedesktop.Notifications":
            return f"{fields[2]} ({fields[4]})" if len(fields) >= 5 else fields[0]
    return "nobody"


def uwsm_active() -> bool:
    if not shutil.which("uwsm"):
        return False
    r = _run(["uwsm", "check", "is-active"], 5)
    return r is not None and r.returncode == 0


def run_checks(lay: Layout, *, timeout: float | None = None, deadline: float | None = None) -> list[Check]:
    # Each probe is independent: a failure or timeout must not hide later checks.
    from . import hypr

    def operating_system():
        arch = is_arch_based()
        return Check("operating system", OK if arch else WARN,
                     os_release().get("PRETTY_NAME", "unknown") + ("" if arch else " (only Arch/CachyOS is supported; continuing is at your own risk)"))

    def command(cmd, pkg, required):
        found = shutil.which(cmd)
        return Check(cmd, OK if found else (FAIL if required else WARN),
                     found or ("not installed" if required else "not installed (some features unavailable)"), pkg)

    def qs_version():
        qv = quickshell_version()
        if qv is None:
            return None
        ok = qv >= MIN_QUICKSHELL
        return Check("quickshell version", OK if ok else FAIL,
                     ".".join(map(str, qv)) + ("" if ok else " (0.3.0 or newer needed)"), "quickshell")

    def config():
        dialect = hypr.detect_dialect(lay, hyprland_version())[0]
        return Check("hyprland config", OK if dialect in ("lua", "hyprlang") else WARN,
                     {"lua": "hyprland.lua (Lua, Hyprland 0.55+)", "hyprlang": "hyprland.conf (hyprlang, deprecated since 0.55)",
                      "unsupported": "only hyprland.conf, which Hyprland 0.57+ no longer reads; migrate it to hyprland.lua, then run `aerolith install` again",
                      "none": "no config found in " + str(lay.hypr)}[dialect])

    def displays():
        mons = hyprland_monitors()
        if mons is None:
            return Check("displays", INFO, "Hyprland is not running here; display check skipped")
        detail = ", ".join(f"{m.get('name')}, {m.get('width')}x{m.get('height')}" for m in mons)
        label = "display" if len(mons) == 1 else "displays"
        return Check("displays", OK, f"{len(mons)} {label} ({detail})")

    def font(fam, pkg):
        have = font_available(fam)
        return None if have is None else Check(f"font {fam}", OK if have else WARN,
                      "installed" if have else "missing (a fallback font will be used)", pkg)

    py = sys.version_info
    probes = [("operating system", operating_system),
              ("python", lambda: Check("python", OK if py >= (3, 11) else FAIL,
               f"{py.major}.{py.minor}.{py.micro}" + ("" if py >= (3, 11) else " (3.11 or newer needed)")))]
    probes += [(cmd, lambda cmd=cmd, pkg=pkg: command(cmd, pkg, True)) for cmd, pkg in REQUIRED.items()]
    probes.append(("quickshell version", qs_version))
    probes += [(cmd, lambda cmd=cmd, pkg=pkg: command(cmd, pkg, False)) for cmd, pkg in RECOMMENDED.items()]
    probes += [("hyprland config", config), ("displays", displays)]
    probes += [(f"font {fam}", lambda fam=fam, pkg=pkg: font(fam, pkg))
               for fam, pkg in (("Inter", "inter-font"), ("JetBrains Mono", "ttf-jetbrains-mono"))]
    out = []
    for name, probe in probes:
        c = collect(name, probe, timeout=timeout, deadline=deadline or float("inf")) if timeout is not None else probe()
        if c is not None:
            out.append(c)
    return out


def failed(checks: list[Check]) -> list[Check]:
    return [c for c in checks if c.status == FAIL]


def missing_packages(checks: list[Check]) -> list[str]:
    return sorted({c.package for c in checks if c.status == FAIL and c.package})


def recommended_packages(checks: list[Check]) -> list[str]:
    return sorted({c.package for c in checks if c.status == WARN and c.package} - set(missing_packages(checks)))
