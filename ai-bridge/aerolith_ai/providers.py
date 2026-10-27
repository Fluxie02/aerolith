"""Provider adapters.

Each adapter turns a request into one locked-down, non-interactive
invocation of the provider's own CLI (or a custom program), runs it in an
empty private working directory with a timeout, and returns its raw text.

Adapter contract (also what a custom provider implements, see
docs/INTEGRATIONS.md):
  identity      name, remote or local, documentation of data flow
  available()   local checks only (binary present, version); never a
                network request
  auth_status() local, offline check where the CLI offers one
  ask()         one request -> text; timeout and cancellation enforced here
  errors        reported as ProviderError(code, message)
"""

from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import AiConfig, ConfigError, check_executable
from .proposals import ENVELOPE_SCHEMA

MAX_OUTPUT_BYTES = 512 * 1024

# Feature flags passed to `codex --disable`. Verified against codex-cli
# 0.163.0 (`codex features list`). An unknown flag is a hard error in Codex,
# and AEROLITH treats that as "incompatible version" rather than running
# Codex without these restrictions.
CODEX_DISABLED_FEATURES = ("shell_tool", "apps", "plugins", "browser_use", "computer_use", "in_app_browser", "hooks", "memories")


class ProviderError(Exception):
    """A provider failed. `code` is stable and shown to the user."""

    CODES = (
        "not_installed",
        "not_authenticated",
        "timeout",
        "cancelled",
        "provider_error",
        "invalid_output",
        "incompatible_version",
        "config_error",
        "disabled",
    )

    def __init__(self, code: str, message: str):
        assert code in self.CODES, code
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass
class RunResult:
    stdout: str
    stderr: str
    returncode: int
    duration_ms: int


_active: subprocess.Popen[bytes] | None = None


def cancel_active(*_: Any) -> None:
    """SIGTERM handler: stop the provider's whole process group."""
    proc = _active
    if proc is not None and proc.poll() is None:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


def run_locked(argv: list[str], stdin_text: str, timeout: int, cwd: str, env: dict[str, str] | None = None) -> RunResult:
    """Run argv (never through a shell) in its own process group.

    On timeout the whole group gets SIGTERM, then SIGKILL after 3 s, so a
    provider cannot leave helpers running.
    """
    global _active
    start = time.monotonic()
    try:
        proc = subprocess.Popen(
            argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cwd,
            env=env,
            start_new_session=True,
        )
    except FileNotFoundError:
        raise ProviderError("not_installed", f"{argv[0]} was not found") from None
    except PermissionError:
        raise ProviderError("not_installed", f"{argv[0]} is not executable") from None
    _active = proc
    try:
        out, err = proc.communicate(stdin_text.encode("utf-8"), timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=3)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        proc.wait()
        raise ProviderError("timeout", f"no answer within {timeout} s; the request was stopped") from None
    finally:
        _active = None
    if proc.returncode is not None and proc.returncode < 0 and -proc.returncode in (signal.SIGTERM, signal.SIGKILL):
        raise ProviderError("cancelled", "the request was cancelled")
    return RunResult(
        stdout=out[:MAX_OUTPUT_BYTES].decode("utf-8", "replace"),
        stderr=err[:MAX_OUTPUT_BYTES].decode("utf-8", "replace"),
        returncode=proc.returncode,
        duration_ms=int((time.monotonic() - start) * 1000),
    )


def _first_line(s: str, limit: int = 240) -> str:
    for line in s.splitlines():
        line = line.strip()
        if line:
            return line[:limit]
    return ""


def resolve(configured: str, name: str) -> str | None:
    """Find a provider binary: configured path, PATH, or ~/.local/bin."""
    if configured:
        return configured if os.path.exists(configured) else None
    found = shutil.which(name)
    if found:
        return found
    local = os.path.join(os.path.expanduser("~"), ".local", "bin", name)
    return local if os.path.exists(local) else None


class Provider:
    name = "provider"
    display = "Provider"
    remote = True
    data_flow = ""

    def __init__(self, cfg: AiConfig):
        self.cfg = cfg

    def executable(self) -> str:
        raise NotImplementedError

    def version(self) -> str:
        exe = self.executable()
        try:
            r = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=10, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise ProviderError("not_installed", f"{exe} --version failed: {exc}") from None
        return _first_line(r.stdout or r.stderr, 80)

    def auth_status(self) -> bool | None:
        return None

    def build(self, prompt: str, workdir: str) -> tuple[list[str], str, dict[str, Any]]:
        raise NotImplementedError

    def read_answer(self, res: RunResult, extra: dict[str, Any]) -> str:
        raise NotImplementedError

    def ask(self, prompt: str) -> tuple[str, int]:
        workdir = tempfile.mkdtemp(prefix="aerolith-ai-")
        try:
            argv, stdin_text, extra = self.build(prompt, workdir)
            res = run_locked(argv, stdin_text, self.cfg.timeout_seconds, cwd=workdir)
            return self.read_answer(res, extra), res.duration_ms
        finally:
            shutil.rmtree(workdir, ignore_errors=True)


class Claude(Provider):
    name = "claude"
    display = "Claude Code"
    data_flow = (
        "Runs the Claude Code CLI you installed (`claude -p`). Your prompt, the list of allowed "
        "AEROLITH actions and any context you enabled are sent to Anthropic's API under your own "
        "Claude account. All Claude Code tools are disabled for these requests (--tools \"\"), so "
        "it cannot read files or run commands. User/project settings, CLAUDE.md, hooks and installed "
        "plugins are disabled (--setting-sources \"\" and --safe-mode). Shell requests use Haiku "
        "unless you explicitly set a model in ai.json."
    )

    def executable(self) -> str:
        exe = resolve(self.cfg.claude_path, "claude")
        if not exe:
            raise ProviderError(
                "not_installed",
                "Claude Code (`claude`) is not installed. See docs/INTEGRATIONS.md, or run: aerolith ai configure",
            )
        return exe

    def auth_status(self) -> bool | None:
        # `claude auth status` is local and works offline (measured with
        # 2.1.306); it prints JSON with "loggedIn". Only that field is read.
        try:
            r = subprocess.run([self.executable(), "auth", "status"], capture_output=True, text=True, timeout=15, check=False)
            data = json.loads(r.stdout)
            return bool(data.get("loggedIn")) if isinstance(data, dict) else None
        except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError, ProviderError):
            return None

    def build(self, prompt: str, workdir: str) -> tuple[list[str], str, dict[str, Any]]:
        from .prompting import SYSTEM_PROMPT

        argv = [
            self.executable(),
            "-p",
            "--output-format",
            "json",
            "--tools",
            "",
            # Verified with Claude Code 2.1.310 --help. Safe mode also
            # disables CLAUDE.md discovery, which is separate from settings.
            "--setting-sources",
            "",
            "--safe-mode",
            "--no-session-persistence",
            "--strict-mcp-config",
            "--disable-slash-commands",
            "--system-prompt",
            SYSTEM_PROMPT,
        ]
        argv += ["--model", self.cfg.model or "haiku"]
        return argv, prompt, {}

    def read_answer(self, res: RunResult, extra: dict[str, Any]) -> str:
        data: Any = None
        try:
            data = json.loads(res.stdout)
        except json.JSONDecodeError:
            pass
        if not isinstance(data, dict):
            hint = _first_line(res.stderr) or _first_line(res.stdout)
            low = (res.stderr + res.stdout).lower()
            if "log in" in low or "login" in low or "not logged in" in low or "authenticat" in low:
                raise ProviderError("not_authenticated", "Claude Code is not signed in. Run `claude` once in a terminal to sign in.")
            raise ProviderError("provider_error", f"Claude Code failed (exit {res.returncode}): {hint or 'no output'}")
        if data.get("is_error"):
            msg = str(data.get("result") or data.get("subtype") or "error")[:300]
            low = msg.lower()
            if "log in" in low or "login" in low or "authenticat" in low or "api key" in low:
                raise ProviderError("not_authenticated", f"Claude Code: {msg}")
            raise ProviderError("provider_error", f"Claude Code: {msg}")
        result = data.get("result")
        if not isinstance(result, str):
            raise ProviderError("invalid_output", "Claude Code returned no result text")
        return result


class Codex(Provider):
    name = "codex"
    display = "Codex"
    data_flow = (
        "Runs the Codex CLI you installed (`codex exec`). Your prompt, the list of allowed AEROLITH "
        "actions and any context you enabled are sent to OpenAI under your own Codex sign-in. "
        "AEROLITH runs it with a read-only sandbox in an empty folder, ignores your Codex config "
        "file, ignores project instructions and execpolicy rules, and turns off its shell, "
        "plugins, apps, browser, hooks and memory features. Codex cannot be told to skip your "
        "global instructions (~/.codex/AGENTS.md) and skills, so those are sent with each request, "
        "to the same OpenAI account; keep them short, or use Claude, which AEROLITH fully isolates."
    )

    def executable(self) -> str:
        exe = resolve(self.cfg.codex_path, "codex")
        if not exe:
            raise ProviderError(
                "not_installed",
                "Codex (`codex`) is not installed. On Arch: sudo pacman -S openai-codex, or run: aerolith ai configure",
            )
        return exe

    def auth_status(self) -> bool | None:
        # `codex login status` is local and reports through its exit code
        # (measured with 0.163.0). Its output is not read or logged.
        try:
            r = subprocess.run([self.executable(), "login", "status"], capture_output=True, timeout=15, check=False)
            return r.returncode == 0
        except (OSError, subprocess.TimeoutExpired, ProviderError):
            return None

    def build(self, prompt: str, workdir: str) -> tuple[list[str], str, dict[str, Any]]:
        from .prompting import SYSTEM_PROMPT

        # --ignore-user-config only ignores config.toml; an offline probe of
        # 0.163.0 still sent global AGENTS.md with project_doc_max_bytes=0.
        # Refusing would break Codex for nearly everyone (Codex itself creates
        # ~/.codex/skills/.system), so data_flow discloses it instead.
        schema_path = os.path.join(workdir, "aerolith-schema.json")
        out_path = os.path.join(workdir, "aerolith-answer.txt")
        Path(schema_path).write_text(json.dumps(ENVELOPE_SCHEMA), encoding="utf-8")
        argv = [self.executable(), "exec"]
        for feature in CODEX_DISABLED_FEATURES:
            argv += ["--disable", feature]
        argv += [
            "--sandbox",
            "read-only",
            "--ephemeral",
            "--skip-git-repo-check",
            "--ignore-user-config",
            "--ignore-rules",
            "-c",
            "project_doc_max_bytes=0",
            "--color",
            "never",
            "-C",
            workdir,
            "--output-schema",
            schema_path,
            "-o",
            out_path,
        ]
        if self.cfg.model:
            argv += ["-m", self.cfg.model]
        argv.append("-")
        return argv, SYSTEM_PROMPT + "\n\n" + prompt, {"out_path": out_path}

    def read_answer(self, res: RunResult, extra: dict[str, Any]) -> str:
        err = res.stderr
        if "Unknown feature flag" in err:
            raise ProviderError(
                "incompatible_version",
                "This Codex version does not accept AEROLITH's restriction flags; refusing to run it without them.",
            )
        if res.returncode != 0:
            low = err.lower()
            if "not logged in" in low or "login" in low or "authenticat" in low:
                raise ProviderError("not_authenticated", "Codex is not signed in. Run `codex login` in a terminal.")
            raise ProviderError("provider_error", f"Codex failed (exit {res.returncode}): {_first_line(err) or 'no output'}")
        try:
            return Path(extra["out_path"]).read_text(encoding="utf-8")
        except OSError:
            raise ProviderError("invalid_output", "Codex finished without writing an answer") from None


class Custom(Provider):
    name = "custom"
    display = "Custom"
    remote = False
    data_flow = (
        "Runs the program you configured. AEROLITH cannot know where that program sends data; "
        "only use one you trust."
    )

    def __init__(self, cfg: AiConfig):
        super().__init__(cfg)
        if cfg.custom is None:
            raise ProviderError("config_error", "custom provider is not configured")
        self.spec = cfg.custom
        self.display = f"Custom ({self.spec.name})"

    def executable(self) -> str:
        try:
            return check_executable(self.spec.executable, label="custom.executable")
        except ConfigError as exc:
            raise ProviderError("config_error", str(exc)) from None

    def version(self) -> str:
        return self.spec.protocol

    def build(self, prompt: str, workdir: str) -> tuple[list[str], str, dict[str, Any]]:
        raise NotImplementedError  # ask() is overridden: the request is structured

    def ask_request(self, request: dict[str, Any]) -> tuple[str, int]:
        workdir = tempfile.mkdtemp(prefix="aerolith-ai-")
        try:
            argv = [self.executable(), *self.spec.args]
            if self.spec.protocol == "aerolith-v1":
                stdin_text = json.dumps(request)
            else:
                from .prompting import render_prompt

                stdin_text = render_prompt(request)
            res = run_locked(argv, stdin_text, self.cfg.timeout_seconds, cwd=workdir)
            if res.returncode != 0:
                raise ProviderError("provider_error", f"{self.spec.name} exited with {res.returncode}: {_first_line(res.stderr) or 'no output'}")
            if self.spec.protocol == "aerolith-v1":
                try:
                    data = json.loads(res.stdout)
                except json.JSONDecodeError:
                    raise ProviderError("invalid_output", f"{self.spec.name} did not print a JSON object") from None
                if not isinstance(data, dict) or not isinstance(data.get("reply"), str):
                    raise ProviderError("invalid_output", f"{self.spec.name} must print {{\"reply\": \"...\", \"proposals\": [...]}}")
                return json.dumps(data), res.duration_ms
            return json.dumps({"reply": res.stdout.strip(), "proposals": []}), res.duration_ms
        finally:
            shutil.rmtree(workdir, ignore_errors=True)


def make(cfg: AiConfig) -> Provider:
    if cfg.provider == "claude":
        return Claude(cfg)
    if cfg.provider == "codex":
        return Codex(cfg)
    if cfg.provider == "custom":
        return Custom(cfg)
    raise ProviderError("config_error", f"unknown provider {cfg.provider!r}")
