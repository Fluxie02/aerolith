"""The ownership manifest: the only source of truth for what AEROLITH owns.

Removal never guesses. A file is removed only if it is listed here and its
content still matches the recorded hash (otherwise the user changed it and
is asked). Edits to files AEROLITH does not own are recorded as marker
blocks with the backup taken before the edit.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

MANIFEST_VERSION = 1


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def atomic_write(path: Path, data: str, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix="." + path.name + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(data)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        raise


@dataclass
class FileEntry:
    path: str
    sha256: str
    component: str  # core | ai | config | integration
    kind: str = "file"  # file | config | fragment | launcher | service


@dataclass
class EditEntry:
    file: str
    begin: str
    end: str
    backup: str
    component: str = "integration"


@dataclass
class PackageEntry:
    name: str
    method: str  # pacman | native-installer
    paths: list[str] = field(default_factory=list)
    installed_at: float = 0.0


@dataclass
class Manifest:
    version: int = MANIFEST_VERSION
    aerolith_version: str = ""
    source: str = ""
    created: float = 0.0
    updated: float = 0.0
    files: list[FileEntry] = field(default_factory=list)
    dirs: list[str] = field(default_factory=list)
    edits: list[EditEntry] = field(default_factory=list)
    packages: list[PackageEntry] = field(default_factory=list)
    ai_provider: str = "none"
    startup: str = "none"  # hyprland | systemd | manual | none
    hypr_dialect: str = "none"  # lua | hyprlang | none

    # -- persistence -----------------------------------------------------------
    @classmethod
    def load(cls, path: Path) -> Manifest | None:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return None
        if not isinstance(data, dict) or data.get("version") != MANIFEST_VERSION:
            raise ValueError(f"{path}: unsupported or damaged manifest")
        m = cls(
            version=data["version"],
            aerolith_version=data.get("aerolith_version", ""),
            source=data.get("source", ""),
            created=data.get("created", 0.0),
            updated=data.get("updated", 0.0),
            dirs=list(data.get("dirs", [])),
            ai_provider=data.get("ai_provider", "none"),
            startup=data.get("startup", "none"),
            hypr_dialect=data.get("hypr_dialect", "none"),
        )
        m.files = [FileEntry(**f) for f in data.get("files", [])]
        m.edits = [EditEntry(**e) for e in data.get("edits", [])]
        m.packages = [PackageEntry(**p) for p in data.get("packages", [])]
        return m

    def save(self, path: Path) -> None:
        self.updated = time.time()
        if not self.created:
            self.created = self.updated
        atomic_write(path, json.dumps(asdict(self), indent=2) + "\n", 0o600)

    # -- records -----------------------------------------------------------------
    def find(self, path: Path | str) -> FileEntry | None:
        p = str(path)
        return next((f for f in self.files if f.path == p), None)

    def record_file(self, path: Path, component: str, kind: str = "file") -> None:
        entry = FileEntry(str(path), sha256(path), component, kind)
        for i, f in enumerate(self.files):
            if f.path == entry.path:
                self.files[i] = entry
                return
        self.files.append(entry)

    def record_dir(self, path: Path) -> None:
        if str(path) not in self.dirs:
            self.dirs.append(str(path))

    def forget(self, path: Path | str) -> None:
        p = str(path)
        self.files = [f for f in self.files if f.path != p]
        self.dirs = [d for d in self.dirs if d != p]

    def component_files(self, component: str) -> list[FileEntry]:
        return [f for f in self.files if f.component == component]

    def package(self, name: str) -> PackageEntry | None:
        return next((p for p in self.packages if p.name == name), None)


def copy_tree(src: Path, dst: Path, manifest: Manifest, component: str, *, exclude: tuple[str, ...] = ("__pycache__",)) -> list[str]:
    """Copy src into dst, recording every created file and directory.
    Returns the paths written."""
    written: list[str] = []
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in exclude)
        rel = Path(root).relative_to(src)
        target_dir = dst / rel
        if not target_dir.exists():
            target_dir.mkdir(parents=True)
        manifest.record_dir(target_dir)
        for name in sorted(files):
            if name.endswith((".pyc", ".pyo")):
                continue
            s = Path(root) / name
            t = target_dir / name
            shutil.copy2(s, t)
            manifest.record_file(t, component)
            written.append(str(t))
    return written


@dataclass
class RemovalReport:
    removed: list[str] = field(default_factory=list)
    kept_modified: list[str] = field(default_factory=list)
    missing: list[str] = field(default_factory=list)
    dirs_removed: list[str] = field(default_factory=list)
    dirs_kept: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def remove_files(manifest: Manifest, entries: list[FileEntry], *, force_modified: bool = False) -> RemovalReport:
    """Remove manifest-listed files whose content is unchanged.

    Files changed since installation are kept (and reported) unless
    force_modified is set. Directories listed in the manifest are removed
    only when they are empty afterwards, deepest first.
    """
    report = RemovalReport()
    for f in entries:
        p = Path(f.path)
        if not p.exists() and not p.is_symlink():
            report.missing.append(f.path)
            manifest.forget(p)
            continue
        if p.is_file() and not p.is_symlink() and sha256(p) != f.sha256 and not force_modified:
            report.kept_modified.append(f.path)
            continue
        p.unlink()
        report.removed.append(f.path)
        manifest.forget(p)
    return report


def _drop_bytecode_cache(d: Path) -> None:
    """Python may have written __pycache__ into an owned directory (for
    example when a user ran a module by hand). Remove it only when it holds
    nothing but compiled bytecode."""
    cache = d / "__pycache__"
    if not cache.is_dir() or cache.is_symlink():
        return
    entries = list(cache.iterdir())
    if all(e.is_file() and not e.is_symlink() and e.suffix in (".pyc", ".pyo") for e in entries):
        for e in entries:
            e.unlink()
        cache.rmdir()


def prune_dirs(manifest: Manifest, under: Path, report: RemovalReport) -> None:
    for d in sorted((d for d in manifest.dirs if d == str(under) or d.startswith(str(under) + "/")), key=len, reverse=True):
        p = Path(d)
        _drop_bytecode_cache(p)
        try:
            p.rmdir()
            report.dirs_removed.append(d)
            manifest.forget(p)
        except FileNotFoundError:
            manifest.forget(p)
        except OSError:
            report.dirs_kept.append(d)
