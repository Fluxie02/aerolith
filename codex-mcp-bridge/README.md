# Codex MCP Bridge

Minimal stdio MCP server that lets an MCP-compatible host call the installed Codex CLI without relying on Claude Code's `/plugin` mechanism.

## Tools
- `codex_status`: per-account role, model, login, last known usage and cap, and which account the next design and coding job use.
- `codex_design_task`: UI task for Astra (design accounts). Runs in the background in its own worktree.
- `codex_coding_buddy`: Sol (coding accounts). `advise` is read-only and waits by default; `edit` is for big coding tasks and runs in the background in its own worktree.
- `codex_review_diff`: review-only, read-only sandbox, waits by default. `visual_design` reviews are design work; other focuses go to the coding accounts.
- `codex_wait_job`: wait up to 10 minutes for a background job, then return its result or current status.
- `codex_get_job`: retrieve a saved result.
- `codex_recent_jobs`: list recent jobs with their account and branch.

Every job tool takes `wait` (block until done) and `timeout_minutes` (1 to 120).

## Parallel jobs and worktrees
Editing jobs (`codex_design_task`, `codex_coding_buddy` in edit mode) each get a Git worktree in `~/.codex-mcp-bridge/worktrees/` on a new branch `codex/<kind>-<id>` made from the main checkout's `HEAD`, so Claude, Astra and Sol never write the same files on disk. When the job ends, the bridge commits its changes to that branch (author Astra or Sol), drops any worktree change to `.ai_sync_hub.json`, removes the worktree and reports the branch with a diffstat. A job that changed nothing leaves no branch. Read-only jobs run in the main checkout.

- Uncommitted changes in the main checkout are not in a job's worktree; commit first.
- Editing jobs get `--add-dir <main checkout>` so Astra and Sol can write the shared agent-sync hub (`agent_sync.py --repo <main checkout>`). This also lets them write the main checkout, as Astra could before worktrees.
- Editing jobs get network access (`sandbox_workspace_write.network_access=true`), which the Docker-based headless harness and package downloads need.
- A worktree has no `node_modules` or build output; checks that need them must install or build first.
- Each account runs one Codex process at a time; further jobs for it wait in a queue. Different accounts run side by side.
- Jobs are owned by the bridge process. If it exits (session end, `/mcp` reconnect), its unfinished jobs are marked `abandoned` at the next start, with their branch named so the work can be recovered.

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
- `CODEX_MCP_TIMEOUT_MS` defaults to 600000 (10 minutes) and is capped at 7200000 (2 hours).
- `CODEX_ACCOUNTS` lists ChatGPT accounts in priority order with a usage cap and options, e.g. `mine:100:role=coding:model=gpt-6.1-sol:effort=high,dad:80:role=design:effort=high:home=default`. Unset means one account using the default Codex login.

## Multiple accounts
Each `CODEX_ACCOUNTS` entry is `name:cap[:option...]`:
- `cap`: the highest `used_percent` of the account's plan limit (5-hour or weekly, whichever is fuller) at which the bridge still starts a job. A running job is stopped when the account reaches its cap (checked every 30 s, status `stopped_at_cap`); its changes so far are committed to the job branch.
- `role=design` or `role=coding`: which work the account takes. Without it the account takes both.
- `model=<id>`: passed to `codex exec -m` for every job on that account.
- `effort=<level>`: reasoning effort for every job on that account (`-c model_reasoning_effort`); the repo runs both accounts on `high`.
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
- This is a starter, not a hardened multi-user service.
- Check `codex exec --help` against the installed CLI version before use. Run on a disposable branch first and inspect diffs before merging.
