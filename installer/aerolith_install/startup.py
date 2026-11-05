"""Transactional startup integration; all systemctl calls use the user bus."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from .manifest import atomic_write, sha256

UNIT = "aerolith.service"


def systemctl(*args: str, allow_failure: bool = False):
    try:
        r = subprocess.run(["systemctl", "--user", *args], capture_output=True,
                           text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"systemd user bus unavailable or timed out: {exc}") from exc
    if r.returncode and not allow_failure:
        raise RuntimeError(f"systemctl --user {' '.join(args)} failed: {r.stderr.strip() or r.stdout.strip()}")
    return r


def disable_for_uninstall():
    """Do not remove installed files if startup cannot be disabled."""
    systemctl("show", "--property=Version")
    enabled = systemctl("is-enabled", UNIT, allow_failure=True).stdout.strip() == "enabled"
    active = systemctl("is-active", UNIT, allow_failure=True).returncode == 0
    try:
        systemctl("disable", "--now", UNIT)
    except RuntimeError as exc:
        try:
            systemctl("enable" if enabled else "disable", UNIT)
            if active:
                systemctl("start", UNIT)
        except RuntimeError as undo_exc:
            raise RuntimeError(f"{exc}; startup rollback also failed: {undo_exc}") from exc
        raise


class Transaction:
    """Back up existing owned files before an install; restore on failure.

    New files are removed by the installer's ownership rollback. Backups live
    only for this transaction and include user configs changed by the plan.
    """

    def __init__(self, lay, previous, desired):
        self.lay = lay
        self.previous = previous
        self.desired = desired
        self.managed = bool(previous and (previous.systemd_enabled or previous.find(lay.service)))
        self.uses_systemd = self.managed or desired == "systemd"
        self.enabled = False
        self.active = False
        self.touched = False
        self.backup = None
        self.saved = {}

    def preflight(self):
        if self.desired == "systemd" and self.lay.service.exists() and not self.managed:
            raise RuntimeError(f"{self.lay.service} is not owned by AEROLITH; refusing to replace it")
        if self.previous:
            for entry in self.previous.files:
                p = Path(entry.path)
                if entry.kind in ("service", "fragment") and p.exists() and sha256(p) != entry.sha256:
                    raise RuntimeError(f"{p} was modified; restore it before changing startup integration")
        if self.uses_systemd:
            # Query a harmless manager property to prove the user bus works.
            # is-system-running can fail with a usable, degraded manager.
            systemctl("show", "--property=Version")
            r = systemctl("is-enabled", UNIT, allow_failure=True)
            state = r.stdout.strip()
            if state not in ("enabled", "enabled-runtime", "disabled", "static", "not-found", ""):
                raise RuntimeError(f"cannot manage {UNIT}: enablement is {state}")
            if state == "enabled-runtime":
                raise RuntimeError(f"{UNIT} has runtime-only enablement; disable it before choosing startup")
            if state == "enabled" and not self.managed:
                raise RuntimeError(f"{UNIT} is already enabled outside this installation")
            self.enabled = state == "enabled"
            self.active = systemctl("is-active", UNIT, allow_failure=True).returncode == 0
            if self.active and not self.managed:
                raise RuntimeError(f"{UNIT} is already running outside this installation")
        # No files or enablement have changed if preflight fails.
        self.backup = tempfile.TemporaryDirectory(prefix="aerolith-install-")
        paths = {Path(f.path) for f in self.previous.files} if self.previous else set()
        paths.update([self.lay.config_file, self.lay.installation_file, self.lay.manifest,
                      self.lay.service, self.lay.hypr / "hyprland.lua", self.lay.hypr / "hyprland.conf"])
        if self.previous:
            paths.update(Path(e.file) for e in self.previous.edits)
        for p in paths:
            if p.is_file():
                backup = Path(self.backup.name) / str(len(self.saved))
                shutil.copy2(p, backup)
                self.saved[p] = backup

    def prepare(self, manifest):
        # Remove the old systemd path before adding compositor autostart.
        if self.managed and self.desired != "systemd":
            self.touched = True
            systemctl("disable", "--now", UNIT)
            self.lay.service.unlink(missing_ok=True)
            manifest.forget(self.lay.service)
            manifest.systemd_enabled = False
            systemctl("daemon-reload")
        # Strip only AEROLITH's generated startup lines, including an old
        # dialect's fragment or --no-hypr installs. Keep binds and layer rules.
        from .hypr import without_autostart
        for entry in list(manifest.files):
            if entry.kind != "fragment":
                continue
            p = Path(entry.path)
            if p.is_file() and p.parent == self.lay.hypr_fragment_dir:
                text = p.read_text()
                clean = without_autostart(text)
                if clean != text:
                    atomic_write(p, clean)
                    manifest.record_file(p, entry.component, entry.kind)

    def enable(self, manifest):
        self.touched = True
        systemctl("daemon-reload")
        systemctl("enable", UNIT)
        manifest.systemd_enabled = True

    def restore(self):
        for p, backup in self.saved.items():
            p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup, p)
        if self.touched:
            systemctl("daemon-reload")
            # A new unit was disabled before ownership rollback removed it.
            # Real systemctl may reject disable after that file is gone.
            if self.enabled or self.managed:
                systemctl("enable" if self.enabled else "disable", UNIT)
            if self.active:
                systemctl("start", UNIT)

    def close(self):
        if self.backup:
            self.backup.cleanup()
