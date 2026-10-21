"""Prompt construction. Everything the provider sees is built here, so the
data that leaves the machine is easy to audit."""

from __future__ import annotations

import json
from typing import Any

SYSTEM_PROMPT = """You are the assistant inside AEROLITH, a desktop shell for Linux (Hyprland).
The user typed a request. Answer briefly and concretely.

You cannot run anything yourself. You may PROPOSE desktop actions, but only
actions from the AVAILABLE ACTIONS list in the request, with arguments that
match their parameters. The user reviews every proposal and decides whether
to run it. Propose nothing if no listed action fits; never invent action ids
or shell commands.

Respond with ONLY a JSON object, no prose before or after it:
{"reply": "<your answer to the user>",
 "proposals": [{"action": "<action id>", "argsJson": "<JSON object of arguments, as a string>", "reason": "<one short sentence>"}]}
Use an empty list when you propose nothing."""


def render_prompt(request: dict[str, Any]) -> str:
    """The user prompt plus the action catalogue and any context the user
    explicitly enabled in ai.json (already filtered by the bridge)."""
    parts = ["USER REQUEST:", str(request.get("prompt", "")).strip(), ""]
    actions = request.get("actions") or []
    if actions:
        parts.append("AVAILABLE ACTIONS (id: title; parameters):")
        for a in actions:
            params = ", ".join(_describe_param(p) for p in a.get("params", []))
            parts.append(f"- {a['id']}: {a.get('title', '')}" + (f"; {params}" if params else ""))
    else:
        parts.append("AVAILABLE ACTIONS: none (answer in text only, propose nothing).")
    context = request.get("context") or {}
    if context:
        parts.append("")
        parts.append("DESKTOP CONTEXT (shared because the user enabled it):")
        parts.append(json.dumps(context, ensure_ascii=False, indent=1)[:6000])
    return "\n".join(parts)


def _describe_param(p: dict[str, Any]) -> str:
    s = f"{p.get('name')}: {p.get('type')}"
    if "min" in p or "max" in p:
        s += f" [{p.get('min', '')}..{p.get('max', '')}]"
    if isinstance(p.get("choices"), list):
        s += " one of " + "|".join(str(c) for c in p["choices"][:12])
    if p.get("required"):
        s += " (required)"
    return s
