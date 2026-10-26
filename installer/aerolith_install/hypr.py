"""Hyprland integration: an AEROLITH-owned fragment plus one include block.

Hyprland 0.55+ reads ~/.config/hypr/hyprland.lua when it exists, otherwise
hyprland.conf (hyprlang, deprecated). AEROLITH writes its binds and
(optionally) its autostart into its own file under ~/.config/hypr/aerolith/
and adds a single marker-delimited block to the main config that includes
it. In Lua the include is `pcall(require, ...)`, so deleting the fragment can
never break the user's config.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

from .manifest import EditEntry, Manifest, atomic_write
from .paths import Layout

BEGIN_LUA = "-- >>> AEROLITH (managed block: remove with `aerolith uninstall`)"
END_LUA = "-- <<< AEROLITH"
BEGIN_CONF = "# >>> AEROLITH (managed block: remove with `aerolith uninstall`)"
END_CONF = "# <<< AEROLITH"

# name -> (modifiers, key, description). Function keys are rarely bound, so
# the less frequent bays use them to avoid stepping on existing binds.
DEFAULT_BINDS: dict[str, tuple[str, str, str]] = {
    "command": ("SUPER", "SPACE", "AEROLITH: Command Core"),
    "navigator": ("SUPER", "TAB", "AEROLITH: Spatial Navigator"),
    "systems": ("SUPER", "F9", "AEROLITH: Systems Bay"),
    "signal": ("SUPER", "F10", "AEROLITH: Signal Rack"),
    "routines": ("SUPER", "F11", "AEROLITH: Routine Console"),
}
AI_BIND = ("ai", ("SUPER", "F12", "AEROLITH: AI Bridge"))
MEDIA_BINDS: dict[str, tuple[str, str, str]] = {
    "volume-up": ("", "XF86AudioRaiseVolume", "AEROLITH: volume up"),
    "volume-down": ("", "XF86AudioLowerVolume", "AEROLITH: volume down"),
    "mute": ("", "XF86AudioMute", "AEROLITH: mute"),
    "play-pause": ("", "XF86AudioPlay", "AEROLITH: play/pause"),
    "brightness-up": ("", "XF86MonBrightnessUp", "AEROLITH: brightness up"),
    "brightness-down": ("", "XF86MonBrightnessDown", "AEROLITH: brightness down"),
}

MODMASK = {"SHIFT": 1, "CAPS": 2, "CTRL": 4, "CONTROL": 4, "ALT": 8, "MOD2": 16, "MOD3": 32, "SUPER": 64, "WIN": 64, "LOGO": 64, "MOD4": 64, "MOD5": 128}


@dataclass
class Bind:
    name: str
    mods: str
    key: str
    description: str

    @property
    def combo(self) -> str:
        return " + ".join([m for m in self.mods.split() if m] + [self.key])

    def modmask(self) -> int:
        return sum(MODMASK.get(m.upper(), 0) for m in self.mods.split())


def detect_dialect(lay: Layout) -> tuple[str, Path | None]:
    lua = lay.hypr / "hyprland.lua"
    conf = lay.hypr / "hyprland.conf"
    if lua.is_file():
        return "lua", lua
    if conf.is_file():
        return "hyprlang", conf
    return "none", None


def lua_string(s: str) -> str:
    out = ['"']
    for b in s.encode("utf-8"):
        if b == 0x5C:
            out.append("\\\\")
        elif b == 0x22:
            out.append('\\"')
        elif 0x20 <= b < 0x7F:
            out.append(chr(b))
        else:
            out.append(f"\\{b:03d}")
    out.append('"')
    return "".join(out)


def shell_quote(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"


def launch_command(shell_dir: Path) -> str:
    qs = shutil.which("qs") or shutil.which("quickshell") or "qs"
    return f"{shell_quote(qs)} -p {shell_quote(str(shell_dir))}"


def fragment(dialect: str, binds: list[Bind], autostart_cmd: str | None) -> str:
    stamp = time.strftime("%Y-%m-%d")
    if dialect == "lua":
        lines = [
            "-- AEROLITH Hyprland integration. Managed file, written by `aerolith` on " + stamp + ".",
            "-- Edits here are replaced on the next `aerolith hypr apply`; change keys in",
            "-- ~/.config/aerolith/hypr-binds.json instead. Remove with `aerolith uninstall`.",
            "",
        ]
        if autostart_cmd:
            lines += [
                'hl.on("hyprland.start", function()',
                f"  hl.exec_cmd({lua_string(autostart_cmd)})",
                "end)",
                "",
            ]
        for b in binds:
            lines.append(f"hl.bind({lua_string(b.combo)}, hl.dsp.global({lua_string('aerolith:' + b.name)}), {{ description = {lua_string(b.description)} }})")
        return "\n".join(lines) + "\n"
    if dialect == "hyprlang":
        lines = [
            "# AEROLITH Hyprland integration. Managed file, written by `aerolith` on " + stamp + ".",
            "# Edits here are replaced on the next `aerolith hypr apply`. Remove with `aerolith uninstall`.",
            "",
        ]
        if autostart_cmd:
            lines += [f"exec-once = {autostart_cmd}", ""]
        for b in binds:
            lines.append(f"bindd = {b.mods}, {b.key}, {b.description}, global, aerolith:{b.name}")
        return "\n".join(lines) + "\n"
    raise ValueError(f"no Hyprland config dialect: {dialect}")


def fragment_path(lay: Layout, dialect: str) -> Path:
    return lay.hypr_fragment_dir / ("aerolith.lua" if dialect == "lua" else "aerolith.conf")


def include_block(lay: Layout, dialect: str) -> tuple[str, str, str]:
    if dialect == "lua":
        return BEGIN_LUA, 'pcall(require, "aerolith/aerolith")', END_LUA
    return BEGIN_CONF, f"source = {fragment_path(lay, dialect)}", END_CONF


def has_block(text: str, begin: str) -> bool:
    return begin in text


def add_include(main: Path, lay: Layout, dialect: str, manifest: Manifest) -> EditEntry:
    """Append the include block to the main config after backing it up."""
    text = main.read_bytes().decode("utf-8")
    begin, body, end = include_block(lay, dialect)
    existing = next((e for e in manifest.edits if e.file == str(main)), None)
    if has_block(text, begin):
        if existing:
            return existing
        raise RuntimeError(f"{main} already contains an AEROLITH block that is not in the manifest; remove it by hand first")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = lay.backups / stamp / main.name
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(main, backup)
    sep = "" if text.endswith("\n") or text == "" else "\n"
    inserted = sep + "\n" + begin + "\n" + body + "\n" + end + "\n"
    atomic_write(main, text + inserted, main.stat().st_mode & 0o777)
    entry = EditEntry(file=str(main), begin=begin, end=end, backup=str(backup), inserted=inserted)
    manifest.edits.append(entry)
    return entry


def remove_include(entry: EditEntry) -> str:
    """Remove exactly the marker block. Returns what happened."""
    p = Path(entry.file)
    if not p.is_file():
        return f"{p} no longer exists; nothing to remove"
    text = p.read_bytes().decode("utf-8")
    if entry.inserted and text.count(entry.inserted) == 1:
        atomic_write(p, text.replace(entry.inserted, "", 1), p.stat().st_mode & 0o777)
        return f"removed the AEROLITH block from {p}"
    # add_include appended "\n" + block; take that blank line with it so the
    # file returns to its previous content.
    pattern = re.compile(r"\n?" + re.escape(entry.begin) + r"\n.*?" + re.escape(entry.end) + r"(?:\n|$)", re.S)
    new, n = pattern.subn("", text, count=1)
    if n == 0:
        return f"AEROLITH block not found in {p}; it was already removed"
    atomic_write(p, new, p.stat().st_mode & 0o777)
    return f"removed the AEROLITH block from {p}"


# --- conflicts ------------------------------------------------------------------

def running_binds() -> list[dict] | None:
    """Binds from a running Hyprland (`hyprctl -j binds`), or None."""
    if not shutil.which("hyprctl"):
        return None
    try:
        r = subprocess.run(["hyprctl", "-j", "binds"], capture_output=True, text=True, timeout=5, check=False)
        data = json.loads(r.stdout)
        return data if isinstance(data, list) else None
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return None


def conflicts(binds: list[Bind], existing: list[dict] | None, config_text: str) -> dict[str, str]:
    """Return {bind name: description of what already uses that key}."""
    found: dict[str, str] = {}
    for b in binds:
        if existing is not None:
            for e in existing:
                if not isinstance(e, dict):
                    continue
                if str(e.get("key", "")).lower() == b.key.lower() and int(e.get("modmask", -1)) == b.modmask():
                    if str(e.get("arg", "")) == f"aerolith:{b.name}":
                        continue
                    found[b.name] = f"{b.combo} is bound to {e.get('dispatcher', '?')} {e.get('arg', '')}".strip()
                    break
        else:
            # Best effort when Hyprland is not running: look for the combo in
            # the config text (Lua and hyprlang spellings, $mainMod as SUPER).
            mods = [m for m in b.mods.split() if m]
            lua = r'hl\.bind\(\s*"\s*' + r"\s*\+\s*".join(map(re.escape, mods + [b.key])) + r'\s*"'
            conf_mods = r"\s*".join(rf"(?:{re.escape(m)}|\$mainMod)" if m == "SUPER" else re.escape(m) for m in mods)
            conf = rf"^\s*bind\w*\s*=\s*{conf_mods}\s*,\s*{re.escape(b.key)}\s*,(?!.*aerolith:)"
            if re.search(lua, config_text, re.I) or re.search(conf, config_text, re.I | re.M):
                found[b.name] = f"{b.combo} appears in your Hyprland config"
    return found


def default_binds(with_ai: bool, with_media: bool) -> list[Bind]:
    out = [Bind(n, *v) for n, v in DEFAULT_BINDS.items()]
    if with_ai:
        out.append(Bind(AI_BIND[0], *AI_BIND[1]))
    if with_media:
        out += [Bind(n, *v) for n, v in MEDIA_BINDS.items()]
    return out
