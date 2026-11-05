"""Offline build identity. Read checkout metadata without importing its code."""

from __future__ import annotations

import ast
import re
import subprocess
from pathlib import Path

from . import __version__


def identity(source: Path | None, *, packaged: bool = False) -> dict:
    result = {"version": __version__, "commit": None, "dirty": None}
    if source is None or packaged:
        return result
    try:
        tree = ast.parse((source / "installer/aerolith_install/__init__.py").read_text())
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "__version__" for t in node.targets):
                value = ast.literal_eval(node.value)
                if isinstance(value, str):
                    result["version"] = value
    except (OSError, SyntaxError, ValueError, TypeError):
        pass
    # Do not accidentally identify an archive extracted inside another repo.
    if not (source / ".git").exists():
        return result
    try:
        def git(*args):
            return subprocess.run(["git", "--no-optional-locks", "-C", str(source), *args],
                                  capture_output=True, text=True, timeout=3, check=False)
        rev = git("rev-parse", "HEAD")
        commit = rev.stdout.strip()
        if rev.returncode != 0 or not re.fullmatch(r"[a-f0-9]{40,64}", commit):
            return result
        result["commit"] = commit
        status = git("status", "--porcelain", "--untracked-files=normal")
        if status.returncode == 0:
            result["dirty"] = bool(status.stdout.strip())
    except (OSError, subprocess.TimeoutExpired):
        pass
    return result


def comparison(manifest, local: dict) -> str | None:
    if manifest and manifest.source_commit and local["commit"] and manifest.source_commit != local["commit"]:
        return "different local source: installed commit " + manifest.source_commit + "; local checkout " + local["commit"]
    return None
