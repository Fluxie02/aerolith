"""Package and provider-tool installation. Every action here is explicit:
callers show the exact command and get a yes before calling run()."""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from .manifest import Manifest, PackageEntry

CLAUDE_INSTALLER_URL = "https://claude.ai/install.sh"


@dataclass
class Step:
    """A command the user approves before it runs."""

    description: str
    argv: list[str]


def pacman_installed(name: str) -> bool:
    if not shutil.which("pacman"):
        return False
    r = subprocess.run(["pacman", "-Q", name], capture_output=True, text=True, check=False)
    return r.returncode == 0


def pacman_install_step(packages: list[str]) -> Step:
    return Step(f"install {', '.join(packages)} from the Arch repositories", ["sudo", "pacman", "-S", "--needed", *packages])


def pacman_remove_step(packages: list[str]) -> Step:
    return Step(f"remove {', '.join(packages)}", ["sudo", "pacman", "-Rns", *packages])


def run(step: Step) -> tuple[bool, str]:
    """Run an approved step with the terminal attached (sudo may prompt)."""
    try:
        r = subprocess.run(step.argv, check=False)
    except FileNotFoundError:
        return False, f"{step.argv[0]} is not installed"
    return r.returncode == 0, f"exit status {r.returncode}"


def install_packages(packages: list[str], manifest: Manifest) -> tuple[bool, str]:
    """Install with pacman, recording only packages that were not already
    installed, so uninstalling never removes something the user had."""
    before = {p: pacman_installed(p) for p in packages}
    ok, msg = run(pacman_install_step(packages))
    if ok:
        for p in packages:
            if not before[p] and pacman_installed(p):
                manifest.packages.append(PackageEntry(name=p, method="pacman", installed_at=time.time()))
    return ok, msg


# --- Claude Code native installer ------------------------------------------------

def claude_paths() -> list[Path]:
    home = Path(os.path.expanduser("~"))
    # Documented by Anthropic for the native installer (code.claude.com/docs/en/setup).
    return [home / ".local" / "bin" / "claude", home / ".local" / "share" / "claude"]


def download_claude_installer(dest_dir: Path) -> tuple[Path | None, str]:
    """Download (not run) the official installer so its hash can be shown."""
    if not shutil.which("curl"):
        return None, "curl is not installed"
    dest = dest_dir / "claude-install.sh"
    r = subprocess.run(["curl", "-fsSL", "--proto", "=https", "--tlsv1.2", "-o", str(dest), CLAUDE_INSTALLER_URL], capture_output=True, text=True, check=False)
    if r.returncode != 0:
        return None, (r.stderr.strip() or f"curl exit {r.returncode}") + " (offline? you can install Claude Code later)"
    return dest, hashlib.sha256(dest.read_bytes()).hexdigest()


def run_claude_installer(script: Path, manifest: Manifest) -> tuple[bool, str]:
    preexisting = [p for p in claude_paths() if p.exists()]
    ok, msg = run(Step("run the Claude Code installer", ["bash", str(script)]))
    if ok and not preexisting:
        manifest.packages.append(PackageEntry(name="claude-code", method="native-installer", paths=[str(p) for p in claude_paths()], installed_at=time.time()))
    return ok, msg


def remove_native_claude(entry: PackageEntry) -> list[str]:
    """Remove only the documented native-install paths AEROLITH recorded.
    ~/.claude (settings, credentials, history) is never touched."""
    removed = []
    for p in map(Path, entry.paths):
        if p.is_symlink() or p.is_file():
            p.unlink()
            removed.append(str(p))
        elif p.is_dir():
            shutil.rmtree(p)
            removed.append(str(p))
    return removed


def find_tool(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    local = Path(os.path.expanduser("~")) / ".local" / "bin" / name
    return str(local) if local.exists() else None


def tool_version(exe: str) -> str:
    try:
        r = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=10, check=False)
        return (r.stdout or r.stderr).strip().splitlines()[0][:80] if (r.stdout or r.stderr).strip() else "unknown"
    except (OSError, subprocess.TimeoutExpired, IndexError):
        return "unknown"


def auth_status(provider: str, exe: str) -> bool | None:
    """Offline sign-in check (measured: both commands work without network).
    Only a boolean is derived; output is never printed or stored."""
    import json

    try:
        if provider == "claude":
            r = subprocess.run([exe, "auth", "status"], capture_output=True, text=True, timeout=15, check=False)
            data = json.loads(r.stdout)
            return bool(data.get("loggedIn")) if isinstance(data, dict) else None
        if provider == "codex":
            r = subprocess.run([exe, "login", "status"], capture_output=True, timeout=15, check=False)
            return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return None
    return None


def temp_dir() -> Path:
    return Path(tempfile.mkdtemp(prefix="aerolith-install-"))
