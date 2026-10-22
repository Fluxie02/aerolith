# Codex MCP Bridge

Minimal stdio MCP server that lets an MCP-compatible host call the installed Codex CLI without relying on Claude Code's `/plugin` mechanism.

## Tools
- `codex_status`: CLI/auth status and configured repository.
- `codex_design_task`: bounded UI task; Codex can edit files.
- `codex_review_diff`: review-only diff inspection.
- `codex_get_job`: retrieve a saved result.
- `codex_recent_jobs`: list recent jobs.

## Install
Requirements: Node.js 20+, Git repository, Codex CLI installed and authenticated by the account owner.

```bash
npm install
npm run build
export CODEX_MCP_REPO="/absolute/path/to/desktop-shell-repo"
npm start
```

Optional environment variables:
- `CODEX_BIN` defaults to `codex`.
- `CODEX_MCP_TIMEOUT_MS` defaults to 600000 and is capped at 1200000.

## Claude Code configuration
A typical Claude Code `.mcp.json` entry is:

```json
{
  "mcpServers": {
    "codex-bridge": {
      "command": "node",
      "args": ["/absolute/path/to/codex-mcp-bridge/dist/index.js"],
      "env": {
        "CODEX_MCP_REPO": "/absolute/path/to/desktop-shell-repo",
        "CODEX_MCP_TIMEOUT_MS": "600000"
      }
    }
  }
}
```

Cloud-hosted environments differ. If your Claude cloud environment does not support project `.mcp.json` or launching stdio MCP processes, this server cannot override that restriction. Use the environment's supported MCP registration method, or host a properly authenticated Streamable HTTP MCP server on a reachable machine. Never expose an unauthenticated MCP endpoint publicly.

## Authentication and account supervision
This bridge does not log in or store credentials. It invokes the Codex CLI using its already configured authentication. The account owner should perform authentication and supervise/authorize usage. Do not copy cookies, OAuth tokens, `auth.json`, or API keys into Git, prompts, or logs. This bridge does not bypass plan limits or account terms.

OpenAI documents Codex CLI authentication and non-interactive execution here:
- https://learn.chatgpt.com/docs/cli/reference
- https://learn.chatgpt.com/docs/non-interactive-mode

## Safety / limitations
- Scoped to one configured Git repository.
- Invokes Codex without a shell, using the `workspace-write` sandbox.
- Review-only behavior is prompt-enforced, not a hard security boundary.
- Does not create isolated worktrees; serialize jobs or use a dedicated branch/worktree before concurrent agent edits.
- This is a starter, not a hardened multi-user service.
- Check `codex exec --help` against the installed CLI version before use. Run on a disposable branch first and inspect diffs before merging.
