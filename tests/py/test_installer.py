"""Installer, maintenance and removal tests (mock system tools; see conftest.py)."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

from aerolith_install import cli, hypr, themes
from aerolith_install.manifest import Manifest
from aerolith_install.paths import layout
from conftest import ROOT, write_exe

LUA_CONFIG = '-- my hyprland config\nhl.config({ general = { gaps_in = 5 } })\nhl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))\n'
CONF_CONFIG = "# my config\n$mainMod = SUPER\nbind = $mainMod, Q, exec, kitty\n"


@pytest.fixture
def system(home, bindir, monkeypatch, tmp_path):
    """A fake Arch system: quickshell and Hyprland present, pacman/sudo/curl fakes."""
    monkeypatch.setenv("AEROLITH_ALLOW_ROOT", "1")
    pkgdb = tmp_path / "pacman-installed"
    pkgdb.write_text("quickshell\nhyprland\n")
    monkeypatch.setenv("FAKE_PKGDB", str(pkgdb))
    write_exe(bindir / "qs", "import sys\nprint('Quickshell 0.3.2 (revision , distributed by Arch Linux)')\n")
    write_exe(bindir / "Hyprland", "print('Hyprland 0.56.2')\n")
    write_exe(
        bindir / "pacman",
        r'''
        import os, sys
        db = os.environ["FAKE_PKGDB"]
        have = set(open(db).read().split())
        args = sys.argv[1:]
        if args[0] == "-Q":
            sys.exit(0 if args[1] in have else 1)
        if os.environ.get("FAKE_PACMAN_FAIL"):
            print("error: failed to retrieve some files", file=sys.stderr); sys.exit(1)
        if args[0] == "-S":
            have |= {a for a in args[1:] if not a.startswith("-")}
        if args[0] == "-Rns":
            have -= set(args[1:])
        open(db, "w").write("\n".join(sorted(have)) + "\n")
        ''',
    )
    write_exe(bindir / "sudo", "import os, sys\nos.execvp(sys.argv[1], sys.argv[1:])\n")
    (home / ".config" / "hypr").mkdir(parents=True)
    return pkgdb


def run(*argv: str) -> int:
    return cli.main(list(argv))


def tree(p: Path) -> set[str]:
    return {str(x.relative_to(p)) for x in p.rglob("*")} if p.exists() else set()


def lua_main(home: Path) -> Path:
    p = home / ".config" / "hypr" / "hyprland.lua"
    p.write_text(LUA_CONFIG)
    return p


# --- explicit choices ------------------------------------------------------------------

def test_yes_is_accepted_after_the_subcommand(system, home):
    lua_main(home)
    assert run("install", "--ai", "none", "--startup", "manual", "--yes") == 0
    assert run("status", "-y") == 0


def test_ai_choice_is_required_when_not_interactive(system, home, capsys):
    lua_main(home)
    assert run("--yes", "install", "--startup", "hyprland") == 2
    assert "answer is required" in capsys.readouterr().err
    assert not (home / ".local" / "share" / "aerolith").exists()


def test_refuses_root_without_override(system, monkeypatch, capsys):
    monkeypatch.delenv("AEROLITH_ALLOW_ROOT")
    if os.geteuid() != 0:
        pytest.skip("only meaningful when the tests run as root")
    assert run("status") == 2
    assert "not root" in capsys.readouterr().err


def test_dry_run_changes_nothing(system, home):
    main = lua_main(home)
    before = tree(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland", "--dry-run") == 0
    assert tree(home) == before
    assert main.read_text() == LUA_CONFIG


# --- NONE ---------------------------------------------------------------------------

def test_none_installs_complete_shell_without_any_ai(system, home):
    main = lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland") == 0
    lay = layout()
    assert (lay.shell / "shell.qml").is_file()
    assert (lay.shell / "modules" / "AiLoader.qml").is_file(), "the loader is core; it does nothing without the module"
    assert not lay.ai_module.exists()
    assert not lay.ai_file.exists()
    all_files = "\n".join(str(p) for p in home.rglob("*"))
    assert "aerolith_ai" not in all_files and "aerolith-ai-bridge" not in all_files
    m = Manifest.load(lay.manifest)
    assert m.ai_provider == "none"
    assert not m.component_files("ai")
    frag = (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert "aerolith:command" in frag and "aerolith:ai" not in frag
    assert "hl.exec_cmd(" in frag, "autostart chosen"
    text = main.read_text()
    assert text.startswith(LUA_CONFIG)
    assert 'pcall(require, "aerolith/aerolith")' in text
    assert (lay.config_file).is_file()
    assert cli.verify(lay, m) == []


# --- CLAUDE -------------------------------------------------------------------------

def test_claude_uses_existing_cli_and_never_owns_it(system, home, fake_claude):
    lua_main(home)
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual") == 0
    lay = layout()
    ai = json.loads(lay.ai_file.read_text())
    assert ai["provider"] == "claude" and ai["context"] == {k: False for k in ai["context"]}
    assert oct(lay.ai_file.stat().st_mode & 0o777) == "0o600"
    assert (lay.ai_module / "AiModule.qml").is_file()
    assert (lay.ai_module / "bridge" / "aerolith-ai-bridge").is_file()
    m = Manifest.load(lay.manifest)
    assert m.packages == [], "a pre-existing claude is not recorded as AEROLITH's"
    frag = (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert "aerolith:ai" in frag and "hl.exec_cmd(" not in frag, "manual startup: no autostart"
    claude = shutil.which("claude")
    assert run("--yes", "uninstall") == 0
    assert Path(claude).exists(), "an independently installed claude survives uninstall"


def test_claude_native_install_is_owned_and_removable(system, home, bindir, monkeypatch):
    lua_main(home)
    # Fake curl "downloads" an installer that creates the documented paths.
    write_exe(
        bindir / "curl",
        r'''
        import sys
        out = sys.argv[sys.argv.index("-o") + 1]
        open(out, "w").write("mkdir -p $HOME/.local/bin $HOME/.local/share/claude/versions\n"
                             "printf '#!/bin/sh\\necho 2.1.306\\n' > $HOME/.local/share/claude/versions/2.1.306\n"
                             "chmod +x $HOME/.local/share/claude/versions/2.1.306\n"
                             "ln -sf $HOME/.local/share/claude/versions/2.1.306 $HOME/.local/bin/claude\n")
        ''',
    )
    (home / ".claude").mkdir()
    (home / ".claude" / "settings.json").write_text("{}")
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual", "--install-provider") == 0
    m = Manifest.load(layout().manifest)
    assert [p.name for p in m.packages] == ["claude-code"]
    assert (home / ".local" / "bin" / "claude").exists()
    assert run("--yes", "ai", "remove", "--remove-provider") == 0
    assert not (home / ".local" / "bin" / "claude").exists()
    assert not (home / ".local" / "share" / "claude").exists()
    assert (home / ".claude" / "settings.json").exists(), "~/.claude is never touched"
    assert (layout().shell / "shell.qml").exists(), "the shell stays"


def test_claude_offline_install_still_completes(system, home, bindir):
    lua_main(home)
    write_exe(bindir / "curl", "import sys; print('curl: (6) Could not resolve host: claude.ai', file=sys.stderr); sys.exit(6)\n")
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual", "--install-provider") == 0
    lay = layout()
    assert lay.ai_file.exists()
    assert Manifest.load(lay.manifest).packages == []


# --- CODEX ----------------------------------------------------------------------------

def test_codex_installed_with_pacman_is_recorded(system, home, fake_codex, bindir):
    lua_main(home)
    (bindir / "codex").unlink()
    write_exe(bindir / "codex-real", "print('codex-cli 0.163.0')\n")
    assert run("--yes", "install", "--ai", "codex", "--startup", "manual", "--install-provider") == 0
    m = Manifest.load(layout().manifest)
    assert [p.name for p in m.packages] == ["openai-codex"]
    assert "openai-codex" in system.read_text()
    # Keep the tool when removing the integration, unless asked.
    assert run("--yes", "ai", "remove", "--keep-provider") == 0
    assert "openai-codex" in system.read_text()
    m = Manifest.load(layout().manifest)
    assert m.ai_provider == "none" and [p.name for p in m.packages] == ["openai-codex"]


def test_failed_package_install_rolls_back(system, home, monkeypatch):
    main = lua_main(home)
    system.write_text("hyprland\n")  # quickshell missing
    bindir = Path(os.environ["PATH"].split(":")[0])
    (bindir / "qs").unlink()
    # Hide any real quickshell on the machine running the tests (the dev
    # container has one in /usr/bin): keep only what the fakes need.
    tools = bindir.parent / "tools"
    tools.mkdir()
    for name in ("python3", "env", "sh"):
        (tools / name).symlink_to(shutil.which(name))
    monkeypatch.setenv("PATH", f"{bindir}:{tools}")
    monkeypatch.setenv("FAKE_PACMAN_FAIL", "1")
    rc = run("--yes", "install", "--ai", "none", "--startup", "hyprland", "--install-deps")
    assert rc == 2
    assert main.read_text() == LUA_CONFIG, "Hyprland config untouched after a failed install"
    assert not (home / ".local" / "share" / "aerolith" / "shell").exists()
    assert not layout().manifest.exists()


# --- CUSTOM ---------------------------------------------------------------------------

def test_custom_provider_is_validated(system, home, tmp_path):
    lua_main(home)
    exe = write_exe(tmp_path / "myai", "print('{}')\n")
    assert run("--yes", "install", "--ai", "custom", "--startup", "manual", "--custom-exec", str(exe), "--custom-protocol", "aerolith-v1", "--custom-name", "local") == 0
    ai = json.loads(layout().ai_file.read_text())
    assert ai["custom"] == {"name": "local", "executable": str(exe), "args": [], "protocol": "aerolith-v1"}


def test_custom_provider_rejects_unsafe_program(system, home, tmp_path, capsys):
    lua_main(home)
    exe = write_exe(tmp_path / "shared", "print('{}')\n")
    exe.chmod(0o777)
    assert run("--yes", "install", "--ai", "custom", "--startup", "manual", "--custom-exec", str(exe), "--custom-protocol", "text") == 2
    assert "writable by other users" in capsys.readouterr().err
    assert not layout().manifest.exists()


def test_custom_provider_relative_path_rejected(system, home):
    lua_main(home)
    assert run("--yes", "install", "--ai", "custom", "--startup", "manual", "--custom-exec", "myai", "--custom-protocol", "text") == 2


# --- switching and removal -----------------------------------------------------------

def test_switch_claude_to_codex(system, home, fake_claude, fake_codex):
    lua_main(home)
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual") == 0
    assert run("--yes", "ai", "switch", "--ai", "codex") == 0
    lay = layout()
    assert json.loads(lay.ai_file.read_text())["provider"] == "codex"
    assert Manifest.load(lay.manifest).ai_provider == "codex"
    assert (lay.ai_module / "AiModule.qml").is_file()
    assert cli.verify(lay, Manifest.load(lay.manifest)) == []


def test_switch_provider_to_none(system, home, fake_claude):
    lua_main(home)
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual") == 0
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    lay = layout()
    assert not lay.ai_module.exists() and not lay.ai_file.exists()
    assert "aerolith:ai" not in (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert (lay.shell / "shell.qml").is_file()


def test_ai_remove_keeps_shell_and_unrelated_ai_tools(system, home, fake_claude, fake_codex):
    lua_main(home)
    (home / ".codex").mkdir()
    (home / ".codex" / "auth.json").write_text('{"secret": "do-not-touch"}')
    assert run("--yes", "install", "--ai", "claude", "--startup", "hyprland") == 0
    lay = layout()
    assert run("--yes", "ai", "remove") == 0
    m = Manifest.load(lay.manifest)
    assert m.ai_provider == "none" and not m.component_files("ai")
    assert not lay.ai_module.exists() and not lay.ai_file.exists()
    assert cli.verify(lay, m) == [], "core and integration intact"
    assert "aerolith:ai" not in (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert shutil.which("claude") and shutil.which("codex")
    assert (home / ".codex" / "auth.json").read_text() == '{"secret": "do-not-touch"}'


def test_enable_disable(system, home, fake_claude):
    lua_main(home)
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual") == 0
    assert run("ai", "disable") == 0
    assert json.loads(layout().ai_file.read_text())["enabled"] is False
    assert run("ai", "enable") == 0
    assert json.loads(layout().ai_file.read_text())["enabled"] is True


# --- uninstall -------------------------------------------------------------------------

def test_uninstall_restores_hyprland_config_exactly(system, home):
    main = lua_main(home)
    (home / ".config" / "aerolith").mkdir(parents=True)
    (home / ".config" / "aerolith" / "my-notes.txt").write_text("mine")
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland") == 0
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert main.read_text() == LUA_CONFIG
    assert (home / ".config" / "aerolith" / "my-notes.txt").read_text() == "mine"
    assert not (home / ".local" / "share" / "aerolith").exists()
    assert not (home / ".config" / "hypr" / "aerolith").exists()
    assert not layout().manifest.exists()


def test_uninstall_keeps_config_by_default_and_modified_files(system, home):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland") == 0
    lay = layout()
    edited = lay.shell / "core" / "Theme.qml"
    edited.write_text(edited.read_text() + "\n// my tweak\n")
    assert run("--yes", "uninstall") == 0
    assert lay.config_file.exists(), "settings kept by default"
    assert edited.exists(), "a modified AEROLITH file is not deleted without --force"
    m = Manifest.load(lay.manifest)
    assert {Path(f.path).name for f in m.files} == {"config.json", "installation.json", "Theme.qml"}


def test_uninstall_without_manifest_removes_nothing(system, home, capsys):
    (home / ".local" / "share" / "aerolith").mkdir(parents=True)
    (home / ".local" / "share" / "aerolith" / "looks-like-ours.qml").write_text("x")
    assert run("--yes", "uninstall") == 0
    assert (home / ".local" / "share" / "aerolith" / "looks-like-ours.qml").exists()


# --- hyprland details ---------------------------------------------------------------

@pytest.mark.parametrize("dialect", ["lua", "hyprlang"])
def test_layer_rules_managed_roundtrip(system, home, dialect):
    lay = layout()
    if dialect == "lua":
        main = lua_main(home)
        user_rule = 'hl.layer_rule({ match = { namespace = "^other-panel$" }, no_anim = false })\n'
        rule = lambda ns: f'hl.layer_rule({{ match = {{ namespace = "^{ns}$" }}, no_anim = true }})'
    else:
        main = lay.hypr / "hyprland.conf"
        main.write_text(CONF_CONFIG)
        user_rule = "layerrule = no_anim off, match:namespace ^other-panel$\n"
        rule = lambda ns: f"layerrule = no_anim on, match:namespace ^{ns}$"
    main.write_text(main.read_text() + user_rule)
    original = main.read_bytes()
    expected = [rule(ns) for ns in (
        "aerolith-ground", "aerolith-strip", "aerolith-deck", "aerolith-notices", "aerolith-osd",
    )]
    frag = hypr.fragment_path(lay, dialect)
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland") == 0
    first = frag.read_bytes()
    included = main.read_bytes()
    assert [line for line in first.decode().splitlines() if line.startswith(("hl.layer_rule(", "layerrule ="))] == expected
    # Simulate an installed pre-D05 fragment, then upgrade through the real CLI.
    frag.write_text("\n".join(line for line in first.decode().splitlines() if line not in expected) + "\n")
    m = Manifest.load(lay.manifest)
    m.record_file(frag, "integration", "fragment")
    m.save(lay.manifest)
    for args in [("install", "--startup", "hyprland"), ("hypr", "apply"), ("hypr", "apply")]:
        assert run("--yes", *args) == 0
        assert frag.read_bytes() == first
        assert main.read_bytes() == included
    # User changes made after installation survive removal too.
    main.write_text(main.read_text() + user_rule)
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert main.read_bytes() == original + user_rule.encode()
    assert not frag.exists()
    assert not lay.hypr_fragment_dir.exists()


def test_hyprlang_config_gets_source_block(system, home):
    p = home / ".config" / "hypr" / "hyprland.conf"
    p.write_text(CONF_CONFIG)
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland") == 0
    frag = (home / ".config" / "hypr" / "aerolith" / "aerolith.conf").read_text()
    assert "exec-once = " in frag and "bindd = SUPER, SPACE, AEROLITH: Command Core, global, aerolith:command" in frag
    assert "source = " in p.read_text()
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert p.read_text() == CONF_CONFIG


def test_conflicting_bind_is_skipped(system, home):
    p = home / ".config" / "hypr" / "hyprland.lua"
    p.write_text(LUA_CONFIG + 'hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("rofi -show drun"))\n')
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    frag = (home / ".config" / "hypr" / "aerolith" / "aerolith.lua").read_text()
    assert "aerolith:command" not in frag
    assert "aerolith:navigator" in frag


def test_conf_conflict_with_mainmod_variable():
    binds = hypr.default_binds(False, False)
    found = hypr.conflicts(binds, None, CONF_CONFIG + "bind = $mainMod, TAB, cyclenext\n")
    assert "navigator" in found and "command" not in found


def test_running_hyprland_binds_are_checked():
    binds = hypr.default_binds(False, False)
    existing = [{"modmask": 64, "key": "space", "dispatcher": "exec", "arg": "wofi"}, {"modmask": 64, "key": "TAB", "dispatcher": "global", "arg": "aerolith:navigator"}]
    found = hypr.conflicts(binds, existing, "")
    assert set(found) == {"command"}, "our own previous bind is not a conflict"


def test_lua_strings_in_fragment_are_escaped():
    b = [hypr.Bind("command", "SUPER", "SPACE", 'say "hi" \\ é')]
    frag = hypr.fragment("lua", b, "qs -p '/home/x/it\"s'")
    assert '"say \\"hi\\" \\\\ \\195\\169"' in frag
    assert 'hl.exec_cmd("qs -p \'/home/x/it\\"s\'")' in frag


@pytest.mark.skipif(shutil.which("luac") is None, reason="luac not installed (it is in the Arch dev container)")
def test_lua_fragment_compiles(tmp_path):
    frag = hypr.fragment("lua", hypr.default_binds(True, True), hypr.launch_command(Path("/home/u/.local/share/aerolith/shell")))
    f = tmp_path / "frag.lua"
    f.write_text(frag)
    subprocess.run(["luac", "-p", str(f)], check=True)


def test_bind_overrides(system, home):
    lua_main(home)
    (home / ".config" / "aerolith").mkdir(parents=True)
    (home / ".config" / "aerolith" / "hypr-binds.json").write_text(json.dumps({"command": "SUPER + ALT + SPACE", "routines": None}))
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    frag = (home / ".config" / "hypr" / "aerolith" / "aerolith.lua").read_text()
    assert 'hl.bind("SUPER + ALT + SPACE", hl.dsp.global("aerolith:command")' in frag
    assert "aerolith:routines" not in frag


@pytest.mark.parametrize("dialect", ["lua", "hyprlang"])
def test_no_hypr_flag_leaves_hyprland_alone(system, home, dialect):
    main = home / ".config" / "hypr" / ("hyprland.lua" if dialect == "lua" else "hyprland.conf")
    original = LUA_CONFIG if dialect == "lua" else CONF_CONFIG
    main.write_text(original)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--no-hypr") == 0
    assert main.read_text() == original
    assert not (home / ".config" / "hypr" / "aerolith").exists()


# --- update, config and status -------------------------------------------------------

def test_update_keeps_ai_json_and_removes_stale_files(system, home, fake_claude):
    lua_main(home)
    assert run("--yes", "install", "--ai", "claude", "--startup", "manual") == 0
    lay = layout()
    ai = json.loads(lay.ai_file.read_text())
    ai["context"]["workspaces"] = True
    lay.ai_file.write_text(json.dumps(ai))
    # Simulate a file that a newer version no longer ships.
    stale = lay.shell / "core" / "Obsolete.qml"
    stale.write_text("x")
    m = Manifest.load(lay.manifest)
    m.record_file(stale, "core")
    m.save(lay.manifest)
    assert run("--yes", "install", "--startup", "manual") == 0
    assert json.loads(lay.ai_file.read_text())["context"]["workspaces"] is True
    assert not stale.exists()


def test_config_validate_reports_errors(system, home, capsys):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    lay = layout()
    lay.config_file.write_text('{"strip": {"edge": "left"}, "mystery": 1}')
    assert run("config", "validate") == 1
    out = capsys.readouterr().out
    assert "strip.edge: must be one of top, bottom" in out and "mystery: unknown setting" in out
    lay.config_file.write_text("{ broken")
    assert run("config", "validate") == 1
    assert "invalid JSON" in capsys.readouterr().out


def test_intensity_command_shows_and_sets_the_level(system, home, capsys):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    lay = layout()
    capsys.readouterr()
    assert run("intensity") == 0
    assert capsys.readouterr().out.strip() == "saturated"
    before = json.loads(lay.config_file.read_text())
    assert run("intensity", "insane") == 0
    after = json.loads(lay.config_file.read_text())
    assert after["theme"]["intensity"] == "insane"
    # Everything else in the file is kept.
    del after["theme"]["intensity"]
    before.get("theme", {}).pop("intensity", None)
    assert after == before
    capsys.readouterr()
    assert run("intensity") == 0
    assert capsys.readouterr().out.strip() == "insane"
    assert run("config", "validate") == 0


def test_intensity_command_never_overwrites_a_broken_file(system, home):
    lay = layout()
    lay.config_file.parent.mkdir(parents=True, exist_ok=True)
    lay.config_file.write_text("{ broken")
    assert run("intensity", "insane") != 0
    assert lay.config_file.read_text() == "{ broken"


def test_intensity_command_creates_a_missing_config(system, home):
    lay = layout()
    assert not lay.config_file.exists()
    assert run("intensity", "insane") == 0
    assert json.loads(lay.config_file.read_text()) == {"theme": {"intensity": "insane"}, "schemaVersion": 1}


def test_status_json(system, home, capsys):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    capsys.readouterr()
    assert run("status", "--json") == 0
    s = json.loads(capsys.readouterr().out)
    assert s["installed"] is True and s["ai_provider"] == "none"
    assert s["direction"] == "piyti"


def test_direction_interactive_default(system, home, monkeypatch, capsys):
    lua_main(home)
    args = cli.build_parser().parse_args(["install", "--ai", "none", "--startup", "manual", "--no-hypr", "--no-start"])
    answers = iter(["", "", "y"])
    monkeypatch.setattr("builtins.input", lambda prompt: next(answers))
    assert cli.cmd_install(args, cli.Ui(interactive=True, color=False)) == 0
    out = capsys.readouterr().out
    assert out.index("PIYTI (default)") < out.index("THEARS")
    assert json.loads(layout().installation_file.read_text()) == {"direction": "piyti"}


def test_direction_interactive_thears(system, home, monkeypatch):
    lua_main(home)
    args = cli.build_parser().parse_args(["install", "--ai", "none", "--startup", "manual", "--no-hypr", "--no-start"])
    answers = iter(["2", "", "y"])
    monkeypatch.setattr("builtins.input", lambda prompt: next(answers))
    assert cli.cmd_install(args, cli.Ui(interactive=True, color=False)) == 0
    assert json.loads(layout().installation_file.read_text())["direction"] == "thears"


@pytest.mark.parametrize("direction", ["piyti", "thears"])
def test_direction_install_reinstall_and_explicit_change(system, home, capsys, direction):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--direction", direction) == 0
    lay = layout()
    # Reinstall also preserves unrelated metadata and live user settings.
    data = json.loads(lay.installation_file.read_text())
    data["future"] = {"keep": True}
    lay.installation_file.write_text(json.dumps(data))
    config = '{"theme":{"intensity":"insane"},"user-note":"keep me"}\n'
    lay.config_file.write_text(config)
    assert run("--yes", "install", "--startup", "manual") == 0
    assert json.loads(lay.installation_file.read_text()) == data
    assert lay.config_file.read_text() == config
    capsys.readouterr()
    assert run("status", "--json") == 0
    assert json.loads(capsys.readouterr().out)["direction"] == direction
    assert run("status") == 0
    assert f"direction: {direction}" in capsys.readouterr().out
    other = "piyti" if direction == "thears" else "thears"
    assert run("--yes", "install", "--startup", "manual", "--direction", other) == 0
    assert json.loads(lay.installation_file.read_text()) == {"direction": other, "future": {"keep": True}}
    assert lay.config_file.read_text() == config
    assert any(f.path == str(lay.installation_file) and f.component == "config" for f in Manifest.load(lay.manifest).files)


@pytest.mark.parametrize("direction", [None, "thears"])
def test_direction_dry_run(system, home, capsys, direction):
    lua_main(home)
    flags = ["--direction", direction] if direction else []
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--dry-run", *flags) == 0
    assert f"application direction: {direction or 'piyti'}" in capsys.readouterr().out
    assert not layout().installation_file.exists()
    assert not layout().manifest.exists()


@pytest.mark.parametrize("text", ["{ broken", "", "[]", "null"])
def test_direction_refuses_broken_metadata_without_writes(system, home, text):
    lua_main(home)
    lay = layout()
    lay.installation_file.parent.mkdir(parents=True, exist_ok=True)
    lay.installation_file.write_text(text)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--direction", "thears") == 2
    assert lay.installation_file.read_text() == text
    assert not lay.shell.exists()
    assert not lay.manifest.exists()


@pytest.mark.parametrize("value", ["other", "PIYTI", None, [], {}])
def test_direction_invalid_value_requires_explicit_repair(system, home, value):
    lua_main(home)
    lay = layout()
    lay.installation_file.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps({"direction": value, "keep": True})
    lay.installation_file.write_text(text)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 2
    assert lay.installation_file.read_text() == text
    assert not lay.shell.exists()
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--direction", "thears") == 0
    assert json.loads(lay.installation_file.read_text()) == {"direction": "thears", "keep": True}


def test_direction_flag_rejects_invalid_value(system, home):
    with pytest.raises(SystemExit) as exc:
        run("install", "--direction", "invalid")
    assert exc.value.code == 2
    assert not layout().installation_file.exists()


def test_direction_status_invalid_value_uses_shell_fallback(system, home, capsys):
    lay = layout()
    lay.installation_file.parent.mkdir(parents=True, exist_ok=True)
    lay.installation_file.write_text('{"direction":"invalid"}')
    assert run("status", "--json") == 0
    status = json.loads(capsys.readouterr().out)
    assert status["direction"] == "piyti"


@pytest.mark.parametrize("remove_config", [False, True])
def test_direction_uninstall_and_reinstall(system, home, remove_config):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--direction", "thears") == 0
    lay = layout()
    flags = ["--remove-config"] if remove_config else []
    assert run("--yes", "uninstall", *flags) == 0
    assert lay.installation_file.exists() is not remove_config
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    assert json.loads(lay.installation_file.read_text())["direction"] == ("piyti" if remove_config else "thears")


def test_direction_modified_metadata_has_uninstall_protection(system, home):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    lay = layout()
    text = '{"direction":"thears","user":"keep"}'
    lay.installation_file.write_text(text)
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert lay.installation_file.read_text() == text
    assert run("--yes", "uninstall", "--remove-config", "--force") == 0
    assert not lay.installation_file.exists()


def test_schema_file_is_up_to_date(tmp_path):
    if shutil.which("node") is None:
        pytest.skip("node not installed")
    script = tmp_path / "gen.mjs"
    script.write_text(f'import {{ toJsonSchema }} from "{ROOT}/shell/lib/config.mjs"; process.stdout.write(JSON.stringify(toJsonSchema(), null, 2) + "\\n");')
    out = subprocess.run(["node", str(script)], capture_output=True, text=True, check=True).stdout
    assert out == (ROOT / "shell" / "schema" / "config.schema.json").read_text(), "run: node tools/gen-schema.mjs"


def test_include_round_trip_is_byte_exact(tmp_path, home):
    lay = layout()
    lay.hypr.mkdir(parents=True, exist_ok=True)
    for original in ("", "a\n", "a\nb", "x\n\n\n"):
        main = lay.hypr / "hyprland.lua"
        main.write_text(original)
        m = Manifest()
        entry = hypr.add_include(main, lay, "lua", m)
        assert hypr.BEGIN_LUA in main.read_text()
        hypr.remove_include(entry)
        got = main.read_text()
        assert got == original, repr((original, got))


def test_prune_removes_bytecode_cache_but_not_user_files(tmp_path):
    from aerolith_install.manifest import Manifest, RemovalReport, prune_dirs

    owned = tmp_path / "owned"
    (owned / "__pycache__").mkdir(parents=True)
    (owned / "__pycache__" / "x.cpython-313.pyc").write_bytes(b"\0")
    mixed = tmp_path / "mixed"
    (mixed / "__pycache__").mkdir(parents=True)
    (mixed / "__pycache__" / "x.cpython-313.pyc").write_bytes(b"\0")
    (mixed / "__pycache__" / "notes.txt").write_text("mine")
    m = Manifest()
    m.record_dir(owned)
    m.record_dir(mixed)
    rep = RemovalReport()
    prune_dirs(m, owned, rep)
    prune_dirs(m, mixed, rep)
    assert not owned.exists()
    assert (mixed / "__pycache__" / "notes.txt").read_text() == "mine"
    assert str(mixed) in rep.dirs_kept


# --- SYSTEM PACKAGE MODE ------------------------------------------------------------
# The Arch packages put a read-only tree in /usr/share/aerolith (marked by
# PACKAGED); `aerolith install` then writes only the user's own files.

_PYC = shutil.ignore_patterns("__pycache__", "*.pyc")


@pytest.fixture
def packaged(tmp_path, monkeypatch):
    """A tree laid out as packaging/arch/PKGBUILD installs the aerolith package."""
    root = tmp_path / "usr-share-aerolith"
    shutil.copytree(ROOT / "shell", root / "shell", ignore=_PYC)
    shutil.copytree(ROOT / "installer", root / "installer", ignore=_PYC)
    (root / "PACKAGED").write_text("aerolith 0.1.0\n")
    monkeypatch.setenv("AEROLITH_SYSTEM_ROOT", str(root))
    return root


def add_ai_package(root: Path) -> None:
    """What the aerolith-ai-bridge package adds to the tree."""
    ai = root / "shell" / "modules" / "ai"
    shutil.copytree(ROOT / "ai-bridge" / "aerolith_ai", ai / "bridge" / "aerolith_ai", ignore=_PYC)
    shutil.copy2(ROOT / "ai-bridge" / "qml" / "AiModule.qml", ai / "AiModule.qml")
    shutil.copy2(ROOT / "ai-bridge" / "aerolith-ai-bridge", ai / "bridge" / "aerolith-ai-bridge")


def snapshot(root: Path) -> dict[str, str]:
    from aerolith_install.manifest import sha256

    return {str(p.relative_to(root)): sha256(p) for p in sorted(root.rglob("*")) if p.is_file()}


@pytest.mark.parametrize("direction", [None, "thears"])
def test_system_mode_none_writes_only_user_files(system, home, packaged, direction):
    main = lua_main(home)
    before = snapshot(packaged)
    flags = ["--direction", direction] if direction else []
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland", *flags) == 0
    lay = layout()
    assert lay.mode == "system" and lay.shell == packaged / "shell"
    assert snapshot(packaged) == before, "the packaged tree is pacman's and must not change"
    assert not (home / ".local" / "share" / "aerolith").exists(), "no copy of the shell in system mode"
    assert not (home / ".local" / "bin" / "aerolith").exists(), "the package provides /usr/bin/aerolith"
    m = Manifest.load(lay.manifest)
    assert m.mode == "system" and m.ai_provider == "none"
    assert json.loads(lay.installation_file.read_text())["direction"] == (direction or "piyti")
    assert all(Path(f.path).is_relative_to(home) for f in m.files), [f.path for f in m.files]
    frag = (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert str(packaged / "shell") in frag, "autostart runs the packaged shell"
    assert 'pcall(require, "aerolith/aerolith")' in main.read_text()
    assert not lay.ai_file.exists()
    assert run("--yes", "install", "--startup", "hyprland") == 0
    assert json.loads(lay.installation_file.read_text())["direction"] == (direction or "piyti")
    assert snapshot(packaged) == before


def test_system_mode_ai_needs_the_bridge_package(system, home, packaged, fake_claude, capsys):
    main = lua_main(home)
    assert run("--yes", "install", "--ai", "claude", "--startup", "hyprland") == 2
    assert "aerolith-ai-bridge" in capsys.readouterr().err
    assert main.read_text() == LUA_CONFIG
    assert not layout().manifest.exists()


def test_system_mode_ai_then_remove_keeps_package_files(system, home, packaged, fake_claude, capsys):
    lua_main(home)
    add_ai_package(packaged)
    before = snapshot(packaged)
    assert run("--yes", "install", "--ai", "claude", "--startup", "hyprland") == 0
    lay = layout()
    m = Manifest.load(lay.manifest)
    assert [f.path for f in m.component_files("ai")] == [str(lay.ai_file)], "only ai.json is the user's"
    assert json.loads(lay.ai_file.read_text())["provider"] == "claude"
    assert "aerolith:ai" in (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    capsys.readouterr()
    assert run("--yes", "ai", "remove") == 0
    out = capsys.readouterr().out
    assert not lay.ai_file.exists()
    assert snapshot(packaged) == before, "package files untouched by ai remove"
    assert "sudo pacman -R aerolith-ai-bridge" in out
    assert "aerolith:ai" not in (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert Manifest.load(lay.manifest).ai_provider == "none"


def test_system_mode_uninstall_restores_config_and_leaves_package(system, home, packaged, capsys):
    main = lua_main(home)
    before = snapshot(packaged)
    assert run("--yes", "install", "--ai", "none", "--startup", "systemd") == 0
    svc = layout().service.read_text()
    assert f"-p {packaged / 'shell'}" in svc
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert main.read_text() == LUA_CONFIG
    assert snapshot(packaged) == before
    assert not layout().manifest.exists()
    assert "sudo pacman -R aerolith" in capsys.readouterr().out


def test_user_and_system_installs_are_not_mixed(system, home, tmp_path, monkeypatch, capsys):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    root = tmp_path / "pkg"
    shutil.copytree(ROOT / "shell", root / "shell", ignore=_PYC)
    (root / "PACKAGED").write_text("aerolith\n")
    monkeypatch.setenv("AEROLITH_SYSTEM_ROOT", str(root))
    capsys.readouterr()
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 2
    assert "~/.local/bin/aerolith" in capsys.readouterr().err
    assert (home / ".local" / "share" / "aerolith" / "shell" / "shell.qml").is_file(), "user install untouched"


# --- C05: opt-in application themes --------------------------------------------------

@pytest.fixture
def theme_home(home, monkeypatch):
    """Only the C01 ownership contract; no host binaries or app processes."""
    monkeypatch.setenv("AEROLITH_ALLOW_ROOT", "1")
    monkeypatch.setattr(themes, "activate", themes.activation)
    lay = layout()
    m = Manifest(source=str(ROOT))
    m.save(lay.manifest)
    lay.config.mkdir(parents=True, exist_ok=True)
    lay.installation_file.write_text('{"direction":"thears"}')
    lay.config_file.write_text('{"theme":{"scheme":"bathyal"}}')
    return lay


def theme_config(lay, app):
    return lay.config.parent / {
        "kitty": "kitty/kitty.conf", "alacritty": "alacritty/alacritty.toml",
        "foot": "foot/foot.ini", "hyprland": "hypr/hyprland.lua",
        "gtk3": "gtk-3.0/gtk.css", "gtk4": "gtk-4.0/gtk.css",
        "btop": "btop/btop.conf", "qt5ct": "qt5ct/qt5ct.conf", "qt6ct": "qt6ct/qt6ct.conf",
    }[app]


def theme_original(app, state):
    if state == "missing":
        return None
    existing = {
        "alacritty": b'[window]\nopacity = 0.8',
        "foot": b'font=monospace:size=10\n[colors-dark]\nbackground=000000',
        "hyprland": b'-- keep my config\r\nhl.config({})',
        "gtk3": b'/* custom */\r\nbutton { padding: 5px; }',
        "gtk4": b'/* custom */\r\nbutton { padding: 5px; }',
        "qt5ct": b'[Appearance]\nstyle=custom', "qt6ct": b'[Appearance]\nstyle=custom',
    }.get(app, b'# my config without final newline')
    if state == "include":
        return {
            "kitty": b'include other.conf\n# keep',
            "alacritty": b'[general]\nimport = ["other.toml", # a ] in a comment\n "second.toml",]\n[window]\nopacity = 0.8',
            "foot": b'include=/tmp/other.ini\n[main]\nfont=monospace:size=10',
            "hyprland": b'dofile("/tmp/other.lua")\n-- keep',
            "gtk3": b'@import url("other.css");\n/* keep */',
            "gtk4": b'@import url("other.css");\n/* keep */',
        }.get(app, existing)
    return existing


def home_bytes(home):
    return {str(p.relative_to(home)): p.read_bytes() for p in home.rglob("*") if p.is_file()}


@pytest.mark.parametrize("app", themes.SUPPORTED)
@pytest.mark.parametrize("state", ["missing", "existing", "include"])
def test_theme_roundtrip_and_idempotence(theme_home, app, state):
    lay = theme_home
    path = theme_config(lay, app)
    original = theme_original(app, state)
    if original is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(original)
        path.chmod(0o640)
    assert run("themes", "apply", app) == 0
    m = Manifest.load(lay.manifest)
    assert m.themes[app]["scheme"] == "bathyal"
    assert m.themes[app]["direction"] == "thears"
    entries = m.component_files(themes.component(app))
    assert entries
    for e in m.edits:
        assert e.inserted
        if original is not None:
            assert Path(e.backup).read_bytes() == original
            assert path.stat().st_mode & 0o777 == 0o640
    if app == "alacritty":
        import tomllib
        imported = tomllib.loads(path.read_text())["general"]["import"]
        assert any("aerolith.toml" in p for p in imported)
        if state == "include":
            assert imported[:2] == ["other.toml", "second.toml"]
    before = home_bytes(lay.home)
    assert run("themes", "apply", app) == 0
    after = home_bytes(lay.home)
    before.pop(str(lay.manifest.relative_to(lay.home)))
    after.pop(str(lay.manifest.relative_to(lay.home)))
    assert before == after
    assert len(Manifest.load(lay.manifest).edits) == len(m.edits)
    assert next(r for r in themes.status(lay, Manifest.load(lay.manifest)) if r["app"] == app)["applied"]
    assert run("themes", "remove", app) == 0
    assert not Manifest.load(lay.manifest).component_files(themes.component(app))
    assert not Manifest.load(lay.manifest).edits
    assert not Manifest.load(lay.manifest).themes
    if original is None:
        assert not path.exists()
    else:
        assert path.read_bytes() == original
    assert all(not Path(e.path).exists() for e in entries)
    assert run("themes", "remove", app) == 0


@pytest.mark.parametrize("app", themes.SUPPORTED)
def test_theme_remove_keeps_user_edits(theme_home, app):
    lay = theme_home
    path = theme_config(lay, app)
    original = theme_original(app, "existing")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(original)
    assert run("themes", "apply", app) == 0
    extra = b'\n/* user addition */\n' if app in ("gtk3", "gtk4") else b'\n# user addition\n'
    path.write_bytes(path.read_bytes() + extra)
    assert run("themes", "remove", app) == 0
    assert path.read_bytes() == original + extra


@pytest.mark.parametrize("app", themes.SUPPORTED)
def test_theme_dry_run_and_collision_refusal(theme_home, app):
    lay = theme_home
    before = home_bytes(lay.home)
    assert run("themes", "apply", app, "--scheme", "iris", "--dry-run") == 0
    assert home_bytes(lay.home) == before
    m = Manifest.load(lay.manifest)
    p = themes.prepare_app(lay, m, ROOT / "themes", app, "iris", "thears").files[0][0]
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("user-owned theme")
    before = home_bytes(lay.home)
    assert run("themes", "apply", app) == 2
    assert home_bytes(lay.home) == before


@pytest.mark.parametrize("app", themes.SUPPORTED)
def test_theme_full_uninstall_restores_original(theme_home, app):
    lay = theme_home
    path = theme_config(lay, app)
    original = theme_original(app, "include")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(original)
    assert run("themes", "apply", app) == 0
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert path.read_bytes() == original
    assert not lay.manifest.exists()
    assert not (lay.data / "themes").exists()


def test_themes_default_none_and_explicit_install(system, home):
    main = lua_main(home)
    main.write_bytes(b'-- original without final newline')
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    lay = layout()
    assert not Manifest.load(lay.manifest).themes
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--themes", "kitty,foot,hyprland", "--direction", "thears") == 0
    m = Manifest.load(lay.manifest)
    assert set(m.themes) == {"kitty", "foot", "hyprland"}
    assert all(t["direction"] == "thears" for t in m.themes.values())
    assert run("hypr", "remove") == 0
    assert "theme:hyprland" in main.read_text()
    assert "theme:kitty" in theme_config(lay, "kitty").read_text()
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--no-themes") == 0
    assert set(Manifest.load(lay.manifest).themes) == {"kitty", "foot", "hyprland"}
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert main.read_bytes() == b'-- original without final newline'
    assert not lay.data.exists()


def test_theme_interactive_selection(monkeypatch):
    from aerolith_install.ui import Ui
    ui = Ui(interactive=True)
    answers = iter(["", "kitty,foot", "invalid", "gtk3"])
    monkeypatch.setattr("builtins.input", lambda _: next(answers))
    assert ui.select_themes(themes.SUPPORTED) == []
    assert ui.select_themes(themes.SUPPORTED) == ["kitty", "foot"]
    assert ui.select_themes(themes.SUPPORTED) == ["gtk3"]
    assert Ui(assume_yes=True, interactive=True).select_themes(themes.SUPPORTED) == []
    assert Ui(interactive=False).select_themes(themes.SUPPORTED) == []


@pytest.mark.parametrize("scheme", ["iris", "limb", "glacial"])
def test_theme_explicit_scheme_and_direction(theme_home, scheme):
    lay = theme_home
    lay.installation_file.write_text('{"direction":"piyti"}')
    assert run("themes", "apply", "hyprland", "kitty", "--scheme", scheme) == 0
    m = Manifest.load(lay.manifest)
    target = lay.data / "themes/hyprland/direction.lua"
    assert target.read_bytes() == (ROOT / f"themes/schemes/{scheme}/hyprland/piyti.lua").read_bytes()
    assert (lay.data / "themes/kitty/aerolith.conf").read_bytes() == (ROOT / f"themes/schemes/{scheme}/kitty/aerolith.conf").read_bytes()
    assert m.themes["hyprland"]["direction"] == "piyti"


def test_theme_status_without_install_and_detection(home, monkeypatch, capsys):
    monkeypatch.setenv("AEROLITH_ALLOW_ROOT", "1")
    (home / ".config/kitty").mkdir()
    assert run("themes", "list") == 0
    assert "Millennium" in capsys.readouterr().out
    assert run("themes", "status", "--json") == 0
    rows = json.loads(capsys.readouterr().out)["apps"]
    assert next(r for r in rows if r["app"] == "kitty")["detected"]
    assert not any(r["applied"] for r in rows)
    assert not next(r for r in rows if r["app"] == "firefox")["supported"]
    assert run("themes", "apply", "kitty") == 2


@pytest.mark.parametrize("value", ["../limb", "absent", "Limb"])
def test_theme_invalid_scheme_is_read_only(theme_home, value):
    before = home_bytes(theme_home.home)
    assert run("themes", "apply", "kitty", "--scheme", value) == 2
    assert home_bytes(theme_home.home) == before


@pytest.mark.parametrize("app", ["steam", "discord", "firefox", "libreoffice", "artcraft", "unknown"])
def test_theme_deferred_apps_refuse_whole_batch(theme_home, app):
    before = home_bytes(theme_home.home)
    assert run("themes", "apply", "kitty", app) == 2
    assert home_bytes(theme_home.home) == before


def test_theme_missing_scheme_defaults_and_broken_metadata(theme_home):
    lay = theme_home
    lay.config_file.unlink()
    lay.installation_file.unlink()
    assert run("themes", "apply", "kitty") == 0
    assert Manifest.load(lay.manifest).themes["kitty"]["scheme"] == "limb"
    lay.installation_file.write_text("{")
    before = home_bytes(lay.home)
    assert run("themes", "apply", "foot") == 2
    assert home_bytes(lay.home) == before


def test_theme_symlink_and_modified_asset_protection(theme_home):
    lay = theme_home
    user = lay.home / "user.conf"
    user.write_text("keep")
    path = theme_config(lay, "kitty")
    path.parent.mkdir(parents=True)
    path.symlink_to(user)
    assert run("themes", "apply", "kitty") == 2
    assert user.read_text() == "keep"
    path.unlink()
    assert run("themes", "apply", "kitty") == 0
    target = lay.data / "themes/kitty/aerolith.conf"
    target.write_text("user-modified theme")
    assert not next(r for r in themes.status(lay, Manifest.load(lay.manifest)) if r["app"] == "kitty")["applied"]
    assert run("themes", "apply", "kitty", "--scheme", "iris") == 2
    assert run("themes", "remove", "kitty") == 0
    assert target.read_text() == "user-modified theme"
    assert Manifest.load(lay.manifest).find(target)


def test_theme_modified_and_incomplete_markers(theme_home):
    lay = theme_home
    assert run("themes", "apply", "kitty") == 0
    path = theme_config(lay, "kitty")
    entry = Manifest.load(lay.manifest).edits[0]
    path.write_text("# outside\n" + path.read_text().replace("include ", "include  ") + "# user\n")
    assert run("themes", "apply", "kitty") == 2
    assert run("themes", "remove", "kitty") == 0
    assert path.read_text() == "# outside\n# user\n"
    assert run("themes", "apply", "kitty") == 0
    path.write_text(path.read_text().replace(entry.end, "# user removed end"))
    before = home_bytes(lay.home)
    assert run("themes", "remove", "kitty") == 2
    assert home_bytes(lay.home) == before


@pytest.mark.parametrize("original", ['[general]\nimport=[]', '[general]\nimport=["other"]', '[general]\nimport=["other",]', '[general]', '[window]\nopacity=1.0\n[general]\n# comment\n[font]\nsize=12'])
def test_alacritty_import_shapes(theme_home, original):
    path = theme_config(theme_home, "alacritty")
    path.parent.mkdir(parents=True)
    path.write_text(original)
    assert run("themes", "apply", "alacritty") == 0
    assert run("themes", "remove", "alacritty") == 0
    assert path.read_text() == original


@pytest.mark.parametrize("original", ['import=["old"]', 'general={import=["other"]}', '[general\n', 'general.import=["other"]'])
def test_alacritty_ambiguous_config_refused(theme_home, original):
    path = theme_config(theme_home, "alacritty")
    path.parent.mkdir(parents=True)
    path.write_text(original)
    before = home_bytes(theme_home.home)
    assert run("themes", "apply", "alacritty") == 2
    assert home_bytes(theme_home.home) == before


def test_theme_install_preflight_and_dry_run(system, home):
    lua_main(home)
    before = home_bytes(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--themes", "kitty,foot,hyprland", "--dry-run") == 0
    assert home_bytes(home) == before
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--themes", "kitty,steam") == 2
    assert home_bytes(home) == before
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--themes", "hyprland", "--no-hypr") == 2
    assert home_bytes(home) == before


def test_theme_reapply_changes_scheme_and_direction(theme_home):
    lay = theme_home
    assert run("themes", "apply", "hyprland", "kitty") == 0
    path = theme_config(lay, "hyprland")
    before = path.read_bytes()
    lay.installation_file.write_text('{"direction":"piyti"}')
    assert run("themes", "apply", "hyprland", "kitty", "--scheme", "iris") == 0
    assert path.read_bytes() == before
    assert (lay.data / "themes/hyprland/direction.lua").read_bytes() == (ROOT / "themes/schemes/iris/hyprland/piyti.lua").read_bytes()
    assert run("themes", "remove", "hyprland", "kitty") == 0
    assert not path.exists()


def test_theme_hyprlang_uses_existing_dialect(theme_home):
    lay = theme_home
    path = lay.hypr / "hyprland.conf"
    path.parent.mkdir(parents=True)
    original = b'source = /tmp/other.conf\r\n# keep'
    path.write_bytes(original)
    assert run("themes", "apply", "hyprland") == 0
    assert "source = " + str(lay.data / "themes/hyprland/direction.conf") in path.read_text()
    assert not (lay.hypr / "hyprland.lua").exists()
    assert run("themes", "remove", "hyprland") == 0
    assert path.read_bytes() == original


def test_theme_catalog_survives_source_checkout_removal(system, home, monkeypatch):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--no-themes") == 0
    lay = layout()
    m = Manifest.load(lay.manifest)
    m.source = str(home / "nonexistent-checkout")
    m.save(lay.manifest)
    monkeypatch.setattr(themes, "source_root", lambda: None)
    assert run("themes", "apply", "kitty", "--scheme", "corona") == 0
    assert (lay.data / "themes/kitty/aerolith.conf").read_bytes() == (ROOT / "themes/schemes/corona/kitty/aerolith.conf").read_bytes()


def test_theme_packaged_catalog_is_read_only(theme_home, monkeypatch):
    lay = theme_home
    package = lay.home / "package"
    (package / "shell").mkdir(parents=True)
    (package / "shell/shell.qml").write_text("// package")
    (package / "PACKAGED").touch()
    shutil.copytree(ROOT / "themes/schemes", package / "themes/schemes")
    before = home_bytes(package)
    monkeypatch.setenv("AEROLITH_SYSTEM_ROOT", str(package))
    lay = layout()
    m = Manifest.load(lay.manifest)
    m.mode, m.source = "system", ""
    m.save(lay.manifest)
    monkeypatch.setattr(themes, "source_root", lambda: None)
    assert run("themes", "apply", "kitty", "qt5ct") == 0
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert home_bytes(package) == before


def test_theme_missing_assets_and_legacy_manifest(theme_home, monkeypatch):
    lay = theme_home
    data = json.loads(lay.manifest.read_text())
    data.pop("themes")
    data["source"] = ""
    lay.manifest.write_text(json.dumps(data))
    assert Manifest.load(lay.manifest).themes == {}
    monkeypatch.setattr(themes, "source_root", lambda: None)
    before = home_bytes(lay.home)
    assert run("themes", "apply", "kitty") == 2
    assert home_bytes(lay.home) == before


def test_theme_unknown_or_unsafe_batch_removal_is_read_only(theme_home):
    assert run("themes", "apply", "kitty") == 0
    before = home_bytes(theme_home.home)
    assert run("themes", "remove", "kitty", "unknown") == 2
    assert home_bytes(theme_home.home) == before


def test_theme_failure_records_recoverable_progress(theme_home, monkeypatch):
    lay = theme_home
    original_write = themes.atomic_write
    def fail_on_config(path, data, mode=0o644):
        if path == theme_config(lay, "kitty"):
            raise OSError("simulated config write failure")
        original_write(path, data, mode)
    monkeypatch.setattr(themes, "atomic_write", fail_on_config)
    assert run("themes", "apply", "kitty") == 2
    assert Manifest.load(lay.manifest).component_files("theme:kitty")
    assert not theme_config(lay, "kitty").exists()
    assert run("themes", "remove", "kitty") == 0
    assert not Manifest.load(lay.manifest).component_files("theme:kitty")


def test_alacritty_section_text_in_string_is_refused(theme_home):
    path = theme_config(theme_home, "alacritty")
    path.parent.mkdir(parents=True)
    original = 'note="""\n[general]\nhello\n"""\n[general]\nimport=["other"]'
    path.write_text(original)
    before = home_bytes(theme_home.home)
    assert run("themes", "apply", "alacritty") == 2
    assert home_bytes(theme_home.home) == before


def test_theme_orphan_include_and_alternate_alacritty_refused(theme_home):
    lay = theme_home
    path = theme_config(lay, "kitty")
    path.parent.mkdir(parents=True)
    path.write_text("# >>> AEROLITH theme:kitty\ninclude orphan\n# <<< AEROLITH theme:kitty\n")
    before = home_bytes(lay.home)
    assert run("themes", "apply", "kitty") == 2
    assert home_bytes(lay.home) == before
    alternate = lay.home / ".alacritty.toml"
    alternate.write_text("# real config")
    before = home_bytes(lay.home)
    assert run("themes", "apply", "alacritty") == 2
    assert home_bytes(lay.home) == before


def test_theme_install_switches_are_exclusive():
    with pytest.raises(SystemExit) as exc:
        cli.build_parser().parse_args(["install", "--themes", "kitty", "--no-themes"])
    assert exc.value.code == 2


def test_theme_created_hypr_config_with_later_startup_integration(system, home):
    # First install skips startup integration because no Hyprland config
    # exists yet, but explicit theming creates its minimal normal config.
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--themes", "hyprland") == 0
    path = layout().hypr / "hyprland.lua"
    assert path.is_file()
    # A later installer run adds startup to that same owned config.
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--no-themes") == 0
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert not path.exists()


def test_gtk_import_keeps_unicode_paths(theme_home, monkeypatch):
    lay = theme_home
    monkeypatch.setenv("XDG_DATA_HOME", str(lay.home / "données"))
    assert run("themes", "apply", "gtk3", "gtk4") == 0
    for app in ("gtk3", "gtk4"):
        text = theme_config(lay, app).read_text()
        assert "données" in text and "\\u00e9" not in text
    assert run("themes", "remove", "gtk3", "gtk4") == 0


# --- C06: consent-preserving payload refresh --------------------------------------

@pytest.mark.parametrize("app", themes.SUPPORTED)
def test_refresh_roundtrip_applied_only(theme_home, app, capsys):
    lay = theme_home
    main = theme_config(lay, app)
    main.parent.mkdir(parents=True, exist_ok=True)
    original = theme_original(app, "existing")
    main.write_bytes(original)
    assert run("themes", "apply", app) == 0
    include = main.read_bytes()
    unapplied = lay.config.parent / "unapplied/config"
    unapplied.parent.mkdir()
    unapplied.write_bytes(b"user bytes\r\n")
    for scheme in ("iris", "corona"):
        lay.config_file.write_text(json.dumps({"theme": {"scheme": scheme}}))
        capsys.readouterr()
        assert run("themes", "refresh", "--json") == 0
        result = json.loads(capsys.readouterr().out)
        assert [(r["app"], r["status"]) for r in result["apps"]] == [(app, "refreshed")]
        assert main.read_bytes() == include
        m = Manifest.load(lay.manifest)
        plan = themes.prepare_app(lay, m, ROOT / "themes", app, scheme, "thears")
        assert all(path.read_bytes() == data.encode() for path, data in plan.files)
        assert m.themes[app]["scheme"] == scheme
    assert unapplied.read_bytes() == b"user bytes\r\n"
    assert list((lay.backups / "themes").iterdir())
    assert run("--yes", "uninstall", "--remove-config") == 0
    assert main.read_bytes() == original
    assert unapplied.read_bytes() == b"user bytes\r\n"


def test_refresh_skips_modified_and_incomplete_apps(theme_home, capsys):
    lay = theme_home
    assert run("themes", "apply", "kitty", "qt5ct", "foot") == 0
    kitty = lay.data / "themes/kitty/aerolith.conf"
    kitty.write_bytes(b"user custom palette")
    theme_config(lay, "foot").unlink()  # never recreate an include
    qt = lay.config.parent / "qt5ct/qss/aerolith.qss"
    qt.unlink()  # never grow an incomplete deployment
    capsys.readouterr()
    assert run("themes", "refresh", "--scheme", "iris", "--json") == 2
    rows = json.loads(capsys.readouterr().out)["apps"]
    assert all(r["status"] == "error" for r in rows)
    assert kitty.read_bytes() == b"user custom palette"
    assert not theme_config(lay, "foot").exists()
    assert not qt.exists()


@pytest.mark.parametrize("failure", ["second-payload", "manifest", "after-manifest"])
def test_refresh_rolls_back_one_app_and_continues(theme_home, monkeypatch, capsys, failure):
    lay = theme_home
    assert run("themes", "apply", "qt6ct", "foot") == 0
    m = Manifest.load(lay.manifest)
    before = {e.path: Path(e.path).read_bytes() for e in m.component_files("theme:qt6ct")}
    if failure == "second-payload":
        original_write = themes.atomic_write
        def fail(path, data, mode=0o644):
            if str(path).endswith("qt6ct/colors/aerolith.conf"):
                raise OSError("injected second-payload failure")
            original_write(path, data, mode)
        monkeypatch.setattr(themes, "atomic_write", fail)
    else:
        original_save = Manifest.save
        def fail(self, path):
            if self.themes.get("qt6ct", {}).get("scheme") == "iris":
                if failure == "after-manifest":
                    original_save(self, path)
                raise OSError("injected manifest failure")
            original_save(self, path)
        monkeypatch.setattr(Manifest, "save", fail)
    capsys.readouterr()
    assert run("themes", "refresh", "--scheme", "iris", "--json") == 2
    rows = json.loads(capsys.readouterr().out)["apps"]
    assert [r["status"] for r in rows] == ["error", "refreshed"]
    assert all(Path(p).read_bytes() == data for p, data in before.items())
    m = Manifest.load(lay.manifest)
    assert m.themes["qt6ct"]["scheme"] == "bathyal"
    assert m.themes["foot"]["scheme"] == "iris"
    assert not list(lay.home.rglob(".aerolith-rollback-*"))
    assert run("themes", "remove", "qt6ct", "foot") == 0


def test_refresh_dry_run_empty_and_idempotent(theme_home, monkeypatch, capsys):
    lay = theme_home
    monkeypatch.setattr(themes, "activate", lambda app: pytest.fail("must not activate"))
    capsys.readouterr()
    assert run("themes", "refresh", "--json", "--dry-run") == 0
    assert json.loads(capsys.readouterr().out)["apps"] == []
    assert run("themes", "apply", "foot") == 0
    before = home_bytes(lay.home)
    capsys.readouterr()
    assert run("themes", "refresh", "--scheme", "iris", "--json", "--dry-run") == 0
    assert json.loads(capsys.readouterr().out)["apps"][0]["status"] == "would-refresh"
    assert home_bytes(lay.home) == before
    assert run("themes", "refresh") == 0
    after = home_bytes(lay.home)
    assert run("themes", "refresh") == 0
    assert home_bytes(lay.home) == after


def test_refresh_lock_contention(theme_home, capsys):
    lay = theme_home
    assert run("themes", "apply", "foot") == 0
    with themes.refresh_lock(lay):
        before = home_bytes(lay.home)
        capsys.readouterr()
        assert run("themes", "refresh", "--scheme", "iris", "--json") == 2
        assert "busy" in json.loads(capsys.readouterr().out)["error"]
        assert home_bytes(lay.home) == before
    assert run("themes", "refresh", "--scheme", "iris") == 0


@pytest.mark.parametrize("damage", ["unknown", "catalog", "config", "theme-config", "manifest-json", "manifest-themes", "manifest-file", "manifest-edit"])
def test_refresh_global_refusal_writes_nothing(theme_home, monkeypatch, capsys, damage):
    lay = theme_home
    assert run("themes", "apply", "foot") == 0
    args = ["--scheme", "unknown"] if damage == "unknown" else ["--scheme", "iris"]
    if damage == "catalog":
        monkeypatch.setattr(themes, "assets_root", lambda *a: lay.home / "absent")
    elif damage in ("config", "theme-config"):
        lay.config_file.write_text("{" if damage == "config" else '{"theme":[]}')
    elif damage == "manifest-json":
        lay.manifest.write_text("{")
    elif damage.startswith("manifest-"):
        data = json.loads(lay.manifest.read_text())
        if damage == "manifest-themes":
            data["themes"] = []
        elif damage == "manifest-file":
            data["files"][0]["sha256"] = None
        else:
            data["edits"][0]["inserted"] = []
        lay.manifest.write_text(json.dumps(data))
    before = home_bytes(lay.home)
    capsys.readouterr()
    assert run("themes", "refresh", "--json", *args) == 2
    assert json.loads(capsys.readouterr().out)["error"]
    assert home_bytes(lay.home) == before


def test_refresh_rechecks_payload_before_write(theme_home, monkeypatch):
    lay = theme_home
    assert run("themes", "apply", "kitty") == 0
    execute = themes.execute
    path = lay.data / "themes/kitty/aerolith.conf"
    def race(*args, **kwargs):
        path.write_text("concurrent user edit")
        return execute(*args, **kwargs)
    monkeypatch.setattr(themes, "execute", race)
    assert run("themes", "refresh", "--scheme", "iris") == 2
    assert path.read_text() == "concurrent user edit"


def test_refresh_activation_consent_and_errors(home, monkeypatch):
    calls = []
    def fake_run(argv, **kwargs):
        calls.append(argv)
        assert kwargs["timeout"] == 2
        return subprocess.CompletedProcess(argv, 0, b"", b"")
    monkeypatch.setattr(themes.subprocess, "run", fake_run)
    for app in themes.SUPPORTED:
        themes.activate(app)
    assert calls == [["pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty"], ["hyprctl", "reload"]]
    def timeout(*args, **kwargs):
        raise subprocess.TimeoutExpired(args[0], 2)
    monkeypatch.setattr(themes.subprocess, "run", timeout)
    assert "payload saved" in themes.activate("kitty")


def test_refresh_never_writes_or_activates_unconsented_app(theme_home, monkeypatch):
    lay = theme_home
    path = lay.data / "themes/kitty/aerolith.conf"
    path.parent.mkdir(parents=True)
    path.write_bytes(b"unowned user theme")
    assert run("themes", "apply", "foot") == 0
    calls = []
    monkeypatch.setattr(themes, "activate", lambda app: calls.append(app) or "next start")
    assert run("themes", "refresh", "--scheme", "iris") == 0
    assert calls == ["foot"]
    assert path.read_bytes() == b"unowned user theme"
    assert not theme_config(lay, "kitty").exists()


@pytest.mark.parametrize("interrupt", ["keyboard", "term"])
def test_refresh_interruption_restores_app(theme_home, monkeypatch, interrupt):
    import signal
    lay = theme_home
    assert run("themes", "apply", "qt6ct") == 0
    m = Manifest.load(lay.manifest)
    before = {entry.path: Path(entry.path).read_bytes() for entry in m.component_files("theme:qt6ct")}
    before[str(lay.manifest)] = lay.manifest.read_bytes()
    write = themes.atomic_write
    def interrupted(path, data, mode=0o644):
        if str(path).endswith("qt6ct/colors/aerolith.conf"):
            if interrupt == "term":
                os.kill(os.getpid(), signal.SIGTERM)
            raise KeyboardInterrupt
        write(path, data, mode)
    monkeypatch.setattr(themes, "atomic_write", interrupted)
    old_handler = signal.getsignal(signal.SIGTERM)
    assert run("themes", "refresh", "--scheme", "iris") == 130
    assert all(Path(path).read_bytes() == data for path, data in before.items())
    assert signal.getsignal(signal.SIGTERM) == old_handler
    with themes.refresh_lock(lay):
        pass
