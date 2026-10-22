"""Installer, maintenance and removal tests (mock system tools; see conftest.py)."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

from aerolith_install import cli, hypr
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
    assert {Path(f.path).name for f in m.files} == {"config.json", "Theme.qml"}


def test_uninstall_without_manifest_removes_nothing(system, home, capsys):
    (home / ".local" / "share" / "aerolith").mkdir(parents=True)
    (home / ".local" / "share" / "aerolith" / "looks-like-ours.qml").write_text("x")
    assert run("--yes", "uninstall") == 0
    assert (home / ".local" / "share" / "aerolith" / "looks-like-ours.qml").exists()


# --- hyprland details ---------------------------------------------------------------

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


def test_no_hypr_flag_leaves_hyprland_alone(system, home):
    main = lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual", "--no-hypr") == 0
    assert main.read_text() == LUA_CONFIG
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


def test_status_json(system, home, capsys):
    lua_main(home)
    assert run("--yes", "install", "--ai", "none", "--startup", "manual") == 0
    capsys.readouterr()
    assert run("status", "--json") == 0
    s = json.loads(capsys.readouterr().out)
    assert s["installed"] is True and s["ai_provider"] == "none"


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
        assert got == original or (not original.endswith("\n") and got == original + "\n"), repr((original, got))


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


def test_system_mode_none_writes_only_user_files(system, home, packaged):
    main = lua_main(home)
    before = snapshot(packaged)
    assert run("--yes", "install", "--ai", "none", "--startup", "hyprland") == 0
    lay = layout()
    assert lay.mode == "system" and lay.shell == packaged / "shell"
    assert snapshot(packaged) == before, "the packaged tree is pacman's and must not change"
    assert not (home / ".local" / "share" / "aerolith").exists(), "no copy of the shell in system mode"
    assert not (home / ".local" / "bin" / "aerolith").exists(), "the package provides /usr/bin/aerolith"
    m = Manifest.load(lay.manifest)
    assert m.mode == "system" and m.ai_provider == "none"
    assert all(Path(f.path).is_relative_to(home) for f in m.files), [f.path for f in m.files]
    frag = (lay.hypr_fragment_dir / "aerolith.lua").read_text()
    assert str(packaged / "shell") in frag, "autostart runs the packaged shell"
    assert 'pcall(require, "aerolith/aerolith")' in main.read_text()
    assert not lay.ai_file.exists()


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
