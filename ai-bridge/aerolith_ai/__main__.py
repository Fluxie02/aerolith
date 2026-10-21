"""aerolith-ai-bridge: the process the AEROLITH shell starts for one AI request.

Usage
  aerolith-ai-bridge ask       < request.json   -> one JSON result on stdout
  aerolith-ai-bridge status [--auth]            -> provider status (local checks only)
  aerolith-ai-bridge --version

Request (stdin, UTF-8 JSON):
  {"version": 1, "prompt": "...", "actions": [{"id", "title", "params"}],
   "context": {"windowTitles": [...], ...}}

Result (stdout):
  {"version": 1, "ok": true, "provider": "claude", "reply": "...",
   "proposals": [{"action", "args", "reason"}], "warnings": [...], "durationMs": n}
  {"version": 1, "ok": false, "provider": "...", "error": {"code", "message"}}

The process is started only when the user submits a request and exits when
it is answered. SIGTERM (the shell's cancel) stops the provider's whole
process group.
"""

from __future__ import annotations

import json
import signal
import sys
from typing import Any

from . import PROTOCOL_VERSION, __version__
from .config import ConfigError, load
from .proposals import parse_output, validate_catalogue
from .prompting import render_prompt
from .providers import Custom, ProviderError, cancel_active, make

MAX_PROMPT_CHARS = 4000
MAX_REQUEST_BYTES = 256 * 1024


def _emit(obj: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _error(code: str, message: str, provider: str = "") -> dict[str, Any]:
    return {"version": PROTOCOL_VERSION, "ok": False, "provider": provider, "error": {"code": code, "message": message}}


def _on_term(signum: int, frame: Any) -> None:
    cancel_active()
    _emit(_error("cancelled", "the request was cancelled"))
    sys.exit(143)


def filter_context(context: Any, allowed: dict[str, bool]) -> dict[str, Any]:
    """Defence in depth: drop any context the user did not enable in ai.json,
    even if the shell sent it."""
    if not isinstance(context, dict):
        return {}
    return {k: v for k, v in context.items() if allowed.get(k) is True}


def ask(raw: str) -> dict[str, Any]:
    if len(raw.encode("utf-8")) > MAX_REQUEST_BYTES:
        return _error("config_error", "request too large")
    try:
        req = json.loads(raw)
    except json.JSONDecodeError:
        return _error("config_error", "request is not valid JSON")
    if not isinstance(req, dict) or req.get("version") != PROTOCOL_VERSION:
        return _error("config_error", f"unsupported request version (bridge speaks {PROTOCOL_VERSION})")
    prompt = req.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        return _error("config_error", "empty prompt")
    if len(prompt) > MAX_PROMPT_CHARS:
        return _error("config_error", f"prompt longer than {MAX_PROMPT_CHARS} characters")
    try:
        cfg = load()
    except ConfigError as exc:
        return _error("config_error", str(exc))
    if not cfg.enabled:
        return _error("disabled", "AI integration is disabled in ai.json", cfg.provider)
    try:
        actions = validate_catalogue(req.get("actions", [])) if cfg.max_proposals > 0 else []
    except ValueError as exc:
        return _error("config_error", f"invalid action catalogue: {exc}", cfg.provider)
    request = {
        "version": PROTOCOL_VERSION,
        "prompt": prompt.strip(),
        "actions": actions,
        "context": filter_context(req.get("context"), cfg.context),
    }
    try:
        provider = make(cfg)
        if isinstance(provider, Custom):
            text, duration = provider.ask_request(request)
        else:
            text, duration = provider.ask(render_prompt(request))
    except ProviderError as exc:
        return _error(exc.code, exc.message, cfg.provider)
    parsed = parse_output(text, {a["id"] for a in actions}, cfg.max_proposals)
    if not parsed.reply and not parsed.proposals:
        return _error("invalid_output", "the provider returned nothing usable", cfg.provider)
    return {
        "version": PROTOCOL_VERSION,
        "ok": True,
        "provider": cfg.provider,
        "reply": parsed.reply,
        "proposals": parsed.proposals,
        "warnings": parsed.warnings,
        "structured": parsed.structured,
        "durationMs": duration,
    }


def status(check_auth: bool) -> dict[str, Any]:
    try:
        cfg = load()
    except ConfigError as exc:
        return {"version": PROTOCOL_VERSION, "ok": False, "error": {"code": "config_error", "message": str(exc)}}
    out: dict[str, Any] = {
        "version": PROTOCOL_VERSION,
        "ok": True,
        "provider": cfg.provider,
        "enabled": cfg.enabled,
        "context": {k: v for k, v in cfg.context.items() if v},
        "timeoutSeconds": cfg.timeout_seconds,
    }
    try:
        p = make(cfg)
        out.update(display=p.display, remote=p.remote, dataFlow=p.data_flow)
        p.executable()
        out["installed"] = True
        out["providerVersion"] = p.version()
        if check_auth:
            out["authenticated"] = p.auth_status()
    except ProviderError as exc:
        out["installed"] = exc.code != "not_installed" and exc.code != "config_error"
        out["problem"] = {"code": exc.code, "message": exc.message}
    return out


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv[0] == "--version":
        print(f"aerolith-ai-bridge {__version__} (protocol {PROTOCOL_VERSION})")
        return 0
    if argv[0] == "ask":
        signal.signal(signal.SIGTERM, _on_term)
        _emit(ask(sys.stdin.read()))
        return 0
    if argv[0] == "status":
        _emit(status("--auth" in argv[1:]))
        return 0
    print(f"unknown command {argv[0]!r}; see --help", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
