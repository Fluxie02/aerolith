# Codex in the Claude Code cloud environment: access report and account decision

_Prepared 22 October 2026 by Claude (Claude Code) for Codex and the repository owner._

**For Codex:** the owner asks you to make the decision in section 5, using the facts
in this report: **upgrade the ChatGPT account to Plus**, or **create an OpenAI API key
and buy prepaid tokens**. Reply with your choice and your reasoning. Prices and
limits change often; where a figure matters, check it against OpenAI's own pricing
page before you rely on it.

---

## 1. Goal

Claude Code and Codex should work on aerolith **in the same cloud environment**, so
they share `.ai_sync_hub.json` (see `tools/agent-sync/`), but each in **its own
isolated workspace**, so they cannot disturb each other.

## 2. What was tested inside the Claude Code cloud container

| Test | Result |
|---|---|
| `npm i -g @openai/codex` | Works: Codex CLI 0.163.0 installed |
| Network to `api.openai.com`, `chatgpt.com`, `auth.openai.com` | Reachable (HTTP 401/405 responses come from OpenAI, not from a proxy block) |
| `codex sandbox -- …` | Works: commands ran; writes outside the allowed area were blocked (`Read-only file system`) |
| `codex doctor` | Everything passes except authentication, which is not set up yet. The Responses WebSocket failed, but Codex falls back to HTTPS |
| `codex remote-control start` | **Not tested:** the session's permission system blocked it because it opens an inbound tunnel into the container |

Conclusion: **Codex can run inside the same cloud container as Claude Code.** The only
missing piece is a login.

## 3. Recommended architecture

**OpenAI's official Claude Code plugin, [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc)**
(released March 2026), runs Codex from inside Claude Code on the same machine and
checkout.

- **Shared environment:** both agents run in one container and use the same
  `.ai_sync_hub.json`, so locks and hand-off events work as designed.
- **Own workspace:** Codex gets its own git worktree on a `codex/...` branch.
  Its sandbox (`workspace-write`) limits writes to that folder.
- **Hand-offs:** Claude delegates with `/codex:rescue --background`. Codex reviews
  Claude's work with `/codex:review` or `/codex:adversarial-review`. This matches the
  "one review, one revision" rule in `AGENTS.md`.
- **Plugin setup:** it can be enabled in the repo's `.claude/settings.json`, so every
  new cloud session has it.

Limits of this setup:

1. **Codex only runs while a Claude Code session is active.** Claude is the lead and
   Codex is a delegated worker; Codex cannot start work here on its own.
2. **The container is ephemeral.** It is thrown away after inactivity, and the Codex
   login is lost with it. How login is restored depends on the account choice below.
3. **The plugin's optional "review gate"** (Codex reviews every Claude reply) can
   "drain usage limits quickly", according to its README. It should stay off unless
   someone is watching.

Rejected alternatives:

- **Codex remote control into this container:** opens an inbound tunnel, the
  container dies when idle anyway, and it is experimental on Linux.
- **Codex Cloud (`codex cloud exec`):** runs in OpenAI's separate cloud, so the shared
  hub is lost.
- **Separate cloud agents syncing through GitHub only:** the owner judged this not
  to work for the project.

## 4. The two account options

### Option P: upgrade to ChatGPT Plus

- **Price:** $20/month. About **€23/month** in the Netherlands including 21% VAT
  (third-party estimate; check the checkout page).
- **Codex CLI:** included.
- **Limits:** a shared five-hour allowance plus possible weekly limits. OpenAI's own
  estimates per five hours:

  | Model | Local messages per 5 h |
  |---|---|
  | GPT-6 Astra | 5–45 |
  | GPT-6.1 Sol | 15–160 |
  | GPT-6 Sol | 15–150 |
  | GPT-6 Luna | 350–3,000 |

  When the limit is reached, extra credits can be bought.
- **Login in the cloud container:** `codex login --device-auth` once per new
  session. The owner enters a short code on their phone, which takes about 30
  seconds. First switch on *Device code authorization* in ChatGPT's security
  settings. Tokens refresh automatically during a session.
- **Extras:** includes ChatGPT Plus itself, the Codex app and Codex Cloud tasks.
- **Cost risk:** none. The cost is fixed; at worst Codex hits its limit and waits for
  the reset.

### Option K: API key with prepaid tokens

- **Price:** pay per token, billed through OpenAI's API account from prepaid credit.
  Current list prices per million tokens (aggregator, 19 Oct 2026):

  | Model | Input | Cached input | Output |
  |---|---|---|---|
  | GPT-6 Astra | $10.00 | $1.00 | $50.00 |
  | GPT-6.1 Sol | $2.00 | $0.10 | $10.00 |
  | GPT-6 Sol | $2.00 | $0.20 | $10.00 |
  | GPT-6 Luna | $0.10 | $0.01 | $0.50 |

- **Codex CLI:** included. OpenAI calls API keys "the recommended default for
  automation".
- **Login in the cloud container:** fully automatic. Store the key as an environment
  secret in the Claude Code environment settings; the setup script runs
  `printenv OPENAI_API_KEY | codex login --with-api-key`. No phone step.
- **Cost risk:** real. Every token is billed, including the context that gets resent
  on each turn. A runaway loop or a big review costs money. **Set a monthly budget
  limit** in the OpenAI dashboard and keep auto-recharge off.
- **Key safety:** the key is a password. Anyone with access to the environment
  settings can use it. It must never be committed or pasted into chat.

### Rough cost per task (Claude's estimate, not an OpenAI figure)

A typical agentic Codex task reads files and makes several turns. Assume about
1 million input tokens (around 85% cached) and 20,000 output tokens:

| Model | Approximate cost per task |
|---|---|
| GPT-6.1 Sol | about **$0.59** (0.15M × $2 + 0.85M × $0.10 + 0.02M × $10) |
| GPT-6 Sol | about **$0.67** |
| GPT-6 Astra | about **$3.35** |
| GPT-6 Luna | about **$0.03** |

Large reviews or long refactors can use five to ten times as much.

### Break-even

At about $0.60–0.70 per Sol-class task, $20 of API credit buys roughly
**30–35 tasks a month**.

- Use **below about 30 tasks a month**: the API key is cheaper.
- Use **above that**: Plus is cheaper, and its cost stays fixed however heavy the
  use.

## 5. Decision for Codex

**The question:** upgrade to **Plus** (Option P), or create an **API key with prepaid
tokens** (Option K)?

Facts to weigh:

1. **Expected use.** Codex is the visual owner ("Astra"): design tokens, layout,
   QML styling, and one design review per Claude integration. During active weeks
   that is likely a few tasks per session over several sessions, which puts monthly
   use near or above the break-even point.
2. **Who pays.** The owner is a student. A fixed, predictable bill matters more than
   squeezing out the last euro.
3. **Automation.** Only Option K works without a human step. Option P needs a
   30-second phone login per new cloud session. The owner is present in every
   session anyway, because Claude sessions are started by hand.
4. **Failure mode.** Plus fails safe: Codex pauses at the limit. An API key fails
   expensive: it keeps spending until the budget cap.

**Claude's recommendation (for reference; the decision is Codex's):**
**Option P, ChatGPT Plus.** Its cost is fixed, it cannot overspend, it covers more than
the break-even amount of work, and it adds ChatGPT, the Codex app and Codex Cloud. The
one-step phone login per session is a small cost because the owner already starts
every session. Choose Option K only if use is expected to stay light (fewer than
about 30 tasks a month) or if fully unattended login is required. In that case,
set a hard monthly budget of about $10–20.

## 6. Next steps once decided

1. **Plus:** upgrade the account, then switch on device code authorization in
   ChatGPT's security settings.
   **API key:** create a key with a monthly budget cap, then add it as the environment
   secret `OPENAI_API_KEY` in the Claude Code environment settings. Never paste it
   into chat.
2. Claude adds `codex-plugin-cc` to `.claude/settings.json`, adds a setup script that
   installs Codex and creates the Codex worktree, and points both agents at one shared
   hub.
3. Claude updates `AGENTS.md` and `CLAUDE.md` to describe delegation through the
   plugin.
4. A first end-to-end test: Claude delegates a small visual task to Codex, Codex
   publishes `design_complete`, and Claude runs the performance audit.

## Sources

- OpenAI Codex pricing and plan limits: https://learn.chatgpt.com/docs/pricing
- OpenAI Codex authentication: https://learn.chatgpt.com/docs/auth
- `openai/codex-plugin-cc` README: https://github.com/openai/codex-plugin-cc/blob/main/README.md
- OpenAI API prices (aggregator, 19 Oct 2026): https://costgoat.com/pricing/openai-api
- Codex usage limits overview: https://standardcompute.com/codex-usage-limits
- ChatGPT Plus price in the Netherlands (third-party): https://www.glbgpt.com/hub/chatgpt-plus-subscription-price-in-netherlands-2026-guide/
- Codex CLI pricing guide: https://codex.danielvaughan.com/2026/04/10/codex-cli-complete-pricing-guide-subscription-tokens-cost-optimization/
- Codex device code auth: https://lucaberton.com/blog/codex-device-code-auth-chatgpt-security-2026/
