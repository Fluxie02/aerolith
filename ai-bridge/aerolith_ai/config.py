"""ai.json: the AI Bridge's own configuration, separate from config.json.

Removing the AI integration deletes this file and nothing in the core
configuration refers to it. Credentials never go here: providers keep their
own (Claude Code in ~/.claude, Codex in ~/.codex) and the bridge never reads
those directories.
"""

from __future__ import annotations

import json
import os
import stat
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
PROVIDERS = ("claude", "codex", "custom")
CUSTOM_PROTOCOLS = ("aerolith-v1", "text")
CONTEXT_KEYS = ("windowTitles", "workspaces", "audioDevices", "mediaPlaying", "telemetrySummary")

# Keys that look like credentials. Their presence in ai.json is refused so a
# well-meaning user does not end up with a secret in a plain config file.
_SECRET_HINTS = ("apikey", "api_key", "token", "secret", "password", "credential")


class ConfigError(ValueError):
    """ai.json is missing, unreadable or invalid."""


@dataclass
class CustomProvider:
    name: str
    executable: str
    args: list[str]
    protocol: str


@dataclass
class AiConfig:
    provider: str
    enabled: bool = True
    timeout_seconds: int = 90
    model: str = ""
    context: dict[str, bool] = field(default_factory=lambda: {k: False for k in CONTEXT_KEYS})
    max_proposals: int = 5
    claude_path: str = ""
    codex_path: str = ""
    custom: CustomProvider | None = None
    # Paths the installer recorded; informational only.
    installed_by_aerolith: bool = False

    def to_json(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "schemaVersion": SCHEMA_VERSION,
            "provider": self.provider,
            "enabled": self.enabled,
            "timeoutSeconds": self.timeout_seconds,
            "model": self.model,
            "context": dict(self.context),
            "maxProposals": self.max_proposals,
        }
        if self.claude_path:
            out["claude"] = {"executable": self.claude_path}
        if self.codex_path:
            out["codex"] = {"executable": self.codex_path}
        if self.custom:
            out["custom"] = {
                "name": self.custom.name,
                "executable": self.custom.executable,
                "args": list(self.custom.args),
                "protocol": self.custom.protocol,
            }
        return out


def default_path() -> Path:
    base = os.environ.get("AEROLITH_CONFIG_DIR") or os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config"), "aerolith"
    )
    return Path(base) / "ai.json"


def _find_secret_keys(obj: Any, path: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}" if path else str(k)
            if any(h in str(k).lower().replace("-", "_") for h in _SECRET_HINTS):
                found.append(p)
            found.extend(_find_secret_keys(v, p))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            found.extend(_find_secret_keys(v, f"{path}[{i}]"))
    return found


def check_executable(path: str, *, label: str) -> str:
    """Validate an executable path for a provider. Returns the resolved path.

    Requirements: absolute, exists, regular file (after resolving symlinks),
    executable by the user, and not writable by group or others, so another
    local user cannot swap the program the bridge runs.
    """
    if not path or not os.path.isabs(path):
        raise ConfigError(f"{label}: executable must be an absolute path, got {path!r}")
    real = os.path.realpath(path)
    try:
        st = os.stat(real)
    except OSError as exc:
        raise ConfigError(f"{label}: {path} does not exist ({exc.strerror})") from None
    if not stat.S_ISREG(st.st_mode):
        raise ConfigError(f"{label}: {path} is not a regular file")
    if not os.access(real, os.X_OK):
        raise ConfigError(f"{label}: {path} is not executable")
    if st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise ConfigError(f"{label}: {path} is writable by other users; refusing to run it")
    if st.st_uid not in (0, os.getuid()):
        raise ConfigError(f"{label}: {path} is owned by another user; refusing to run it")
    return real


def parse(data: Any) -> AiConfig:
    """Validate a decoded ai.json document. Raises ConfigError."""
    if not isinstance(data, dict):
        raise ConfigError("ai.json must contain a JSON object")
    secrets = _find_secret_keys(data)
    if secrets:
        raise ConfigError(
            "ai.json must not contain credentials (found: "
            + ", ".join(secrets)
            + "). Sign in with the provider's own tool instead."
        )
    version = data.get("schemaVersion", SCHEMA_VERSION)
    if version != SCHEMA_VERSION:
        raise ConfigError(f"unsupported ai.json schemaVersion {version!r}")
    provider = data.get("provider")
    if provider not in PROVIDERS:
        raise ConfigError(f"provider must be one of {', '.join(PROVIDERS)}, got {provider!r}")
    enabled = data.get("enabled", True)
    if not isinstance(enabled, bool):
        raise ConfigError("enabled must be true or false")
    timeout = data.get("timeoutSeconds", 90)
    if not isinstance(timeout, int) or isinstance(timeout, bool) or not 5 <= timeout <= 600:
        raise ConfigError("timeoutSeconds must be a whole number between 5 and 600")
    model = data.get("model", "")
    if not isinstance(model, str) or len(model) > 128 or any(c.isspace() for c in model):
        raise ConfigError("model must be a short name without spaces")
    ctx_in = data.get("context", {})
    if not isinstance(ctx_in, dict):
        raise ConfigError("context must be an object of true/false switches")
    context = {k: False for k in CONTEXT_KEYS}
    for k, v in ctx_in.items():
        if k not in CONTEXT_KEYS:
            raise ConfigError(f"unknown context switch {k!r} (known: {', '.join(CONTEXT_KEYS)})")
        if not isinstance(v, bool):
            raise ConfigError(f"context.{k} must be true or false")
        context[k] = v
    max_props = data.get("maxProposals", 5)
    if not isinstance(max_props, int) or isinstance(max_props, bool) or not 0 <= max_props <= 10:
        raise ConfigError("maxProposals must be between 0 and 10")

    cfg = AiConfig(
        provider=provider,
        enabled=enabled,
        timeout_seconds=timeout,
        model=model,
        context=context,
        max_proposals=max_props,
    )
    for key in ("claude", "codex"):
        section = data.get(key)
        if section is None:
            continue
        if not isinstance(section, dict) or not isinstance(section.get("executable", ""), str):
            raise ConfigError(f"{key}.executable must be a path")
        setattr(cfg, f"{key}_path", section.get("executable", ""))
    if provider == "custom":
        c = data.get("custom")
        if not isinstance(c, dict):
            raise ConfigError("provider 'custom' needs a 'custom' section")
        name = c.get("name", "custom")
        if not isinstance(name, str) or not 1 <= len(name) <= 40:
            raise ConfigError("custom.name must be 1-40 characters")
        exe = c.get("executable")
        if not isinstance(exe, str):
            raise ConfigError("custom.executable must be an absolute path")
        args = c.get("args", [])
        if not isinstance(args, list) or len(args) > 32 or not all(isinstance(a, str) and len(a) < 1024 for a in args):
            raise ConfigError("custom.args must be a list of at most 32 strings")
        protocol = c.get("protocol", "aerolith-v1")
        if protocol not in CUSTOM_PROTOCOLS:
            raise ConfigError(f"custom.protocol must be one of {', '.join(CUSTOM_PROTOCOLS)}")
        cfg.custom = CustomProvider(name=name, executable=exe, args=list(args), protocol=protocol)
    return cfg


def load(path: Path | None = None) -> AiConfig:
    p = path or default_path()
    try:
        text = p.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise ConfigError(f"{p} not found: AI integration is not configured") from None
    except OSError as exc:
        raise ConfigError(f"cannot read {p}: {exc.strerror}") from None
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{p} is not valid JSON: {exc.msg} at line {exc.lineno}") from None
    return parse(data)


def write(cfg: AiConfig, path: Path | None = None) -> Path:
    """Write ai.json atomically with user-only permissions."""
    p = path or default_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + ".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(cfg.to_json(), fh, indent=2)
        fh.write("\n")
    os.replace(tmp, p)
    return p
