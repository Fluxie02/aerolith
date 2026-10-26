# Codex MCP Bridge

Minimal stdio MCP server that lets an MCP-compatible host call the installed Codex CLI without relying on Claude Code's `/plugin` mechanism.

## Tools
- `codex_status`: per-account login, last known usage, cap, and which account the next job uses.
- `codex_design_task`: bounded UI task; Codex can edit files. Design work.
- `codex_review_diff`: review-only diff inspection (read-only sandbox). `visual_design` reviews are design work; other focuses go to the coding buddy.
- `codex_coding_buddy`: second opinion on systems code; `advise` is read-only, `edit` may change files.
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
- `CODEX_ACCOUNTS` lists ChatGPT accounts in priority order with a usage cap and options, e.g. `mine:100:role=coding:model=gpt-6.1-sol,dad:80:role=design:home=default`. Unset means one account using the default Codex login.

## Multiple accounts
Each `CODEX_ACCOUNTS` entry is `name:cap[:option...]`:
- `cap`: the highest `used_percent` of the account's plan limit at which the bridge still starts a job.
- `role=design` or `role=coding`: which work the account takes. Without it the account takes both.
- `model=<id>`: passed to `codex exec -m` for every job on that account.
- `home=default`: use the normal Codex login (`~/.codex`, or `$CODEX_HOME`) instead of `~/.codex-accounts/<name>`.

A job goes to the first account for its role that is logged in, has not hit its usage limit, and is below its cap. With the repo's setting, design work goes to `dad` up to 80% of its limit (the rest stays with its owner), and coding-buddy work goes to `mine` on `gpt-6.1-sol`. Neither spills over to the other: when the account for a role is unavailable, that job is refused.

Each owner logs in once per container:

```bash
CODEX_HOME=~/.codex-accounts/mine codex login --device-auth   # coding buddy
codex login --device-auth                                     # dad, home=default
```

The session hook also writes `model = "gpt-6.1-sol"` into `~/.codex-accounts/mine/config.toml`, so that account uses it outside the bridge too.

Usage comes from the rate-limit figures Codex prints during `codex exec --json` and is kept in `~/.codex-mcp-bridge/usage.json`. It is only known after an account's first job, and the cap is checked before a job starts, so a long job can end a few percent past it. If a job fails because an account hit its usage limit, the bridge marks that account blocked until the limit resets and runs the job on the next account. Codex used outside the bridge (the Codex plugin, ChatGPT itself) is only seen at the next bridge job.

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
