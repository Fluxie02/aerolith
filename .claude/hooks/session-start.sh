#!/bin/bash
# Prepares Codex for Claude Code cloud sessions: installs the Codex CLI and
# builds codex-mcp-bridge. The Codex login itself is never stored here; it
# has to be redone in each new container (see codex-mcp-bridge/README.md).
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

CODEX_VERSION="0.163.0"
if [ "$(codex --version 2>/dev/null || true)" != "codex-cli $CODEX_VERSION" ]; then
  npm install -g "@openai/codex@$CODEX_VERSION" --no-fund --no-audit >&2
fi

(cd codex-mcp-bridge && npm install --no-fund --no-audit >&2 && npm run build >&2)

# agent-sync watcher and its tests (tools/agent-sync/README.md).
python3 -m pip install --quiet -r tools/agent-sync/requirements.txt pytest >&2

# Anything printed to stdout is added to Claude's context for the session.
# The bridge uses these ChatGPT accounts in this order (CODEX_ACCOUNTS in .mcp.json);
# each keeps its own login in ~/.codex-accounts/<name>.
for account in mine dad; do
  home="$HOME/.codex-accounts/$account"
  mkdir -p "$home" && chmod 700 "$home"
  if CODEX_HOME="$home" codex login status >/dev/null 2>&1; then
    echo "Codex account '$account' is logged in."
  else
    echo "Codex account '$account' is NOT logged in (new container). To log in, run"
    echo "'CODEX_HOME=$home codex login --device-auth' in the background and give the user"
    echo "the link and one-time code; the owner of the '$account' ChatGPT account must enter it within 15 minutes."
  fi
done
