"""Explicit application exports. No app processes, preferences or mod installers.

prepare_app() is the single scheme/direction entry point for a future C06 caller.
It preflights without writes; execute() checks again before writing. All edits
are additive, byte-preserving blocks, separate from shell startup integration.
"""
from __future__ import annotations

import json
import re
import shutil
import tomllib
import uuid
from dataclasses import dataclass, field
from pathlib import Path

from . import hypr
from .manifest import EditEntry, Manifest, atomic_write, prune_dirs, remove_files, sha256
from .paths import Layout, source_root

SUPPORTED = ("kitty", "alacritty", "foot", "btop", "hyprland", "gtk3", "gtk4", "qt5ct", "qt6ct")
DEFERRED = {
    "firefox": "not yet supported: needs an explicitly named profile/chrome directory and stylesheet preference consent; no prefs.js or user.js edits",
    "steam": "not yet supported: needs an existing Millennium theme directory and manual selection; AEROLITH never installs Millennium",
    "discord": "not yet supported: needs an existing Vencord theme directory and manual selection; AEROLITH never installs Vencord",
    "libreoffice": "not yet supported: extension packaging/registration and exact removal need a separate integration",
    "artcraft": "not supported: exported adapter is for debug builds only",
}
CONFIG_DIRS = {"gtk3": "gtk-3.0", "gtk4": "gtk-4.0", "hyprland": "hypr", "steam": "steam", "discord": "Vencord", "firefox": "mozilla", "libreoffice": "libreoffice"}


class ThemeError(RuntimeError):
    pass


def component(app: str) -> str:
    return "theme:" + app


def read_object(path: Path) -> dict:
    try:
        value = json.loads(path.read_bytes())
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as exc:
        raise ThemeError(f"{path}: invalid JSON ({exc}); fix it first") from exc
    if not isinstance(value, dict):
        raise ThemeError(f"{path}: expected a JSON object")
    return value


def selection(lay: Layout, scheme: str | None = None, direction: str | None = None) -> tuple[str, str]:
    direction = direction or read_object(lay.installation_file).get("direction", "piyti")
    if direction not in ("piyti", "thears"):
        raise ThemeError("invalid installation direction; repair installation.json first")
    if scheme is None:
        theme = read_object(lay.config_file).get("theme", {})
        if not isinstance(theme, dict):
            raise ThemeError("config.json: theme must be an object")
        scheme = theme.get("scheme", "limb")
    if not isinstance(scheme, str) or not re.fullmatch(r"[a-z][a-z0-9-]*", scheme):
        raise ThemeError("invalid scheme ID")
    return scheme, direction


def assets_root(lay: Layout, manifest: Manifest, source: Path | None = None) -> Path:
    # Source installs retain a private catalog so the checkout can disappear.
    candidates = ([source / "themes"] if source else []) + [
        (lay.system or lay.data) / "theme-assets",
        (lay.system or lay.data) / "themes",
    ]
    if manifest.source:
        candidates.append(Path(manifest.source) / "themes")
    src = source_root()
    if src:
        candidates.append(src / "themes")
    for root in candidates:
        if (root / "schemes" / "index.json").is_file():
            return root
    raise ThemeError("generated theme assets are unavailable; use a checkout containing themes/schemes or ask the package maintainer to ship them")


def safe_path(path: Path) -> None:
    for p in (path, *path.parents):
        if p.is_symlink():
            raise ThemeError(f"{p}: symlinks are not modified; use a regular config path")
    if path.exists() and not path.is_file():
        raise ThemeError(f"{path}: expected a regular file")
    if any(ord(c) < 32 for c in str(path)):
        raise ThemeError(f"unsafe control character in path: {path!r}")


def text_at(path: Path) -> str:
    safe_path(path)
    try:
        return path.read_bytes().decode("utf-8") if path.exists() else ""
    except UnicodeError as exc:
        raise ThemeError(f"{path}: config must be UTF-8") from exc


def fragment(path: Path) -> str:
    try:
        return path.read_bytes().decode("utf-8")
    except (OSError, UnicodeError) as exc:
        raise ThemeError(f"generated fragment unavailable: {path} ({exc}); report the asset to Astra") from exc


def backup(lay: Layout, path: Path) -> str:
    target = lay.backups / "themes" / (uuid.uuid4().hex + "-" + path.name)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    return str(target)


def mkdir_owned(path: Path, manifest: Manifest) -> None:
    missing = []
    while not path.exists():
        missing.append(path)
        path = path.parent
    for directory in reversed(missing):
        directory.mkdir()
        manifest.record_dir(directory)


@dataclass
class AppPlan:
    app: str
    scheme: str
    direction: str
    files: list[tuple[Path, str]] = field(default_factory=list)
    edit: tuple[Path, str, str, str, str] | None = None  # path, original, insertion, begin, end
    note: str = "Restart/reload the app to load the fragment."
    position: int = 0

    def describe(self) -> list[str]:
        lines = [f"{self.app}: {self.scheme}/{self.direction}"]
        lines += [f"  copy generated fragment to {p}" for p, _ in self.files]
        if self.edit:
            lines += [f"  add managed include to {self.edit[0]}"]
        return lines + ["  " + self.note]


def marked(app: str, body: str, prefix: str = "#") -> tuple[str, str, str]:
    begin = f"{prefix} >>> AEROLITH theme:{app}"
    end = f"{prefix} <<< AEROLITH theme:{app}"
    return begin, end, begin + "\n" + body + "\n" + end + "\n"


def alacritty_insert(text: str, target: Path, block) -> tuple[int, str]:
    try:
        parsed = tomllib.loads(text)
    except ValueError as exc:
        raise ThemeError(f"Alacritty TOML is invalid: {exc}") from exc
    if "import" in parsed:
        raise ThemeError("Alacritty: migrate legacy root import to [general].import first")
    general = parsed.get("general", {})
    if not isinstance(general, dict):
        raise ThemeError("Alacritty: general must be a table")
    table = re.search(r"(?m)^\s*\[general\][ \t]*(?:#[^\n]*)?(?:\n|$)", text)
    if "general" in parsed and table is None:
        raise ThemeError("Alacritty: use an explicit [general] table instead of dotted keys/inline tables")
    quoted = json.dumps(str(target))
    if table is None:
        return len(text), block("[general]\nimport = [" + quoted + "]")
    if "import" not in general:
        return table.end(), block("import = [" + quoted + "]")
    imports = general["import"]
    if not isinstance(imports, list) or not all(isinstance(p, str) for p in imports):
        raise ThemeError("Alacritty: general.import must be an array of paths")
    if str(target) in imports:
        raise ThemeError("Alacritty: AEROLITH path is already imported outside its managed block; remove that import first")
    next_table = re.search(r"(?m)^\s*\[", text[table.end():])
    limit = table.end() + next_table.start() if next_table else len(text)
    match = re.search(r"(?m)^[ \t]*import[ \t]*=[ \t]*\[", text[table.end():limit])
    if not match:
        raise ThemeError("Alacritty: cannot safely locate general.import; use a plain import = [...] entry")
    start = table.end() + match.end() - 1
    # Try each closing bracket; TOML itself validates strings, comments and
    # trailing commas. No reserialization of the user's document is needed.
    for end in range(start + 1, limit):
        if text[end] != "]":
            continue
        try:
            value = tomllib.loads("value = " + text[start:end + 1])["value"]
        except ValueError:
            continue
        if value != imports:
            continue
        for comma in ("", ", "):
            insertion = "\n" + block(comma + quoted)
            try:
                tomllib.loads(text[:end] + insertion + text[end:])
            except ValueError:
                continue
            return end, insertion
    raise ThemeError("Alacritty: cannot safely extend general.import")


def prepare_app(lay: Layout, manifest: Manifest, root: Path, app: str, scheme: str, direction: str) -> AppPlan:
    """Render a preflighted deployment for one app and an explicit scheme."""
    if app not in SUPPORTED:
        raise ThemeError(f"{app}: " + DEFERRED.get(app, "unknown app; see `aerolith themes list`"))
    catalog = read_object(root / "schemes" / "index.json")
    if scheme not in {s["id"] for s in catalog.get("schemes", [])}:
        raise ThemeError(f"unknown scheme: {scheme}; see themes/schemes/index.json")
    base = root / "schemes" / scheme
    owned = lay.data / "themes" / app
    config = lay.config.parent
    plan = AppPlan(app, scheme, direction)
    main = None
    body = ""
    prefix = "#"
    if app == "kitty":
        source, target = "kitty/aerolith.conf", owned / "aerolith.conf"
        main, body = config / "kitty/kitty.conf", f"include {target}"
    elif app == "alacritty":
        source, target = "alacritty/aerolith.toml", owned / "aerolith.toml"
        main = config / "alacritty/alacritty.toml"
        alternate = [config / p for p in ("alacritty.toml", "alacritty.yml", "alacritty/alacritty.yml")]
        alternate += [lay.home / ".alacritty.toml", lay.home / ".alacritty.yml", lay.home / ".config/alacritty/alacritty.toml"]
        if not main.exists() and any(p.exists() for p in alternate if p != main):
            raise ThemeError("Alacritty: alternate/legacy config detected; migrate to alacritty/alacritty.toml first")
    elif app == "foot":
        source, target = "foot/aerolith.ini", owned / "aerolith.ini"
        main, body = config / "foot/foot.ini", f"include={target}"
    elif app == "btop":
        source, target = "btop/aerolith.theme", config / "btop/themes/aerolith.theme"
        plan.note = "Select aerolith in btop's theme chooser; selection preferences are unchanged."
    elif app in ("gtk3", "gtk4"):
        directory = "gtk-3.0" if app == "gtk3" else "gtk-4.0"
        source, target = directory + "/gtk.css", owned / "gtk.css"
        main = config / directory / "gtk.css"
        body = f"@import url({json.dumps(str(target), ensure_ascii=False)});"
        prefix = "/*"
        plan.note = "GTK user CSS override only; restart apps. Accessibility CSS and sandbox access remain user choices."
    elif app in ("qt5ct", "qt6ct"):
        source, target = "qt/aerolith.conf", config / app / "colors/aerolith.conf"
        plan.files.append((config / app / "qss/aerolith.qss", fragment(base / "qt/aerolith.qss")))
        plan.note = f"In {app} choose Fusion, custom palette aerolith and optionally qss/aerolith.qss. Select the platform plugin per app; no environment or preferences are changed."
    else:
        dialect, main = hypr.detect_dialect(lay)
        if main is None:
            dialect = manifest.hypr_dialect if manifest.hypr_dialect in ("lua", "hyprlang") else "lua"
            main = lay.hypr / ("hyprland.lua" if dialect == "lua" else "hyprland.conf")
        ext = "lua" if dialect == "lua" else "conf"
        source, target = f"hyprland/aerolith.{ext}", owned / ("aerolith." + ext)
        shape = owned / ("direction." + ext)
        plan.files.append((shape, fragment(base / "hyprland" / (direction + "." + ext))))
        prefix = "--" if dialect == "lua" else "#"
        body = "\n".join(f"dofile({hypr.lua_string(str(p))})" if dialect == "lua" else f"source = {p}" for p in (target, shape))
        plan.note = "Reload Hyprland manually. Loads shared appearance plus the installed direction's app rules."
    plan.files.append((target, fragment(base / source)))
    if app in ("kitty", "foot", "hyprland") and any(c in str(target) for c in '\\#$*?[]"\''):
        raise ThemeError(f"{target}: path contains characters unsafe for this app's include syntax")
    for path, _ in plan.files:
        safe_path(path)
        entry = manifest.find(path)
        if path.exists() and (entry is None or entry.component != component(app) or sha256(path) != entry.sha256):
            raise ThemeError(f"{path}: existing or user-modified file; move it aside before applying")
    if main is not None:
        text = text_at(main)
        def block(value: str) -> str:
            begin, end, insertion = marked(app, value, prefix)
            if prefix == "/*":
                insertion = insertion.replace(begin, begin + " */").replace(end, end + " */")
            return insertion
        begin, end, _ = marked(app, "", prefix)
        if prefix == "/*":
            begin, end = begin + " */", end + " */"
        existing = next((e for e in manifest.edits if e.file == str(main) and e.component == component(app)), None)
        if existing:
            if text.count(begin) != 1 or text.count(end) != 1 or existing.inserted not in text:
                raise ThemeError(f"{main}: managed block was edited; remove/repair it before reapplying")
        else:
            if begin in text or end in text or str(target) in text:
                raise ThemeError(f"{main}: unrecorded AEROLITH include; remove it by hand before applying")
            if app == "alacritty":
                pos, insertion = alacritty_insert(text, target, block)
            elif app in ("foot", "gtk3", "gtk4"):
                pos, insertion = 0, block(body)
            else:
                pos = len(text)
                insertion = ("\n" if text and not text.endswith("\n") else "") + block(body)
            if app == "alacritty":
                # A new table at EOF needs a line boundary as well.
                if pos == len(text) and text and not text.endswith("\n"):
                    insertion = "\n" + insertion
                try:
                    updated = tomllib.loads(text[:pos] + insertion + text[pos:])
                except ValueError as exc:
                    raise ThemeError(f"Alacritty: cannot safely add an import ({exc})") from exc
                if str(target) not in updated.get("general", {}).get("import", []):
                    raise ThemeError("Alacritty: section-like text inside a string; cannot safely locate [general]")
            # Store the full original + the insertion offset implicitly via
            # the final document, while the manifest owns just the insertion.
            plan.edit = (main, text, insertion, begin, end)
            plan.position = pos
    return plan


def execute(lay: Layout, manifest: Manifest, plan: AppPlan) -> None:
    for path, data in plan.files:
        safe_path(path)
        existing = manifest.find(path)
        if path.exists() and (not existing or existing.component != component(plan.app) or sha256(path) != existing.sha256):
            raise ThemeError(f"{path}: changed after planning")
    if plan.edit:
        path, original, insertion, begin, end = plan.edit
        if text_at(path) != original:
            raise ThemeError(f"{path}: changed after planning")
    # Write payloads before exposing their includes to the application.
    for path, data in plan.files:
        mkdir_owned(path.parent, manifest)
        atomic_write(path, data)
        manifest.record_file(path, component(plan.app))
        manifest.save(lay.manifest)
    if plan.edit:
        path, original, insertion, begin, end = plan.edit
        if text_at(path) != original:
            raise ThemeError(f"{path}: changed after writing theme payloads; config was not edited")
        created = not path.exists()
        saved = backup(lay, path) if not created else ""
        mkdir_owned(path.parent, manifest)
        pos = plan.position
        mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
        atomic_write(path, original[:pos] + insertion + original[pos:], mode)
        manifest.edits.append(EditEntry(str(path), begin, end, saved, component(plan.app), insertion, created))
        manifest.save(lay.manifest)
    manifest.themes[plan.app] = {"scheme": plan.scheme, "direction": plan.direction, "note": plan.note}
    manifest.save(lay.manifest)


def remove_edit(lay: Layout, entry: EditEntry) -> str:
    path = Path(entry.file)
    text = text_at(path)
    if not path.exists():
        return f"{path}: already absent"
    if entry.inserted and text.count(entry.inserted) == 1:
        new = text.replace(entry.inserted, "", 1)
    elif entry.begin not in text and entry.end not in text:
        return f"{path}: block already absent; kept unmarked content"
    else:
        # A modified block is still ours, but never consume neighbouring bytes.
        pattern = re.compile(r"(?m)^" + re.escape(entry.begin) + r"\r?\n.*?^" + re.escape(entry.end) + r"(?:\r?\n|$)", re.S | re.M)
        if text.count(entry.begin) != 1 or text.count(entry.end) != 1:
            raise ThemeError(f"{path}: ambiguous/incomplete theme markers; repair them before removal")
        new, count = pattern.subn("", text, count=1)
        if count != 1:
            raise ThemeError(f"{path}: cannot safely remove modified theme markers")
    backup(lay, path)
    if entry.created and new == "":
        path.unlink()
    else:
        atomic_write(path, new, path.stat().st_mode & 0o777)
    return f"removed theme block from {path}"


def remove_app(lay: Layout, manifest: Manifest, app: str) -> list[str]:
    notes = []
    for entry in list(manifest.edits):
        if entry.component != component(app):
            continue
        notes.append(remove_edit(lay, entry))
        manifest.edits.remove(entry)
        manifest.save(lay.manifest)
    entries = manifest.component_files(component(app))
    for entry in entries:
        safe_path(Path(entry.path))
    report = remove_files(manifest, entries)
    notes += ["removed " + p for p in report.removed]
    notes += ["kept user-modified theme file: " + p for p in report.kept_modified]
    if not report.kept_modified:
        manifest.themes.pop(app, None)
    for directory in (lay.data / "themes", lay.config.parent / CONFIG_DIRS.get(app, app)):
        prune_dirs(manifest, directory, report)
    manifest.save(lay.manifest)
    return notes


def status(lay: Layout, manifest: Manifest | None) -> list[dict]:
    rows = []
    for app in (*SUPPORTED, *DEFERRED):
        directory = lay.config.parent / CONFIG_DIRS.get(app, app)
        binary = {"hyprland": "Hyprland", "gtk3": "gtk-query-settings", "gtk4": "gtk4-demo"}.get(app, app)
        detected = directory.is_dir() or shutil.which(binary) is not None
        if app == "firefox":
            detected = detected or (lay.home / ".mozilla/firefox").is_dir()
        record = manifest.themes.get(app) if manifest else None
        files = manifest.component_files(component(app)) if manifest else []
        edits = [e for e in manifest.edits if e.component == component(app)] if manifest else []
        intact = bool(record and files) and all(Path(f.path).is_file() and not Path(f.path).is_symlink() and sha256(Path(f.path)) == f.sha256 for f in files)
        intact = intact and all(Path(e.file).is_file() and e.inserted in Path(e.file).read_bytes().decode("utf-8", errors="replace") for e in edits)
        rows.append({"app": app, "supported": app in SUPPORTED, "detected": detected, "applied": intact,
                     "recorded": bool(record or files or edits), "scheme": record.get("scheme") if record else None,
                     "direction": record.get("direction") if record else None,
                     "note": record["note"] if record else DEFERRED.get(app, "Optional; not applied")})
    return rows
