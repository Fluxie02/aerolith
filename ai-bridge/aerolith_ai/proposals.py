"""Turning provider output into a reply and validated action proposals.

Provider output is untrusted. This module:
  - extracts the JSON envelope the system prompt asks for, tolerating code
    fences and surrounding prose;
  - falls back to treating the whole output as a plain reply (with no
    proposals) when there is no valid envelope, instead of guessing;
  - keeps only proposals whose action is in the catalogue the shell sent,
    with an object of arguments, bounded in number and size.

Argument *values* are checked again by the shell against the live command
registry before anything is shown for approval.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any

MAX_REPLY_CHARS = 8000
MAX_REASON_CHARS = 300
MAX_ARGS_BYTES = 2000

_FENCE = re.compile(r"```(?:json)?\s*(\{.*?\})\s*```", re.S)


@dataclass
class Parsed:
    reply: str
    proposals: list[dict[str, Any]]
    warnings: list[str]
    structured: bool


def _candidates(text: str) -> list[str]:
    out = [m.group(1) for m in _FENCE.finditer(text)]
    stripped = text.strip()
    if stripped.startswith("{") and stripped.endswith("}"):
        out.append(stripped)
    # First balanced {...} span as a last resort.
    start = text.find("{")
    if start != -1:
        depth = 0
        in_str = False
        esc = False
        for i in range(start, len(text)):
            ch = text[i]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
            elif ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    out.append(text[start : i + 1])
                    break
    return out


def _clip(s: str, n: int) -> str:
    return s if len(s) <= n else s[: n - 1] + "…"


def parse_output(text: str, catalogue_ids: set[str], max_proposals: int) -> Parsed:
    warnings: list[str] = []
    if not isinstance(text, str) or not text.strip():
        return Parsed(reply="", proposals=[], warnings=["provider returned an empty answer"], structured=False)
    envelope: dict[str, Any] | None = None
    for cand in _candidates(text):
        try:
            obj = json.loads(cand)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and isinstance(obj.get("reply"), str):
            envelope = obj
            break
    if envelope is None:
        return Parsed(
            reply=_clip(text.strip(), MAX_REPLY_CHARS),
            proposals=[],
            warnings=["provider did not return the structured format; showing its text with no proposed actions"],
            structured=False,
        )

    proposals: list[dict[str, Any]] = []
    raw = envelope.get("proposals", [])
    if not isinstance(raw, list):
        warnings.append("ignored 'proposals' because it is not a list")
        raw = []
    for i, p in enumerate(raw):
        if len(proposals) >= max_proposals:
            warnings.append(f"ignored {len(raw) - i} proposal(s) beyond the limit of {max_proposals}")
            break
        if not isinstance(p, dict):
            warnings.append(f"ignored proposal {i + 1}: not an object")
            continue
        action = p.get("action")
        if not isinstance(action, str) or action not in catalogue_ids:
            warnings.append(f"ignored proposal {i + 1}: action {action!r} is not an allowed action")
            continue
        # Arguments arrive either as an object ("args") or, from providers
        # held to a strict output schema, as a JSON string ("argsJson").
        args: Any = p.get("args", None)
        if args is None and isinstance(p.get("argsJson"), str):
            try:
                args = json.loads(p["argsJson"]) if p["argsJson"].strip() else {}
            except json.JSONDecodeError:
                warnings.append(f"ignored proposal {i + 1}: argsJson is not valid JSON")
                continue
        if args is None:
            args = {}
        if not isinstance(args, dict):
            warnings.append(f"ignored proposal {i + 1}: args must be an object")
            continue
        if len(json.dumps(args)) > MAX_ARGS_BYTES:
            warnings.append(f"ignored proposal {i + 1}: arguments too large")
            continue
        reason = p.get("reason", "")
        if not isinstance(reason, str):
            reason = ""
        proposals.append({"action": action, "args": args, "reason": _clip(reason.strip(), MAX_REASON_CHARS)})
    return Parsed(
        reply=_clip(envelope["reply"].strip(), MAX_REPLY_CHARS),
        proposals=proposals,
        warnings=warnings,
        structured=True,
    )


def validate_catalogue(catalogue: Any) -> list[dict[str, Any]]:
    """Sanity-check the action catalogue sent by the shell."""
    if not isinstance(catalogue, list) or len(catalogue) > 200:
        raise ValueError("actions must be a list of at most 200 entries")
    out = []
    for a in catalogue:
        if not isinstance(a, dict) or not isinstance(a.get("id"), str) or not re.fullmatch(r"[a-z][a-z0-9.-]{0,63}", a["id"]):
            raise ValueError("each action needs a valid id")
        params = a.get("params", [])
        if not isinstance(params, list):
            raise ValueError(f"action {a['id']}: params must be a list")
        out.append(
            {
                "id": a["id"],
                "title": str(a.get("title", ""))[:80],
                "params": [
                    {k: v for k, v in p.items() if k in ("name", "type", "min", "max", "choices", "required", "description")}
                    for p in params
                    if isinstance(p, dict)
                ],
            }
        )
    return out


ENVELOPE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "required": ["reply", "proposals"],
    "properties": {
        "reply": {"type": "string"},
        "proposals": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["action", "argsJson", "reason"],
                "properties": {
                    "action": {"type": "string"},
                    "argsJson": {"type": "string"},
                    "reason": {"type": "string"},
                },
            },
        },
    },
}
