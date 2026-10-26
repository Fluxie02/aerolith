"""`aerolith`: install, inspect, maintain and remove AEROLITH.

Every changing command plans first, prints the plan, asks once, then acts and
records ownership in the manifest. --dry-run stops after the plan.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from . import __version__, checks, hypr, packages, themes
from .manifest import Manifest, RemovalReport, atomic_write, copy_tree, prune_dirs, remove_files, sha256
from .paths import Layout, layout, source_root, tilde
from .schema import validate_file
from .ui import NeedAnswer, Ui

AI_CHOICES = [
    (
        "claude",
        "Claude: use the Claude Code CLI",
        "Requests go to Anthropic under your Claude account (Pro/Max/Team/Enterprise/Console\n"
        "or an API provider). Needs the `claude` CLI; AEROLITH can run the official installer.",
    ),
    (
        "codex",
        "Codex: use the OpenAI Codex CLI",
        "Requests go to OpenAI under your Codex sign-in. Needs the `codex` CLI\n"
        "(Arch package openai-codex); AEROLITH can install it with pacman.",
    ),
    (
        "custom",
        "Custom: a program you provide",
        "Any executable that speaks AEROLITH's documented adapter protocol\n"
        "(docs/INTEGRATIONS.md). You are responsible for where it sends data.",
    ),
    (
        "none",
        "None: no AI integration",
        "Installs the complete shell without any AI module, configuration,\n"
        "background process or network request. You will not be asked again.",
    ),
]

STARTUP_CHOICES = [
    ("hyprland", "Start with Hyprland", "Adds an autostart line to AEROLITH's own Hyprland fragment."),
    ("systemd", "systemd user service", "Installs aerolith.service bound to graphical-session.target (for uwsm setups)."),
    ("manual", "I will start it myself", "No autostart. Run `aerolith run` or `qs -p <shell dir>` yourself."),
]

DIRECTION_CHOICES = [
    ("piyti", "PIYTI (default)", "App windows become part of the shell instrument. The forward design."),
    ("thears", "THEARS", "Apps take on SHEAR's look. The maintained original direction."),
]
DIRECTIONS = tuple(c[0] for c in DIRECTION_CHOICES)
INTENSITY_CHOICES = [
    ("saturated", "Saturated (default)", "The standard information density."),
    ("insane", "Insane", "An even denser interface with more information visible."),
]
INTENSITIES = tuple(c[0] for c in INTENSITY_CHOICES)


class Abort(RuntimeError):
    pass


@dataclass
class Plan:
    lines: list[str] = field(default_factory=list)
    actions: list[tuple[str, Callable[[], None]]] = field(default_factory=list)

    def add(self, line: str, action: Callable[[], None] | None = None) -> None:
        self.lines.append(line)
        if action:
            self.actions.append((line, action))


# --- helpers -------------------------------------------------------------------

def read_installation(lay: Layout) -> dict:
    """Installation metadata is separate from the live Settings schema."""
    try:
        data = json.loads(lay.installation_file.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as exc:
        raise Abort(f"{tilde(lay.installation_file)} is not valid JSON ({exc}); fix it first") from exc
    if not isinstance(data, dict):
        raise Abort(f"{tilde(lay.installation_file)} does not contain a JSON object; fix it first")
    return data


def require_source(args: argparse.Namespace) -> Path:
    src = Path(args.source).resolve() if getattr(args, "source", None) else source_root()
    if not src or not (src / "shell" / "shell.qml").is_file():
        raise Abort("cannot find the AEROLITH source files; run from the repository checkout or pass --source")
    return src


def ai_bridge_source(src: Path | None, lay: Layout) -> Path | None:
    for cand in ([src / "ai-bridge"] if src else []) + [Path("/usr/share/aerolith/ai-bridge")]:
        if (cand / "aerolith_ai" / "__init__.py").is_file() and (cand / "qml" / "AiModule.qml").is_file():
            return cand
    return None


def import_ai_config(lay: Layout, src: Path | None):
    """Import the bridge's own config module, so ai.json is validated and
    written by exactly the code that reads it."""
    for cand in [lay.ai_module / "bridge"] + ([src / "ai-bridge"] if src else []):
        if (cand / "aerolith_ai" / "config.py").is_file():
            if str(cand) not in sys.path:
                sys.path.insert(0, str(cand))
            from aerolith_ai import config as aicfg  # noqa: PLC0415

            return aicfg
    raise Abort("the AI Bridge files are not available; reinstall from the source tree with --ai")


def load_manifest(lay: Layout) -> Manifest | None:
    try:
        m = Manifest.load(lay.manifest)
    except (ValueError, TypeError) as exc:
        raise Abort(f"invalid ownership manifest: {exc}") from None
    if m is not None and m.mode != lay.mode:
        if m.mode == "user":
            raise Abort(
                "AEROLITH is installed for this user from a source checkout; manage it with ~/.local/bin/aerolith, "
                "or remove it with `~/.local/bin/aerolith uninstall` before setting up the packaged version"
            )
        raise Abort(
            "AEROLITH is set up for this user from the system package; manage it with /usr/bin/aerolith, "
            "or run `/usr/bin/aerolith uninstall` before installing from a checkout"
        )
    return m


def _own_pids():
    """PIDs of this user's processes (a packaged shell path is shared by all users)."""
    uid = os.getuid()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            if os.stat(f"/proc/{pid}").st_uid == uid:
                yield pid
        except OSError:
            continue


def shell_running(lay: Layout) -> bool:
    for pid in _own_pids():
        try:
            cmd = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
        except OSError:
            continue
        if any(os.path.basename(c.decode(errors="replace")) in ("qs", "quickshell") for c in cmd[:1]) and str(lay.shell).encode() in cmd:
            return True
    return False


def kill_bridge_processes(lay: Layout) -> int:
    """SIGTERM AEROLITH's own AI bridge processes (matched by path)."""
    target = str(lay.ai_module / "bridge").encode()
    n = 0
    for pid in _own_pids():
        if int(pid) == os.getpid():
            continue
        try:
            if target in Path(f"/proc/{pid}/cmdline").read_bytes():
                os.kill(int(pid), signal.SIGTERM)
                n += 1
        except (OSError, ProcessLookupError):
            continue
    return n


def bind_overrides(lay: Layout, binds: list[hypr.Bind]) -> list[hypr.Bind]:
    """Apply ~/.config/aerolith/hypr-binds.json: {"command": "SUPER + SPACE" | null}."""
    p = lay.config / "hypr-binds.json"
    if not p.is_file():
        return binds
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise Abort(f"{p}: invalid JSON ({exc.msg})") from None
    out = []
    for b in binds:
        if b.name in data:
            v = data[b.name]
            if v is None:
                continue
            parts = [s.strip() for s in str(v).split("+") if s.strip()]
            if not parts:
                raise Abort(f"{p}: empty key for {b.name}")
            b = hypr.Bind(b.name, " ".join(parts[:-1]), parts[-1], b.description)
        out.append(b)
    return out


def starter_config(lay: Layout) -> str:
    return json.dumps(
        {
            "$schema": "file://" + str(lay.shell / "schema" / "config.schema.json"),
            "schemaVersion": 1,
            "strip": {"edge": "top", "telemetry": "alert"},
            "theme": {"density": "standard", "motion": "full"},
        },
        indent=2,
    ) + "\n"


def read_live_config(lay: Layout) -> dict:
    data = themes.read_object(lay.config_file)
    if not isinstance(data.get("theme", {}), dict):
        raise Abort(f"{tilde(lay.config_file)}: theme must be an object; fix it first")
    return data


def write_theme_values(lay: Layout, data: dict, values: dict) -> None:
    """Atomically update live settings, retaining every unrelated key."""
    data.setdefault("theme", {}).update(values)
    data.setdefault("schemaVersion", 1)
    atomic_write(lay.config_file, json.dumps(data, indent=2) + "\n")


def scheme_choices(lay: Layout, manifest: Manifest | None, source: Path | None = None) -> list[tuple[str, str, str]]:
    root = themes.assets_root(lay, manifest or Manifest(), source)
    rows = themes.read_object(root / "schemes/index.json").get("schemes")
    if (not isinstance(rows, list) or not rows
        or any(not isinstance(row, dict) or not isinstance(row.get("id"), str)
               or not isinstance(row.get("name"), str) for row in rows)):
        raise Abort("invalid or missing scheme catalog")
    return [(r["id"], r["name"] + (" (default)" if r["id"] == "limb" else ""), r.get("description", "")) for r in rows]


LAUNCHER = """#!/bin/sh
# AEROLITH maintenance tool. Managed by AEROLITH; removed by `aerolith uninstall`.
exec python3 -I -B "{cli}/aerolith" "$@"
"""

CLI_ENTRY = """#!/usr/bin/env -S python3 -I -B
import os, sys
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from aerolith_install.cli import main
sys.exit(main(sys.argv[1:]))
"""

SERVICE = """[Unit]
Description=AEROLITH desktop shell
Documentation=file://{shell}/../README.md
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart={qs} -p {shell}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
"""


# --- install ----------------------------------------------------------------------

def plan_ai(args: argparse.Namespace, ui: Ui, lay: Layout, src: Path, manifest: Manifest, plan: Plan, choice: str) -> None:
    """Add the AI part of an install/switch to the plan."""
    if lay.system:
        # The module is the aerolith-ai-bridge package's; only ai.json is ours.
        bridge_src = None
        if not (lay.ai_module / "AiModule.qml").is_file():
            raise Abort(
                "the AI Bridge is a separate package: build and install aerolith-ai-bridge (packaging/arch, "
                "`makepkg`), then run this again. Nothing was changed"
            )
    else:
        bridge_src = ai_bridge_source(src, lay)
        if bridge_src is None:
            raise Abort("AI Bridge sources not found (ai-bridge/); cannot install an AI provider from here")
    aicfg = import_ai_config(lay, src)
    data: dict = {"schemaVersion": 1, "provider": choice, "enabled": True, "timeoutSeconds": 90}

    if choice in ("claude", "codex"):
        exe = packages.find_tool(choice)
        if exe:
            ui.ok(f"{choice} found: {exe} ({packages.tool_version(exe)}); AEROLITH will use it and will never uninstall it")
        else:
            ui.warn(f"{choice} is not installed")
            if choice == "claude":
                ui.say("  Claude Code's documented Linux installer is: curl -fsSL https://claude.ai/install.sh | bash")
                ui.say("  It installs to ~/.local/bin/claude and ~/.local/share/claude. AEROLITH would download it,")
                ui.say("  show its SHA-256, and run it only after you confirm. Requires network access.")
                want = args.install_provider if args.install_provider is not None else ui.confirm("Download the official Claude Code installer now?", default=False)
                if want:
                    plan.add("download and run the official Claude Code installer (after showing its hash)", lambda: install_claude(ui, manifest))
                else:
                    ui.info("Claude Code can be installed later; AI requests will report it as missing until then")
            else:
                step = packages.pacman_install_step(["openai-codex"])
                ui.say("  Codex is packaged in the Arch repositories. Command: " + " ".join(step.argv))
                want = args.install_provider if args.install_provider is not None else ui.confirm("Install openai-codex with pacman now?", default=False)
                if want:
                    plan.add("install openai-codex with pacman (sudo)", lambda: install_pkgs(["openai-codex"], manifest))
                else:
                    ui.info("Codex can be installed later; AI requests will report it as missing until then")
    elif choice == "custom":
        exe = ui.ask("Absolute path of the custom provider program:", args.custom_exec, lambda v: None if os.path.isabs(v) else "must be an absolute path")
        try:
            aicfg.check_executable(exe, label="custom provider")
        except aicfg.ConfigError as exc:
            raise Abort(str(exc)) from None
        protocol = args.custom_protocol or ui.choose(
            "Protocol the program speaks:",
            [("aerolith-v1", "aerolith-v1 (JSON request on stdin, JSON reply)", "Can propose actions."), ("text", "text (prompt on stdin, plain reply)", "Answers only; no proposals.")],
        )
        name = args.custom_name or "custom"
        ui.warn(f"AEROLITH will run {exe} with your prompt. It cannot know where that program sends data.")
        if not ui.confirm("Trust this program for AI requests?", default=False):
            raise Abort("custom provider not trusted; nothing changed")
        data["custom"] = {"name": name, "executable": exe, "args": [], "protocol": protocol}

    cfg = aicfg.parse(data)
    # Updating with the same provider keeps the user's ai.json (timeouts,
    # context switches) instead of resetting it.
    keep_existing = manifest.ai_provider == choice and lay.ai_file.is_file() and getattr(args, "cmd", "") == "install"

    def install_module() -> None:
        lay.ai_module.mkdir(parents=True, exist_ok=True)
        manifest.record_dir(lay.ai_module)
        shutil.copy2(bridge_src / "qml" / "AiModule.qml", lay.ai_module / "AiModule.qml")
        manifest.record_file(lay.ai_module / "AiModule.qml", "ai")
        bdir = lay.ai_module / "bridge"
        bdir.mkdir(exist_ok=True)
        manifest.record_dir(bdir)
        shutil.copy2(bridge_src / "aerolith-ai-bridge", bdir / "aerolith-ai-bridge")
        (bdir / "aerolith-ai-bridge").chmod(0o755)
        manifest.record_file(bdir / "aerolith-ai-bridge", "ai")
        copy_tree(bridge_src / "aerolith_ai", bdir / "aerolith_ai", manifest, "ai")

    def write_ai_json() -> None:
        aicfg.write(cfg, lay.ai_file)
        manifest.record_file(lay.ai_file, "ai", "config")
        manifest.ai_provider = choice

    if lay.system:
        plan.add(f"use the AI Bridge from the aerolith-ai-bridge package ({lay.ai_module})")
    else:
        plan.add(f"install the AI Bridge module to {tilde(lay.ai_module)}", install_module)
    if keep_existing:
        plan.add(f"keep your existing {tilde(lay.ai_file)}")
    else:
        plan.add(f"write {tilde(lay.ai_file)} (provider {choice}; no credentials; desktop context off)", write_ai_json)


def install_claude(ui: Ui, manifest: Manifest) -> None:
    tmp = packages.temp_dir()
    try:
        script, digest = packages.download_claude_installer(tmp)
        if script is None:
            ui.warn("could not download the Claude Code installer: " + digest)
            return
        ui.say(f"  Downloaded {packages.CLAUDE_INSTALLER_URL} ({script.stat().st_size} bytes, sha256 {digest})")
        if not ui.confirm("Run it now?", default=False):
            ui.info("skipped; install Claude Code later with the command above")
            return
        ok, msg = packages.run_claude_installer(script, manifest)
        (ui.ok if ok else ui.warn)("Claude Code installer " + ("finished" if ok else "failed: " + msg))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def install_pkgs(names: list[str], manifest: Manifest) -> None:
    ok, msg = packages.install_packages(names, manifest)
    if not ok:
        raise Abort(f"package installation failed ({msg}); nothing after this step was done")


def plan_hypr(args: argparse.Namespace, ui: Ui, lay: Layout, manifest: Manifest, plan: Plan, with_ai: bool, startup: str) -> None:
    dialect, main = hypr.detect_dialect(lay)
    if args.no_hypr or dialect == "none":
        if dialect == "none":
            ui.warn(f"no Hyprland config found in {tilde(lay.hypr)}; skipping Hyprland integration")
        manifest.hypr_dialect = "none"
        return
    binds = bind_overrides(lay, hypr.default_binds(with_ai, args.media_keys))
    existing_text = main.read_text(encoding="utf-8") if main else ""
    found = hypr.conflicts(binds, hypr.running_binds(), existing_text)
    if found:
        ui.warn("keybinding conflicts:")
        for name, what in found.items():
            ui.say(f"    aerolith:{name}: {what}")
        keep = ui.confirm("Skip the conflicting AEROLITH binds (recommended) instead of adding them anyway?", default=True)
        if keep:
            binds = [b for b in binds if b.name not in found]
            ui.info("skipped; set your own keys in ~/.config/aerolith/hypr-binds.json and run `aerolith hypr apply`")
    autostart = hypr.launch_command(lay.shell) if startup == "hyprland" else None
    frag = hypr.fragment(dialect, binds, autostart)
    fpath = hypr.fragment_path(lay, dialect)
    begin, body, end = hypr.include_block(lay, dialect)
    ui.say(f"\n  AEROLITH's own file {tilde(fpath)}:")
    ui.code(frag)
    ui.say(f"  One block appended to YOUR {tilde(main)} (a backup is taken first):")
    ui.code(f"{begin}\n{body}\n{end}")
    if not ui.confirm(f"Add this include block to {main.name}?", default=None if not args.yes else True):
        ui.info("not editing your Hyprland config; include the fragment yourself (see docs/INSTALLATION.md)")
        manifest.hypr_dialect = dialect

        def write_fragment_only() -> None:
            atomic_write(fpath, frag)
            manifest.record_dir(lay.hypr_fragment_dir)
            manifest.record_file(fpath, "integration", "fragment")

        plan.add(f"write {tilde(fpath)} (not included anywhere)", write_fragment_only)
        return

    def apply() -> None:
        atomic_write(fpath, frag)
        manifest.record_dir(lay.hypr_fragment_dir)
        manifest.record_file(fpath, "integration", "fragment")
        hypr.add_include(main, lay, dialect, manifest)
        manifest.hypr_dialect = dialect

    plan.add(f"write {tilde(fpath)} and include it from {tilde(main)} (backup in {tilde(lay.backups)})", apply)


def cmd_install(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    src = require_source(args)
    existing = load_manifest(lay)
    manifest = existing or Manifest(aerolith_version=__version__, source=str(src))
    manifest.aerolith_version = __version__
    manifest.source = str(src)
    manifest.mode = lay.mode

    ui.title(f"AEROLITH {__version__} · install for {os.environ.get('USER', 'this user')}")
    if lay.system:
        ui.info(f"using the packaged shell in {lay.shell} (owned by pacman; only your own files are written)")
    if existing:
        ui.info(f"existing installation found (AI: {existing.ai_provider}); this updates it")

    installation = read_installation(lay)
    current_direction = installation.get("direction")
    if "direction" in installation and current_direction not in DIRECTIONS and args.direction is None:
        raise Abort(f"{tilde(lay.installation_file)} has an invalid direction; fix it or pass --direction piyti|thears")
    if args.direction is not None:
        direction = args.direction
    elif current_direction in DIRECTIONS:
        direction = current_direction
    else:
        ui.title("Application direction")
        direction = ui.choose("Choose once during installation (no Settings control):", DIRECTION_CHOICES, default="piyti")

    # Live settings are validated before any install action, even with flags.
    config = read_live_config(lay)
    config_existed = lay.config_file.exists()
    stored_theme = config.get("theme", {})
    spectra = scheme_choices(lay, manifest, src)
    chosen = {}
    updates = {}
    for key, options, default in (("intensity", INTENSITY_CHOICES, "saturated"), ("scheme", spectra, "limb")):
        explicit = getattr(args, key)
        current = stored_theme.get(key, default)
        if explicit is not None:
            value = ui.choose(f"Choose {key}:", options, given=explicit)
        elif current not in [o[0] for o in options]:
            raise Abort(f"config.json has an invalid theme.{key}; fix it or pass --{key}")
        elif key in stored_theme or existing:
            value = current
        else:
            value = ui.choose(f"Choose {key} (also available live in Settings):", options, default=default)
        chosen[key] = value
        if explicit is not None or value != current or not config_existed:
            updates[key] = value

    # 1. environment
    ui.title("Environment")
    results = checks.run_checks(lay)
    for c in results:
        {"ok": ui.ok, "warn": ui.warn, "fail": ui.fail, "info": ui.info}[c.status](f"{c.name}: {c.detail}")
    plan = Plan()
    missing = checks.missing_packages(results)
    if missing:
        step = packages.pacman_install_step(missing)
        ui.say("\nRequired packages are missing. Command: " + " ".join(step.argv))
        want = args.install_deps if args.install_deps is not None else ui.confirm("Install them now?", default=False)
        if not want:
            raise Abort("required packages are missing: " + ", ".join(missing) + ". Install them and run this again.")
        plan.add("install " + ", ".join(missing) + " with pacman (sudo)", lambda: install_pkgs(missing, manifest))
    elif checks.failed(results):
        raise Abort("environment check failed: " + "; ".join(c.name + " " + c.detail for c in checks.failed(results)))

    # 2. AI provider: explicit choice, never defaulted.
    ui.title("AI integration")
    current = existing.ai_provider if existing else None
    if args.ai is None and current is not None and not ui.interactive:
        choice = current
    else:
        choice = ui.choose("Choose how AEROLITH should handle AI (you can change this later with `aerolith ai`):", AI_CHOICES, args.ai)
    if choice == "none":
        ui.ok("no AI integration: no AI files, configuration, processes or network requests")
        if existing and existing.ai_provider != "none":
            plan.add("remove the existing AI integration", lambda: ai_remove(lay, manifest, ui, remove_provider=False, report=False))
    else:
        if existing and existing.ai_provider not in ("none", choice):
            plan.add(f"switch AI provider from {existing.ai_provider} to {choice}")
        plan_ai(args, ui, lay, src, manifest, plan, choice)

    # 3. startup and Hyprland
    ui.title("Startup and Hyprland")
    startup = ui.choose("How should AEROLITH start?", STARTUP_CHOICES, args.startup)
    manifest.startup = startup
    plan_hypr(args, ui, lay, manifest, plan, choice != "none", startup)

    selected_themes = [] if args.no_themes else (
        list(dict.fromkeys(a.strip() for a in args.themes.split(",") if a.strip()))
        if args.themes is not None else ui.select_themes(themes.SUPPORTED)
    )
    if args.no_hypr and "hyprland" in selected_themes:
        raise Abort("--no-hypr conflicts with --themes hyprland; omit one of them")
    theme_selection = themes.selection(lay, scheme=chosen["scheme"], direction=direction) if selected_themes else None
    theme_root = themes.assets_root(lay, manifest, src) if selected_themes else None
    theme_plans = [themes.prepare_app(lay, manifest, theme_root, app, *theme_selection) for app in selected_themes]

    # 4. core files
    def install_core() -> None:
        old_core = [f for f in manifest.component_files("core")]
        lay.data.mkdir(parents=True, exist_ok=True)
        manifest.record_dir(lay.data)
        written = copy_tree(src / "shell", lay.shell, manifest, "core", exclude=("__pycache__", "ai"))
        lay.cli.mkdir(parents=True, exist_ok=True)
        manifest.record_dir(lay.cli)
        written += copy_tree(src / "installer" / "aerolith_install", lay.cli / "aerolith_install", manifest, "core")
        if (src / "themes/schemes/index.json").is_file():
            written += copy_tree(src / "themes/schemes", lay.data / "theme-assets/schemes", manifest, "core")
            manifest.record_dir(lay.data / "theme-assets")
        atomic_write(lay.cli / "aerolith", CLI_ENTRY, 0o755)
        manifest.record_file(lay.cli / "aerolith", "core", "launcher")
        atomic_write(lay.launcher, LAUNCHER.format(cli=lay.cli), 0o755)
        manifest.record_file(lay.launcher, "core", "launcher")
        written += [str(lay.cli / "aerolith"), str(lay.launcher)]
        if (src / "README.md").is_file():
            shutil.copy2(src / "README.md", lay.data / "README.md")
            manifest.record_file(lay.data / "README.md", "core")
            written.append(str(lay.data / "README.md"))
        # On update, remove files the new version no longer ships (only if
        # unmodified; see remove_files).
        keep = set(written)
        stale = [f for f in old_core if f.path not in keep]
        if stale:
            rep = remove_files(manifest, stale)
            for d in (lay.shell, lay.cli):
                prune_dirs(manifest, d, rep)

    def install_config() -> None:
        lay.config.mkdir(parents=True, exist_ok=True)
        if not lay.config_file.exists():
            atomic_write(lay.config_file, starter_config(lay))
            manifest.record_file(lay.config_file, "config", "config")

    # Core files go after any dependency installation, before the AI module
    # (which lives inside the shell directory).
    pos = 1 if missing else 0
    if lay.system:
        plan.lines.insert(pos, f"run the shell from {lay.shell} (the aerolith package; `pacman -Syu` updates it)")
    else:
        plan.lines.insert(pos, f"copy the shell to {tilde(lay.shell)} and the `aerolith` tool to {tilde(lay.launcher)}")
        plan.actions.insert(pos, ("core", install_core))
    if lay.config_file.exists():
        plan.add(f"keep your existing settings in {tilde(lay.config_file)}")
    else:
        plan.add(f"create {tilde(lay.config_file)} with a few common settings", install_config)

    def install_live_settings() -> None:
        write_theme_values(lay, read_live_config(lay), updates)
        # Retain modified-file protection for an existing user's config.
        if not config_existed:
            manifest.record_file(lay.config_file, "config", "config")

    plan.add(f"live settings: intensity {chosen['intensity']}; scheme {chosen['scheme']} ({tilde(lay.config_file)})",
             install_live_settings if updates else None)

    def install_direction() -> None:
        # Keep unrelated metadata and all live user settings. Reading above
        # refuses broken JSON before any planned action can run.
        installation["direction"] = direction
        atomic_write(lay.installation_file, json.dumps(installation, indent=2) + "\n")
        manifest.record_file(lay.installation_file, "config", "config")

    if startup == "systemd":
        def install_service() -> None:
            qs = shutil.which("qs") or "/usr/bin/qs"
            atomic_write(lay.service, SERVICE.format(qs=qs, shell=lay.shell))
            manifest.record_file(lay.service, "integration", "service")

        plan.add(f"install {tilde(lay.service)} (enable it with: systemctl --user enable aerolith.service)", install_service)
    plan.add(f"application direction: {direction} (startup only; {tilde(lay.installation_file)})", install_direction)
    for deployment in theme_plans:
        for line in deployment.describe():
            plan.add(line)
        # Startup integration may have added its own block since preflight.
        # Re-read, preserving it, before adding the separate theme block.
        def apply_theme(app=deployment.app):
            fresh = themes.prepare_app(lay, manifest, theme_root, app, *theme_selection)
            themes.execute(lay, manifest, fresh)
        plan.actions.append(("theme:" + deployment.app, apply_theme))
    plan.add(f"record ownership in {tilde(lay.manifest)}")

    # 5. summary
    ui.title("Planned changes")
    for line in plan.lines:
        ui.say("  • " + line)
    ui.say("  Nothing else on your system is changed. No reboot is needed.")
    if args.dry_run:
        ui.info("dry run: nothing was changed")
        return 0
    if not ui.confirm("Proceed?", default=None):
        ui.info("cancelled: nothing was changed")
        return 1

    # 6. execute with rollback
    done: list[str] = []
    snapshot = Manifest.load(lay.manifest) if lay.manifest.exists() else None
    try:
        for label, action in plan.actions:
            action()
            done.append(label)
    except (Abort, OSError, RuntimeError) as exc:
        ui.fail(f"installation stopped: {exc}")
        rollback(lay, manifest, snapshot, ui)
        return 2
    manifest.save(lay.manifest)

    # 7. verify
    ui.title("Verification")
    problems = verify(lay, manifest)
    for p in problems:
        ui.fail(p)
    if not problems:
        ui.ok(f"{len(manifest.files)} files installed and verified")
    errors, warnings = validate_file(lay.config_file, lay.shell / "schema" / "config.schema.json")
    for e in errors:
        ui.fail(e)
    for w in warnings:
        ui.warn(w)
    if choice != "none":
        st = bridge_status(lay)
        if st.get("ok") and st.get("installed"):
            ui.ok(f"AI provider {choice}: {st.get('providerVersion', 'installed')}")
        else:
            ui.warn(f"AI provider {choice}: " + (st.get("problem", {}).get("message") or st.get("error", {}).get("message") or "not ready"))

    # 8. next steps
    ui.title("Done")
    if not lay.system and str(lay.bindir) not in os.environ.get("PATH", "").split(":"):
        ui.warn(f"{tilde(lay.bindir)} is not on your PATH; run {tilde(lay.launcher)} directly or add it")
    ui.say(f"  Start now:        aerolith run   (or: qs -p {tilde(lay.shell)})")
    ui.say("  Status:           aerolith status · aerolith doctor")
    ui.say("  Remove AI only:   aerolith ai remove")
    ui.say("  Uninstall:        aerolith uninstall")
    for e in manifest.edits:
        ui.say(f"  Backup of {Path(e.file).name}: {tilde(e.backup)}")
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") and not shell_running(lay) and (args.start or (args.start is None and ui.interactive and ui.confirm("Start AEROLITH now?", default=False))):
        subprocess.Popen([shutil.which("qs") or "qs", "-p", str(lay.shell), "-d"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        ui.ok("started")
    return 0 if not problems and not errors else 2


def rollback(lay: Layout, manifest: Manifest, snapshot: Manifest | None, ui: Ui) -> None:
    """Undo files created in this run (not present in the previous manifest)."""
    before = {f.path for f in snapshot.files} if snapshot else set()
    for e in list(manifest.edits):
        if e.component.startswith("theme:") and (not snapshot or e not in snapshot.edits):
            ui.info(themes.remove_edit(lay, e))
            manifest.edits.remove(e)
    created = [f for f in manifest.files if f.path not in before]
    report = remove_files(manifest, created, force_modified=True)
    for e in [e for e in manifest.edits if not snapshot or e.file not in {x.file for x in snapshot.edits}]:
        ui.info(hypr.remove_include(e))
        manifest.edits.remove(e)
    prune_dirs(manifest, lay.data, report)
    prune_dirs(manifest, lay.hypr_fragment_dir, report)
    if snapshot:
        snapshot.save(lay.manifest)
    elif lay.manifest.exists():
        lay.manifest.unlink()
    ui.info(f"rolled back {len(report.removed)} new files; your previous state is unchanged")


def verify(lay: Layout, manifest: Manifest) -> list[str]:
    problems = []
    for f in manifest.files:
        p = Path(f.path)
        if not p.exists():
            problems.append(f"missing: {tilde(p)}")
        elif f.kind not in ("config",) and sha256(p) != f.sha256:
            problems.append(f"modified since install: {tilde(p)}")
    for e in manifest.edits:
        p = Path(e.file)
        if not p.is_file() or e.begin not in p.read_text(encoding="utf-8"):
            problems.append(f"include block missing from {tilde(p)}")
    return problems


def bridge_status(lay: Layout, auth: bool = False) -> dict:
    exe = lay.ai_module / "bridge" / "aerolith-ai-bridge"
    if not exe.is_file():
        return {"ok": False, "error": {"message": "AI Bridge not installed"}}
    try:
        r = subprocess.run([str(exe), "status"] + (["--auth"] if auth else []), capture_output=True, text=True, timeout=30, check=False)
        return json.loads(r.stdout)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return {"ok": False, "error": {"message": "AI Bridge did not answer"}}


# --- removal ------------------------------------------------------------------------

def ai_remove(lay: Layout, manifest: Manifest, ui: Ui, *, remove_provider: bool | None, report: bool = True) -> RemovalReport:
    n = kill_bridge_processes(lay)
    if n:
        ui.info(f"stopped {n} running AI bridge process(es)")
    rep = remove_files(manifest, manifest.component_files("ai"), force_modified=True)
    prune_dirs(manifest, lay.ai_module, rep)
    prev = manifest.ai_provider
    manifest.ai_provider = "none"
    # Regenerate the Hyprland fragment without the AI bind.
    frag = next((f for f in manifest.files if f.kind == "fragment"), None)
    if frag and manifest.hypr_dialect != "none":
        regenerate_fragment(lay, manifest, with_ai=False)
    retained: list[str] = []
    for pkg in list(manifest.packages):
        if pkg.name not in ("claude-code", "openai-codex"):
            continue
        q = f"Also uninstall {pkg.name}, which AEROLITH installed for you? Your own settings and sign-in in ~/.claude or ~/.codex are kept either way."
        if remove_provider or (remove_provider is None and ui.confirm(q, default=False)):
            if pkg.method == "native-installer":
                removed = packages.remove_native_claude(pkg)
                rep.removed += removed
                manifest.packages.remove(pkg)
            else:
                ok, msg = packages.run(packages.pacman_remove_step([pkg.name]))
                if ok:
                    rep.removed.append(f"package {pkg.name}")
                    manifest.packages.remove(pkg)
                else:
                    ui.warn(f"could not remove {pkg.name}: {msg}")
        else:
            retained.append(f"{pkg.name} (installed by AEROLITH; kept at your request)")
    for tool in ("claude", "codex"):
        exe = packages.find_tool(tool)
        if exe and not any(p.name in ("claude-code", "openai-codex") and tool in p.name for p in manifest.packages):
            retained.append(f"{tool} at {exe} (not installed by AEROLITH; never touched)")
    if report:
        ui.title("AI integration removed")
        ui.ok(f"previous provider: {prev}")
        for r in rep.removed:
            ui.ok("removed " + tilde(r))
        for r in retained:
            ui.info("kept " + r)
        ui.info("kept ~/.claude, ~/.claude.json and ~/.codex (owned by those tools)")
        if lay.system and (lay.ai_module / "AiModule.qml").is_file():
            ui.info(
                f"the AI Bridge files in {lay.ai_module} belong to the aerolith-ai-bridge package and stay inactive "
                "without your ai.json; to remove them for every user: sudo pacman -R aerolith-ai-bridge"
            )
        ui.ok("the shell keeps working; AI commands disappear immediately")
    return rep


def regenerate_fragment(lay: Layout, manifest: Manifest, with_ai: bool) -> None:
    dialect = manifest.hypr_dialect
    if dialect == "none":
        return
    fpath = hypr.fragment_path(lay, dialect)
    binds = bind_overrides(lay, hypr.default_binds(with_ai, False))
    frag = hypr.fragment(dialect, binds, hypr.launch_command(lay.shell) if manifest.startup == "hyprland" else None)
    atomic_write(fpath, frag)
    manifest.record_file(fpath, "integration", "fragment")


def cmd_uninstall(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    manifest = load_manifest(lay)
    if manifest is None:
        ui.info(f"no AEROLITH installation is recorded in {tilde(lay.manifest)}; nothing was removed")
        return 0
    ui.title("Uninstall AEROLITH")
    for e in manifest.edits:
        ui.say(f"  • remove the AEROLITH block from {tilde(e.file)}")
    counts: dict[str, int] = {}
    for f in manifest.files:
        counts[f.component] = counts.get(f.component, 0) + 1
    for comp, n in sorted(counts.items()):
        ui.say(f"  • {comp}: {n} file(s)")
    keep_config = not args.remove_config
    if not args.remove_config and manifest.component_files("config"):
        keep_config = ui.confirm("Keep your AEROLITH settings (config.json, routines.json, installation.json) for a later reinstall?", default=True)
    if args.dry_run:
        ui.info("dry run: nothing was changed")
        return 0
    if not ui.confirm("Uninstall now?", default=None):
        ui.info("cancelled")
        return 1
    if shell_running(lay):
        subprocess.run([shutil.which("qs") or "qs", "-p", str(lay.shell), "kill"], capture_output=True, check=False, timeout=15)
        ui.info("stopped the running shell")
    if (lay.service.exists()) and shutil.which("systemctl"):
        subprocess.run(["systemctl", "--user", "disable", "--now", "aerolith.service"], capture_output=True, check=False, timeout=15)
    # Startup may have been added to a minimal config created by theming on
    # an earlier install. Remove it first so the theme can delete that file
    # only when no user content remains.
    for e in list(manifest.edits):
        if e.component.startswith("theme:"):
            continue
        ui.ok(hypr.remove_include(e))
        manifest.edits.remove(e)
    themed_apps = set(manifest.themes)
    themed_apps.update(f.component[6:] for f in manifest.files if f.component.startswith("theme:"))
    themed_apps.update(e.component[6:] for e in manifest.edits if e.component.startswith("theme:"))
    for app in sorted(themed_apps):
        for note in themes.remove_app(lay, manifest, app):
            ui.info(note)
    ai_remove(lay, manifest, ui, remove_provider=args.remove_provider, report=False)
    components = ["core", "integration"] + ([] if keep_config else ["config"])
    rep = remove_files(manifest, [f for f in manifest.files if f.component in components], force_modified=args.force)
    for d in (lay.data, lay.hypr_fragment_dir):
        prune_dirs(manifest, d, rep)
    for p in rep.removed:
        ui.ok("removed " + tilde(p))
    for p in rep.kept_modified:
        ui.warn(f"kept {tilde(p)}: you changed it after installation (use --force to remove)")
    if keep_config:
        for f in manifest.component_files("config"):
            ui.info("kept " + tilde(f.path))
    remaining = [f for f in manifest.files]
    if remaining or manifest.packages or manifest.edits or manifest.themes:
        manifest.save(lay.manifest)
        ui.info(f"{len(remaining)} kept file(s) remain listed in {tilde(lay.manifest)}")
    else:
        lay.manifest.unlink(missing_ok=True)
        try:
            lay.state.rmdir()
        except OSError:
            pass
    if lay.state.exists():
        # Backups of edited files and the shell's command history are user
        # data: report them, never delete them.
        ui.info(f"kept {tilde(lay.state)} (backups of files AEROLITH edited, command history); delete it yourself when you no longer need it")
    if lay.system:
        ui.info(f"the packaged files in {lay.system} are pacman's; remove them with: sudo pacman -R aerolith (and aerolith-ai-bridge)")
        ui.ok("AEROLITH has been removed for this user. No reboot is needed; restart Hyprland or reload its config to drop the binds.")
    else:
        ui.ok("AEROLITH has been uninstalled. No reboot is needed; restart Hyprland or reload its config to drop the binds.")
    return 0


# --- ai subcommands ----------------------------------------------------------------

def cmd_ai(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    manifest = load_manifest(lay)
    if manifest is None:
        raise Abort("AEROLITH is not installed; run the installer first")
    sub = args.ai_cmd
    if sub == "status":
        ui.title("AI integration")
        ui.say(f"  provider: {manifest.ai_provider}")
        if manifest.ai_provider == "none":
            ui.say("  No AI files, configuration or processes are installed.")
            return 0
        st = bridge_status(lay, auth=args.auth)
        for k in ("display", "enabled", "installed", "providerVersion", "authenticated", "remote", "context", "timeoutSeconds"):
            if k in st:
                ui.say(f"  {k}: {st[k]}")
        if st.get("problem"):
            ui.warn(st["problem"]["message"])
        if st.get("dataFlow"):
            ui.say("  data flow: " + st["dataFlow"])
        return 0
    if sub in ("enable", "disable"):
        if manifest.ai_provider == "none":
            raise Abort("no AI provider is configured; use `aerolith ai configure`")
        aicfg = import_ai_config(lay, None)
        cfg = aicfg.load(lay.ai_file)
        cfg.enabled = sub == "enable"
        aicfg.write(cfg, lay.ai_file)
        manifest.record_file(lay.ai_file, "ai", "config")
        manifest.save(lay.manifest)
        ui.ok(f"AI integration {sub}d (the shell picks this up immediately)")
        return 0
    if sub == "remove":
        if args.dry_run:
            for f in manifest.component_files("ai"):
                ui.say("  • remove " + tilde(f.path))
            ui.info("dry run: nothing was changed")
            return 0
        if manifest.ai_provider == "none" and not manifest.component_files("ai"):
            ui.info("no AI integration is installed")
            return 0
        if not ui.confirm("Remove AEROLITH's AI integration? The shell keeps working.", default=None):
            return 1
        ai_remove(lay, manifest, ui, remove_provider=args.remove_provider)
        manifest.save(lay.manifest)
        return 0
    if sub in ("configure", "switch"):
        src = Path(manifest.source) if manifest.source else None
        if args.source:
            src = Path(args.source).resolve()
        if not lay.system and (src is None or ai_bridge_source(src, lay) is None):
            raise Abort("AI Bridge sources not found; pass --source <aerolith checkout>")
        choice = ui.choose("Choose an AI provider:", [c for c in AI_CHOICES if c[0] != "none"], args.ai)
        plan = Plan()
        plan_ai(args, ui, lay, src, manifest, plan, choice)
        if manifest.hypr_dialect != "none":
            plan.add("add the aerolith:ai bind to AEROLITH's Hyprland fragment", lambda: regenerate_fragment(lay, manifest, with_ai=True))
        ui.title("Planned changes")
        for line in plan.lines:
            ui.say("  • " + line)
        if args.dry_run:
            ui.info("dry run: nothing was changed")
            return 0
        if not ui.confirm("Proceed?", default=None):
            return 1
        if manifest.component_files("ai"):
            remove_files(manifest, [f for f in manifest.component_files("ai") if f.kind != "config"], force_modified=True)
        for _, action in plan.actions:
            action()
        manifest.save(lay.manifest)
        ui.ok(f"AI provider set to {choice}")
        return 0
    raise Abort(f"unknown ai command {sub}")


# --- other commands ---------------------------------------------------------------

def cmd_status(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    manifest = load_manifest(lay)
    direction = read_installation(lay).get("direction", "piyti")
    info = {
        "installed": manifest is not None,
        "mode": lay.mode,
        "shell": str(lay.shell),
        "running": shell_running(lay),
        "direction": direction if direction in DIRECTIONS else "piyti",
        "ai_provider": manifest.ai_provider if manifest else None,
        "startup": manifest.startup if manifest else None,
        "hyprland_dialect": manifest.hypr_dialect if manifest else None,
        "files": len(manifest.files) if manifest else 0,
        "packages_installed_by_aerolith": [p.name for p in manifest.packages] if manifest else [],
        "version": manifest.aerolith_version if manifest else None,
    }
    if args.json:
        print(json.dumps(info, indent=2))
        return 0
    ui.title("AEROLITH status")
    for k, v in info.items():
        ui.say(f"  {k}: {v}")
    return 0


def cmd_doctor(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    bad = 0
    ui.title("Environment")
    for c in checks.run_checks(lay):
        {"ok": ui.ok, "warn": ui.warn, "fail": ui.fail, "info": ui.info}[c.status](f"{c.name}: {c.detail}")
        bad += c.status == "fail"
    ui.title("Installation")
    manifest = load_manifest(lay)
    if manifest is None:
        ui.warn("not installed")
        return 1
    problems = verify(lay, manifest)
    for p in problems:
        ui.fail(p)
    if not problems:
        ui.ok("all installed files present and unmodified")
    bad += len(problems)
    ui.title("Configuration")
    schema = lay.shell / "schema" / "config.schema.json"
    if schema.is_file():
        errors, warnings = validate_file(lay.config_file, schema)
        for e in errors:
            ui.fail(e)
        for w in warnings:
            ui.warn(w)
        if not errors:
            ui.ok(f"{tilde(lay.config_file)} is valid")
        bad += len(errors)
    ui.ok(f"shell {'running' if shell_running(lay) else 'not running'}")
    if manifest.ai_provider != "none":
        ui.title("AI")
        st = bridge_status(lay)
        if st.get("installed"):
            ui.ok(f"{manifest.ai_provider}: {st.get('providerVersion')}")
        else:
            ui.warn(f"{manifest.ai_provider}: " + str((st.get("problem") or st.get("error") or {}).get("message")))
    return 1 if bad else 0


def cmd_config(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    if args.config_cmd == "path":
        print(lay.config_file)
        return 0
    if args.config_cmd == "validate":
        schema = lay.shell / "schema" / "config.schema.json"
        if not schema.is_file():
            src = source_root()
            schema = src / "shell" / "schema" / "config.schema.json" if src else schema
        errors, warnings = validate_file(lay.config_file, schema)
        for e in errors:
            ui.fail(e)
        for w in warnings:
            ui.warn(w)
        if not errors:
            ui.ok(f"{tilde(lay.config_file)} is valid")
        return 1 if errors else 0
    if args.config_cmd == "reset":
        if lay.config_file.exists():
            backup = lay.backups / time.strftime("%Y%m%d-%H%M%S") / "config.json"
            ui.say(f"  your current file is backed up to {tilde(backup)}")
        if not ui.confirm(f"Replace {tilde(lay.config_file)} with the starter configuration?", default=None):
            return 1
        if lay.config_file.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(lay.config_file, backup)
        atomic_write(lay.config_file, starter_config(lay))
        manifest = load_manifest(lay)
        if manifest:
            manifest.record_file(lay.config_file, "config", "config")
            manifest.save(lay.manifest)
        ui.ok("configuration reset")
        return 0
    raise Abort(f"unknown config command {args.config_cmd}")


def cmd_intensity(args: argparse.Namespace, ui: Ui) -> int:
    """Show or set theme.intensity in config.json; the running shell applies it live."""
    lay = layout()
    data = read_live_config(lay)
    theme = data.get("theme", {})
    current = theme.get("intensity", INTENSITIES[0])
    if not args.level:
        print(current)
        return 0
    if args.dry_run:
        ui.info(f"dry run: intensity {args.level}; would update {tilde(lay.config_file)}")
        return 0
    if args.level == current and "intensity" in theme:
        ui.ok(f"intensity is already {current}")
        return 0
    write_theme_values(lay, data, {"intensity": args.level})
    ui.ok(f"intensity set to {args.level}; a running shell switches at once")
    return 0


def cmd_scheme(args: argparse.Namespace, ui: Ui) -> int:
    """Use the generated catalog and C06's consent-preserving refresh."""
    lay = layout()
    data = read_live_config(lay)
    manifest = load_manifest(lay)
    options = scheme_choices(lay, manifest)
    value = args.id if args.id is not None else data.get("theme", {}).get("scheme", "limb")
    if value not in [o[0] for o in options]:
        raise Abort(f"unknown scheme: {value}; choose from " + ", ".join(o[0] for o in options))
    if args.id is None:
        print(value)
        return 0

    def save() -> None:
        if args.dry_run:
            ui.info(f"dry run: scheme {value}; would update {tilde(lay.config_file)}")
        else:
            write_theme_values(lay, read_live_config(lay), {"scheme": value})
            ui.ok(f"scheme set to {value}; a running shell switches at once")

    if manifest and manifest.themes:
        themes.refresh_plans(lay, manifest, value)
        if args.dry_run:
            save()
            result = themes.refresh(lay, manifest, value, dry_run=True)
        else:
            with themes.refresh_lock(lay):
                manifest = load_manifest(lay)
                themes.refresh_plans(lay, manifest, value)
                save()
                result = themes.refresh(lay, manifest, value)
        return report_theme_refresh(result, False, ui)
    save()
    return 0


def report_theme_refresh(result: dict, as_json: bool, ui: Ui) -> int:
    if as_json:
        print(json.dumps(result, indent=2))
    else:
        for row in result["apps"]:
            ui.say(f"{row['app']}: {row['status']}; {row.get('error', row.get('activation', ''))}")
    return 2 if result.get("error") or any(r["status"] == "error" for r in result["apps"]) else 0


def cmd_hypr(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    manifest = load_manifest(lay)
    if manifest is None:
        raise Abort("AEROLITH is not installed")
    if args.hypr_cmd == "show":
        f = next((x for x in manifest.files if x.kind == "fragment"), None)
        if f:
            ui.code(Path(f.path).read_text(encoding="utf-8"))
        for e in manifest.edits:
            ui.say(f"  included from {tilde(e.file)} (backup {tilde(e.backup)})")
        return 0
    if args.hypr_cmd == "apply":
        if manifest.hypr_dialect == "none":
            raise Abort("no Hyprland integration is installed")
        regenerate_fragment(lay, manifest, with_ai=manifest.ai_provider != "none")
        manifest.save(lay.manifest)
        ui.ok("fragment regenerated; Hyprland reloads it automatically")
        return 0
    if args.hypr_cmd == "remove":
        for e in list(manifest.edits):
            if e.component != "integration":
                continue
            ui.ok(hypr.remove_include(e))
            manifest.edits.remove(e)
        rep = remove_files(manifest, [f for f in manifest.files if f.kind == "fragment"], force_modified=True)
        prune_dirs(manifest, lay.hypr_fragment_dir, rep)
        manifest.hypr_dialect = "none"
        manifest.save(lay.manifest)
        ui.ok("Hyprland integration removed")
        return 0
    raise Abort(f"unknown hypr command {args.hypr_cmd}")


def cmd_run(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    qs = shutil.which("qs") or shutil.which("quickshell")
    if not qs:
        raise Abort("quickshell is not installed")
    if args.cmd == "stop":
        return subprocess.run([qs, "-p", str(lay.shell), "kill"], check=False).returncode
    if args.cmd == "restart":
        subprocess.run([qs, "-p", str(lay.shell), "kill"], capture_output=True, check=False)
        return subprocess.run([qs, "-p", str(lay.shell), "-d"], check=False).returncode
    os.execv(qs, [qs, "-p", str(lay.shell)])
    return 0


def cmd_themes(args: argparse.Namespace, ui: Ui) -> int:
    lay = layout()
    if args.themes_cmd == "refresh":
        try:
            # Preflight before creating even the operational lock file. Re-read
            # under the lock: another refresh may have committed while waiting.
            themes.refresh_plans(lay, load_manifest(lay), args.scheme)
            if args.dry_run:
                result = themes.refresh(lay, load_manifest(lay), args.scheme, dry_run=True)
            else:
                with themes.refresh_lock(lay):
                    result = themes.refresh(lay, load_manifest(lay), args.scheme)
        except (Abort, themes.ThemeError, OSError, ValueError, TypeError) as exc:
            if not args.json:
                raise Abort(str(exc)) from None
            result = {"apps": [], "error": str(exc)}
        return report_theme_refresh(result, args.json, ui)
    manifest = load_manifest(lay)
    if args.themes_cmd in ("list", "status"):
        rows = themes.status(lay, manifest)
        if getattr(args, "json", False):
            print(json.dumps({"apps": rows}, indent=2))
        else:
            for row in rows:
                ui.say(f"{row['app']}: {'detected' if row['detected'] else 'not detected'}, "
                       f"{'applied' if row['applied'] else 'not applied'}" +
                       (f" ({row['scheme']}/{row['direction']})" if row['scheme'] else ""))
                ui.say("  " + row["note"])
        return 0
    if manifest is None:
        raise Abort("install AEROLITH first; no ownership manifest was found")
    apps = list(dict.fromkeys(args.apps))
    if args.themes_cmd == "apply":
        root = themes.assets_root(lay, manifest)
        scheme, direction = themes.selection(lay, args.scheme)
        plans = [themes.prepare_app(lay, manifest, root, app, scheme, direction) for app in apps]
        for deployment in plans:
            for line in deployment.describe():
                ui.say(line)
        if args.dry_run:
            ui.info("dry run: nothing was changed")
            return 0
        # Naming apps is explicit consent; unlike install, no second prompt.
        for deployment in plans:
            themes.execute(lay, manifest, deployment)
    else:
        for app in apps:
            if app not in themes.SUPPORTED and app not in themes.DEFERRED:
                raise Abort(f"unknown app: {app}; see `aerolith themes list`")
        for app in apps:
            for note in themes.remove_app(lay, manifest, app):
                ui.info(note)
    return 0


# --- argument parsing ---------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="aerolith", description="Install, inspect, maintain and remove AEROLITH.")
    p.add_argument("--version", action="version", version=f"aerolith {__version__}")
    p.add_argument("-y", "--yes", action="store_true", help="answer yes to every question (use with explicit choice flags)")
    # --yes is accepted after the subcommand too (`aerolith install --yes`);
    # SUPPRESS keeps a global --yes from being reset by the subparser.
    yes = argparse.ArgumentParser(add_help=False)
    yes.add_argument("-y", "--yes", action="store_true", default=argparse.SUPPRESS, help=argparse.SUPPRESS)
    sub = p.add_subparsers(dest="cmd", required=True)

    i = sub.add_parser("install", parents=[yes], help="install or update AEROLITH for this user")
    i.add_argument("--ai", choices=[c[0] for c in AI_CHOICES], help="AI integration (required when not interactive)")
    i.add_argument("--startup", choices=[c[0] for c in STARTUP_CHOICES])
    i.add_argument("--direction", choices=DIRECTIONS, help="installation-only application direction (default: piyti; reinstall keeps the existing choice)")
    i.add_argument("--intensity", choices=INTENSITIES, help="live intensity (default: saturated; reinstall keeps the current setting)")
    i.add_argument("--scheme", help="Spectra ID from the generated catalog (default: limb; reinstall keeps the current setting)")
    tg = i.add_mutually_exclusive_group()
    tg.add_argument("--themes", metavar="APP,APP", help="explicitly opt in to application theme exports")
    tg.add_argument("--no-themes", action="store_true", help="skip optional application theme selection; keeps previously applied exports")
    i.add_argument("--no-hypr", action="store_true", help="do not touch Hyprland configuration")
    i.add_argument("--media-keys", action="store_true", help="also bind volume/play keys")
    i.add_argument("--install-deps", dest="install_deps", action="store_true", default=None)
    i.add_argument("--no-install-deps", dest="install_deps", action="store_false")
    i.add_argument("--install-provider", dest="install_provider", action="store_true", default=None)
    i.add_argument("--no-install-provider", dest="install_provider", action="store_false")
    i.add_argument("--custom-exec")
    i.add_argument("--custom-protocol", choices=["aerolith-v1", "text"])
    i.add_argument("--custom-name")
    i.add_argument("--start", dest="start", action="store_true", default=None)
    i.add_argument("--no-start", dest="start", action="store_false")
    i.add_argument("--source", help="AEROLITH source tree (default: the one this runs from)")
    i.add_argument("--dry-run", action="store_true")

    u = sub.add_parser("uninstall", parents=[yes], help="remove everything AEROLITH installed")
    u.add_argument("--remove-config", action="store_true", help="also remove config.json and routines.json")
    u.add_argument("--remove-provider", dest="remove_provider", action="store_true", default=None, help="also uninstall AI tools AEROLITH installed")
    u.add_argument("--keep-provider", dest="remove_provider", action="store_false")
    u.add_argument("--force", action="store_true", help="also remove AEROLITH files you modified")
    u.add_argument("--dry-run", action="store_true")

    s = sub.add_parser("status", parents=[yes], help="show what is installed")
    s.add_argument("--json", action="store_true")
    sub.add_parser("doctor", parents=[yes], help="check the environment and installation")
    th = sub.add_parser("themes", parents=[yes], help="explicit optional app theme deployment")
    ts = th.add_subparsers(dest="themes_cmd", required=True)
    ts.add_parser("list", parents=[yes])
    ts.add_parser("status", parents=[yes]).add_argument("--json", action="store_true")
    ta = ts.add_parser("apply", parents=[yes])
    ta.add_argument("apps", nargs="+")
    ta.add_argument("--scheme", help="generated Spectra scheme ID (default: config.json theme.scheme, or limb)")
    ta.add_argument("--dry-run", action="store_true")
    ts.add_parser("remove", parents=[yes]).add_argument("apps", nargs="+")
    tr = ts.add_parser("refresh", parents=[yes], help="refresh only opted-in app payloads")
    tr.add_argument("--scheme", help="scheme ID (default: current config.json theme.scheme)")
    tr.add_argument("--json", action="store_true")
    tr.add_argument("--dry-run", action="store_true")

    a = sub.add_parser("ai", parents=[yes], help="manage the optional AI integration")
    asub = a.add_subparsers(dest="ai_cmd", required=True)
    st = asub.add_parser("status", parents=[yes])
    st.add_argument("--auth", action="store_true", help="also check sign-in (local, offline)")
    for name in ("configure", "switch"):
        c = asub.add_parser(name, parents=[yes])
        c.add_argument("--ai", choices=["claude", "codex", "custom"])
        c.add_argument("--install-provider", dest="install_provider", action="store_true", default=None)
        c.add_argument("--no-install-provider", dest="install_provider", action="store_false")
        c.add_argument("--custom-exec")
        c.add_argument("--custom-protocol", choices=["aerolith-v1", "text"])
        c.add_argument("--custom-name")
        c.add_argument("--source")
        c.add_argument("--dry-run", action="store_true")
    asub.add_parser("enable", parents=[yes])
    asub.add_parser("disable", parents=[yes])
    r = asub.add_parser("remove", parents=[yes], help="remove AEROLITH's AI integration; the shell keeps working")
    r.add_argument("--remove-provider", dest="remove_provider", action="store_true", default=None)
    r.add_argument("--keep-provider", dest="remove_provider", action="store_false")
    r.add_argument("--dry-run", action="store_true")

    c = sub.add_parser("config", parents=[yes], help="configuration file helpers")
    c.add_argument("config_cmd", choices=["validate", "path", "reset"])
    t = sub.add_parser("intensity", parents=[yes], help="show or set how much the interface shows")
    t.add_argument("level", nargs="?", choices=INTENSITIES)
    t.add_argument("--dry-run", action="store_true")
    s = sub.add_parser("scheme", parents=[yes], help="show or set the live Spectra scheme and refresh opted-in app themes")
    s.add_argument("id", nargs="?")
    s.add_argument("--dry-run", action="store_true")
    h = sub.add_parser("hypr", parents=[yes], help="Hyprland integration")
    h.add_argument("hypr_cmd", choices=["show", "apply", "remove"])
    for name in ("run", "restart", "stop"):
        sub.add_parser(name, parents=[yes], help=f"{name} the shell")
    return p


COMMANDS = {
    "themes": cmd_themes,
    "install": cmd_install,
    "uninstall": cmd_uninstall,
    "status": cmd_status,
    "doctor": cmd_doctor,
    "ai": cmd_ai,
    "config": cmd_config,
    "intensity": cmd_intensity,
    "scheme": cmd_scheme,
    "hypr": cmd_hypr,
    "run": cmd_run,
    "restart": cmd_run,
    "stop": cmd_run,
}


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if os.geteuid() == 0 and os.environ.get("AEROLITH_ALLOW_ROOT") != "1":
        print("aerolith: run as your normal user, not root (it installs per user and asks before using sudo)", file=sys.stderr)
        return 2
    ui = Ui(assume_yes=args.yes)
    try:
        return COMMANDS[args.cmd](args, ui)
    except NeedAnswer as exc:
        print(f"aerolith: an answer is required: {exc}. Run interactively or pass the matching flag.", file=sys.stderr)
        return 2
    except (Abort, themes.ThemeError) as exc:
        print(f"aerolith: {exc}", file=sys.stderr)
        return 2
    except OSError as exc:
        if args.cmd not in ("themes", "scheme"):
            raise
        print(f"aerolith: theme operation stopped: {exc}. Recorded changes can be removed with `aerolith themes remove <app>`.", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("\naerolith: interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
