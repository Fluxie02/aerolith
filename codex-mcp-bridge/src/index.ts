import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync, renameSync, rmSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";

const ROOT = path.resolve(process.env.CODEX_MCP_REPO ?? process.cwd());
const CODEX = process.env.CODEX_BIN ?? "codex";
const MAX_TIMEOUT_MS = 2 * 3600_000;
const TIMEOUT_MS = Math.max(30_000, Math.min(Number(process.env.CODEX_MCP_TIMEOUT_MS ?? 600_000), MAX_TIMEOUT_MS));
const STATE_DIR = path.join(os.homedir(), ".codex-mcp-bridge");
const JOBS_FILE = path.join(STATE_DIR, "jobs.json");
const WORKTREES = path.join(STATE_DIR, "worktrees");
type Job = { id: string; kind: string; status: string; startedAt: string; finishedAt?: string; summary: string;
  account?: string; pid?: number; base?: string; branch?: string; output?: string };
const DONE = new Set(["succeeded", "failed", "timed_out", "stopped_at_cap", "no_account", "abandoned"]);

function ensureState() {
  mkdirSync(STATE_DIR, { recursive: true, mode: 0o700 });
  if (!existsSync(JOBS_FILE)) writeFileSync(JOBS_FILE, "[]\n", { mode: 0o600 });
}
function readJobs(): Job[] {
  ensureState();
  try { const x = JSON.parse(readFileSync(JOBS_FILE, "utf8")); return Array.isArray(x) ? x : []; }
  catch { return []; }
}
function writeJobs(jobs: Job[]) {
  ensureState();
  const tmp = `${JOBS_FILE}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(jobs.slice(-100), null, 2) + "\n", { mode: 0o600 });
  renameSync(tmp, JOBS_FILE);
}
function saveJob(job: Job) {
  const jobs = readJobs(); const i = jobs.findIndex(j => j.id === job.id);
  if (i >= 0) jobs[i] = job; else jobs.push(job);
  writeJobs(jobs);
}
function clip(s: string, n = 30000) { return s.length > n ? s.slice(0, n) + "\n...[truncated]" : s; }
function tail(s: string, n: number) { return s.length > n ? "...[earlier output truncated]\n" + s.slice(-n) : s; }
// The agent's answer is its last agent_message in the JSONL stream; it must
// survive clipping, which otherwise keeps only the start of a long run.
function finalMessage(stdout: string) {
  let text = "";
  for (const line of stdout.split("\n")) {
    if (!line.includes('"agent_message"')) continue;
    try {
      const e = JSON.parse(line);
      if (e.type === "item.completed" && e.item?.type === "agent_message") text = e.item.text ?? "";
    } catch { /* not a JSON event */ }
  }
  return text;
}

type Role = "design" | "coding";
type Account = { name: string; cap: number; home?: string; role?: Role; model?: string; effort?: string };
type Window = { used: number; resetsAt: number };
type Usage = { windows: Window[]; observedAt: string; limitHitUntil?: number };
// CODEX_ACCOUNTS="mine:100:role=coding:model=gpt-6.1-sol,dad:80:role=design:home=default":
// ChatGPT logins in priority order, each with the highest used_percent of its plan
// limit at which the bridge still starts a job. Options: role (design or coding;
// unset takes both), model (passed to codex -m), effort (reasoning effort,
// e.g. high), home=default (use the normal
// Codex login in ~/.codex instead of ~/.codex-accounts/<name>).
const ACCOUNTS: Account[] = (process.env.CODEX_ACCOUNTS ?? "").split(",").map(x => x.trim()).filter(Boolean).map(x => {
  const [name, cap, ...rest] = x.split(":");
  if (!/^[a-z0-9_-]+$/i.test(name)) throw new Error(`Invalid account name in CODEX_ACCOUNTS: ${name}`);
  const opt = Object.fromEntries(rest.map(o => o === "default" ? ["home", "default"] : o.split("=", 2)));
  if (opt.role && opt.role !== "design" && opt.role !== "coding") throw new Error(`Invalid role for ${name}: ${opt.role}`);
  if (opt.model && !/^[a-z0-9._-]+$/i.test(opt.model)) throw new Error(`Invalid model for ${name}: ${opt.model}`);
  if (opt.effort && !/^(minimal|low|medium|high|xhigh|max|ultra)$/.test(opt.effort)) throw new Error(`Invalid effort for ${name}: ${opt.effort}`);
  return { name, cap: Math.max(1, Math.min(Number(cap ?? 100) || 100, 100)), role: opt.role, model: opt.model, effort: opt.effort,
    home: opt.home === "default" ? undefined : path.join(os.homedir(), ".codex-accounts", name) };
});
if (!ACCOUNTS.length) ACCOUNTS.push({ name: "default", cap: 100 });
const USAGE_FILE = path.join(STATE_DIR, "usage.json");

function readUsage(): Record<string, Usage> {
  ensureState();
  try { const x = JSON.parse(readFileSync(USAGE_FILE, "utf8")); return x && typeof x === "object" ? x : {}; }
  catch { return {}; }
}
function saveUsage(name: string, u: Usage) {
  const all = readUsage(); all[name] = u;
  const tmp = `${USAGE_FILE}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(all, null, 2) + "\n", { mode: 0o600 });
  renameSync(tmp, USAGE_FILE);
}
// `codex exec --json` does not report rate limits; Codex writes them only to the
// session logs in $CODEX_HOME/sessions/YYYY/MM/DD. Read the newest two of those,
// so the cap also counts work done outside the bridge.
function sessionWindows(a: Account): Window[] {
  let dir = path.join(a.home ?? path.join(os.homedir(), ".codex"), "sessions");
  for (let depth = 0; depth < 3; depth++) {
    const sub = existsSync(dir) ? readdirSync(dir).filter(d => /^\d+$/.test(d)).sort() : [];
    if (!sub.length) return [];
    dir = path.join(dir, sub[sub.length - 1]);
  }
  const files = readdirSync(dir).filter(f => f.endsWith(".jsonl")).map(f => path.join(dir, f))
    .sort((x, y) => statSync(x).mtimeMs - statSync(y).mtimeMs).slice(-2);
  return files.flatMap(f => rateWindows(readFileSync(f, "utf8")));
}
function usedPercent(a: Account): number | undefined {
  const live = [...(readUsage()[a.name]?.windows ?? []), ...sessionWindows(a)].filter(w => w.resetsAt > Date.now());
  return live.length ? Math.max(...live.map(w => w.used)) : undefined;
}
function toWindow(o: Record<string, unknown>): Window {
  const now = Date.now(); const r = o.resets_at;
  const resetsAt = typeof r === "number" ? (r < 1e12 ? r * 1000 : r)
    : typeof r === "string" && !Number.isNaN(Date.parse(r)) ? Date.parse(r)
    : typeof o.resets_in_seconds === "number" ? now + o.resets_in_seconds * 1000
    : typeof o.window_minutes === "number" ? now + o.window_minutes * 60_000
    : now + 5 * 3600_000;
  return { used: Number(o.used_percent), resetsAt };
}
// The rate-limit windows from the last --json event that reported any.
function rateWindows(stdout: string): Window[] {
  let last: Window[] = [];
  for (const line of stdout.split("\n")) {
    if (!line.includes("used_percent")) continue;
    let ev: unknown; try { ev = JSON.parse(line); } catch { continue; }
    const found: Window[] = [];
    const walk = (v: unknown) => {
      if (!v || typeof v !== "object") return;
      const o = v as Record<string, unknown>;
      if (typeof o.used_percent === "number") found.push(toWindow(o));
      Object.values(o).forEach(walk);
    };
    walk(ev);
    if (found.length) last = found;
  }
  return last;
}
function accountEnv(a: Account) { return a.home ? { ...process.env, CODEX_HOME: a.home } : { ...process.env }; }
function loginStatus(a: Account) {
  if (a.home) mkdirSync(a.home, { recursive: true, mode: 0o700 });
  return new Promise<{ ok: boolean; text: string }>(resolve => {
    const p = spawn(CODEX, ["login", "status"], { cwd: ROOT, env: accountEnv(a), stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    p.stdout.setEncoding("utf8"); p.stderr.setEncoding("utf8");
    p.stdout.on("data", (x: string) => out += x);
    p.stderr.on("data", (x: string) => out += x);
    p.on("error", e => resolve({ ok: false, text: `Codex CLI unavailable: ${e.message}` }));
    p.on("close", code => resolve({ ok: code === 0, text: `exit_code=${code}; ${out.trim().slice(0, 500)}` }));
  });
}
// Why an account cannot take a job now, or undefined when it can.
async function blocked(a: Account): Promise<string | undefined> {
  if (!(await loginStatus(a)).ok) return "not logged in";
  const hit = readUsage()[a.name]?.limitHitUntil;
  if (hit && hit > Date.now()) return `usage limit reached until ${new Date(hit).toISOString()}`;
  const used = usedPercent(a);
  if (used !== undefined && used >= a.cap) return `${used}% used, cap is ${a.cap}%`;
  return undefined;
}
const LIMIT_HIT = /usage limit|rate.?limit|too many requests|\b429\b|quota/i;

function git(args: string[], cwd = ROOT) {
  return new Promise<{ code: number | null; out: string }>(resolve => {
    const p = spawn("git", args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    p.stdout.setEncoding("utf8"); p.stderr.setEncoding("utf8");
    p.stdout.on("data", (x: string) => out += x);
    p.stderr.on("data", (x: string) => out += x);
    p.on("error", e => resolve({ code: -1, out: e.message }));
    p.on("close", code => resolve({ code, out: out.trim() }));
  });
}
// One Codex process per account at a time; a second job for the same account
// waits its turn (status "queued"). Different accounts run side by side.
const accountQueue = new Map<string, Promise<void>>();
async function onAccount<T>(name: string, fn: () => Promise<T>): Promise<T> {
  const prev = accountQueue.get(name) ?? Promise.resolve();
  let release!: () => void;
  const turn = new Promise<void>(r => release = r);
  accountQueue.set(name, prev.then(() => turn));
  await prev;
  try { return await fn(); } finally { release(); }
}
const AGENT_NAME: Record<Role, string> = { design: "Astra", coding: "Sol" };

// Editing jobs get their own Git worktree on a new branch from the current
// HEAD, so Claude, Astra and Sol never write the same checkout. The bridge
// commits whatever the job changed to that branch and removes the worktree.
async function openWorktree(job: Job) {
  const base = await git(["rev-parse", "HEAD"]);
  if (base.code !== 0) throw new Error(`git rev-parse HEAD failed: ${base.out}`);
  const dir = path.join(WORKTREES, job.id.slice(0, 8));
  job.base = base.out; job.branch = `codex/${job.kind}-${job.id.slice(0, 8)}`;
  mkdirSync(WORKTREES, { recursive: true, mode: 0o700 });
  const add = await git(["worktree", "add", "-q", "-b", job.branch, dir, job.base]);
  if (add.code !== 0) throw new Error(`git worktree add failed: ${add.out}`);
  return dir;
}
async function closeWorktree(job: Job, dir: string, role: Role) {
  // The shared hub lives in ROOT (agent_sync.py --repo); never ship a worktree copy of it.
  await git(["checkout", "--", ".ai_sync_hub.json"], dir);
  await git(["add", "-A"], dir);
  const staged = await git(["diff", "--cached", "--quiet"], dir);
  let note: string;
  if (staged.code === 0) {
    await git(["worktree", "remove", "--force", dir]);
    await git(["branch", "-D", job.branch!]);
    note = "No files changed; branch removed.";
    job.branch = undefined;
  } else {
    const who = AGENT_NAME[role];
    const c = await git(["-c", `user.name=${who}`, "-c", `user.email=${who.toLowerCase()}@codex.local`,
      "commit", "-q", "--no-verify", "-m", `${job.kind} job ${job.id.slice(0, 8)} by ${who}\n\n${job.summary.slice(0, 200)}`], dir);
    if (c.code !== 0) return `Commit failed; worktree kept at ${dir} on branch ${job.branch}: ${c.out}`;
    const stat = await git(["diff", "--stat", `${job.base}..${job.branch}`]);
    await git(["worktree", "remove", "--force", dir]);
    note = `Changes committed to branch ${job.branch} (base ${job.base!.slice(0, 12)}). Review, then merge it with: git merge ${job.branch}\n${stat.out}`;
  }
  rmSync(dir, { recursive: true, force: true });
  return note;
}

async function runCodex(job: Job, role: Role, prompt: string, sandbox: "workspace-write" | "read-only", timeoutMs: number) {
  const log: string[] = [];
  for (const account of ACCOUNTS.filter(a => !a.role || a.role === role)) {
    const why = await blocked(account);
    if (why) { log.push(`account=${account.name} skipped: ${why}`); continue; }
    job.account = account.name; job.status = "queued"; saveJob(job);
    const next = await onAccount(account.name, async () => {
      // Usage may have moved while this job waited behind another on the same account.
      const late = await blocked(account);
      if (late) { log.push(`account=${account.name} skipped after queueing: ${late}`); return true; }
      job.status = "running"; saveJob(job);
      const edit = sandbox === "workspace-write";
      const dir = edit ? await openWorktree(job) : ROOT;
      saveJob(job);
      const where = edit
        ? `\nYou are working in a separate Git worktree at ${dir} on branch ${job.branch}; edit files only there. ` +
          `Do not commit; the bridge commits your changes. Run agent-sync commands against the shared hub with ` +
          `\`python ${path.join(dir, "tools/agent-sync/agent_sync.py")} --repo ${ROOT} <command> ...\` and do not edit .ai_sync_hub.json directly.\n`
        : "";
      // Astra and Sol both need write access to the shared hub in ROOT for their
      // locks and events, and network access for the Docker-based headless harness.
      const extra = edit ? ["--add-dir", ROOT, "-c", "sandbox_workspace_write.network_access=true"] : [];
      // Not --ephemeral: the session log is the only place Codex reports the
      // account's usage, and capWatch reads it while the job runs.
      const args = ["exec", "--json", "--sandbox", sandbox, ...extra,
        ...(account.model ? ["-m", account.model] : []),
        ...(account.effort ? ["-c", `model_reasoning_effort="${account.effort}"`] : []), "-C", dir, prompt + where];
      const exec = new Promise<{code: number | null; stdout: string; stderr: string; timedOut: boolean; capped: boolean}>((resolve, reject) => {
        let stdout = "", stderr = "", timedOut = false, capped = false;
        const child = spawn(CODEX, args, { cwd: dir, env: accountEnv(account), stdio: ["ignore", "pipe", "pipe"] });
        const stop = () => { child.kill("SIGTERM"); setTimeout(() => child.kill("SIGKILL"), 5000).unref(); };
        const timer = setTimeout(() => { timedOut = true; stop(); }, timeoutMs);
        // The cap is checked before a job starts, but a long job can cross it:
        // stop the job when the account's usage reaches its cap. Its changes so
        // far are still committed to the job branch.
        const capWatch = setInterval(() => {
          const used = usedPercent(account);
          if (used !== undefined && used >= account.cap && !capped) { capped = true; stop(); }
        }, 30_000);
        child.stdout.setEncoding("utf8"); child.stderr.setEncoding("utf8");
        child.stdout.on("data", (x: string) => stdout += x);
        child.stderr.on("data", (x: string) => stderr += x);
        child.on("error", e => { clearTimeout(timer); clearInterval(capWatch); reject(new Error(`Could not launch Codex CLI (${CODEX}): ${e.message}`)); });
        child.on("close", code => { clearTimeout(timer); clearInterval(capWatch); resolve({ code, stdout, stderr, timedOut, capped }); });
      });
      const r = await exec.catch(async e => { if (edit) await closeWorktree(job, dir, role); throw e; });
      const windows = rateWindows(r.stdout);
      const hit = r.code !== 0 && !r.timedOut && !r.capped && LIMIT_HIT.test(r.stderr + r.stdout.slice(-4000));
      // Block until the window that ran out resets: the fullest one, else the soonest.
      const live = windows.filter(w => w.resetsAt > Date.now());
      const full = live.filter(w => w.used >= 95);
      const resetAt = full.length ? Math.max(...full.map(w => w.resetsAt)) : live.length ? Math.min(...live.map(w => w.resetsAt)) : Date.now() + 3600_000;
      saveUsage(account.name, {
        windows: windows.length ? windows : readUsage()[account.name]?.windows ?? [],
        observedAt: new Date().toISOString(),
        limitHitUntil: hit ? resetAt : undefined
      });
      log.push(`account=${account.name}${account.model ? ` model=${account.model}` : ""} used_percent=${usedPercent(account) ?? "unknown"} cap=${account.cap}%${hit ? " (usage limit hit, trying next account)" : ""}`);
      job.status = r.capped ? "stopped_at_cap" : r.timedOut ? "timed_out" : (r.code === 0 ? "succeeded" : "failed");
      if (r.capped) log.push(`account=${account.name} stopped at its ${account.cap}% cap; its changes so far are on the job branch`);
      const changes = edit ? `\nCHANGES:\n${await closeWorktree(job, dir, role)}\n` : "";
      if (hit && edit) log.push(`account=${account.name} changes before the limit: ${changes.trim()}`);
      job.output = `exit_code=${r.code}\ntimed_out=${r.timedOut}\n${changes}\nFINAL MESSAGE:\n${finalMessage(r.stdout)}\n\nSTDOUT:\n${tail(r.stdout, 12000)}\n\nSTDERR:\n${tail(r.stderr, 4000)}`;
      return hit;
    });
    if (!next) break;
  }
  if (!DONE.has(job.status)) {
    job.status = "no_account";
    job.output = `No Codex account for ${role} work can take this job. Run codex_status for details.`;
  }
  job.finishedAt = new Date().toISOString();
  job.output = clip(`${log.join("\n")}\n${job.output}`);
  saveJob(job);
}

// Starts a job and, unless wait is set, returns at once so Claude keeps working;
// codex_wait_job or codex_get_job collects the result.
async function startJob(role: Role, kind: string, prompt: string, sandbox: "workspace-write" | "read-only",
                        opts: { wait: boolean; timeoutMinutes?: number; summary: string }) {
  if (!existsSync(ROOT) || !existsSync(path.join(ROOT, ".git")))
    throw new Error(`CODEX_MCP_REPO must point to an existing Git repository: ${ROOT}`);
  const timeoutMs = opts.timeoutMinutes ? Math.min(opts.timeoutMinutes * 60_000, MAX_TIMEOUT_MS) : TIMEOUT_MS;
  const job: Job = { id: crypto.randomUUID(), kind, status: "starting", startedAt: new Date().toISOString(), summary: opts.summary.slice(0, 300), pid: process.pid };
  saveJob(job);
  const done = runCodex(job, role, prompt, sandbox, timeoutMs).catch(e => {
    job.status = "failed"; job.finishedAt = new Date().toISOString();
    job.output = `${job.output ?? ""}\nBridge error: ${e instanceof Error ? e.message : String(e)}`; saveJob(job);
  });
  if (opts.wait) { await done; return resultText(job); }
  return `Job ${job.id} started in the background (${role}${sandbox === "workspace-write" ? ", own worktree" : ", read-only"}). ` +
    `Keep working; collect it with codex_wait_job or codex_get_job.`;
}
// Jobs left running by a bridge process that has since exited never finish.
function markAbandoned() {
  const alive = (pid?: number) => { if (!pid) return false; try { process.kill(pid, 0); return true; } catch { return false; } };
  const jobs = readJobs(); let changed = false;
  for (const j of jobs) if (!DONE.has(j.status) && j.pid !== process.pid && !alive(j.pid)) {
    j.status = "abandoned"; j.finishedAt = new Date().toISOString(); changed = true;
    j.output = `${j.output ?? ""}\nThe bridge process running this job exited before it finished.` +
      (j.branch ? ` Its worktree may still be in ${WORKTREES} on branch ${j.branch}.` : "");
  }
  if (changed) writeJobs(jobs);
}
markAbandoned();
function resultText(job: Job) { return `Job ${job.id} — ${job.status}\n${job.output ?? ""}`; }

const server = new McpServer({ name: "codex-mcp-bridge", version: "0.1.0" });

server.tool("codex_status",
  "Check each Codex account's login, last known usage and cap, and which account the next job uses. Never returns credentials.",
  {},
  async () => {
    const lines: string[] = [];
    const next: Partial<Record<Role, string>> = {};
    for (const acc of ACCOUNTS) {
      const login = await loginStatus(acc);
      const why = await blocked(acc);
      if (!why) for (const r of ["design", "coding"] as Role[]) if ((!acc.role || acc.role === r) && !next[r]) next[r] = acc.name;
      const used = usedPercent(acc);
      lines.push(`- ${acc.name} (${acc.role ?? "design+coding"}${acc.model ? `, model ${acc.model}` : ""}${acc.effort ? `, effort ${acc.effort}` : ""}): cap ${acc.cap}%, used ${used === undefined ? "unknown" : `${used}%`}, ${why ? `blocked (${why})` : "available"}` +
        `${acc.home ? `, CODEX_HOME=${acc.home}` : ""}\n  login: ${login.text}`);
    }
    return { content: [{ type: "text", text: `Repository: ${ROOT}\nCodex binary: ${CODEX}\nAccounts (priority order):\n${lines.join("\n")}\nNext design job goes to: ${next.design ?? "none"}\nNext coding job goes to: ${next.coding ?? "none"}` }] };
  }
);

const jobOpts = {
  wait: z.boolean().optional().describe("Block until the job finishes instead of running it in the background."),
  timeout_minutes: z.number().int().min(1).max(120).optional().describe("Job time limit; default from CODEX_MCP_TIMEOUT_MS (10 minutes).")
};

server.tool("codex_design_task",
  "Delegate a bounded UI design task to Astra (Codex). Runs in the background in its own Git worktree; its changes come back as a branch to review and merge.",
  {
    brief: z.string().min(10).max(12000).describe("Design task, constraints, and acceptance criteria."),
    relevant_files: z.array(z.string().max(300)).max(30).optional().describe("Repository-relative files to inspect; Codex must verify paths."),
    ...jobOpts
  },
  async ({ brief, relevant_files, wait, timeout_minutes }) => {
    const files = relevant_files?.length ? `\nRelevant paths to verify:\n${relevant_files.map(x => `- ${x}`).join("\n")}\n` : "";
    const prompt = [
      "You are the UI/visual-design specialist in a shared desktop-shell repository.",
      "Stay within the repository. Do not access secrets, change host/system configuration, install global packages, or reboot/shutdown.",
      "Inspect existing code before editing. Focus on hierarchy, layout, spacing, typography, color, target-screen behavior, and purposeful animation.",
      "Do not alter core Linux/Wayland/Hyprland integration or performance-sensitive logic unless explicitly requested; report issues instead.",
      "Make a coherent minimal set of changes and run relevant safe checks.",
      "Finish with files changed, design rationale, checks, risks, and follow-up needs.",
      files, "TASK BRIEF:\n", brief
    ].join("\n");
    return { content: [{ type: "text", text: await startJob("design", "design", prompt, "workspace-write", { wait: wait ?? false, timeoutMinutes: timeout_minutes, summary: brief }) }] };
  }
);

server.tool("codex_review_diff",
  "Review the current Git changes for visual quality or engineering risks. Review-only: do not edit files.",
  {
    focus: z.enum(["visual_design", "linux_integration", "general"]).default("general"),
    base_ref: z.string().max(200).optional().describe("Optional Git base ref for review context."),
    ...jobOpts
  },
  async ({ focus, base_ref, wait, timeout_minutes }) => {
    const prompt = [
      "Review only. DO NOT edit, create, delete, or format files.",
      "Inspect current Git changes and relevant surrounding code. Report only actionable findings.",
      `Focus: ${focus}.`,
      base_ref ? `Compare with base ref ${base_ref}; treat it as a Git ref, not a shell command.` : "Review uncommitted changes and current branch context.",
      "For each finding give severity, file/line if available, evidence, impact, and concrete fix.",
      "If there are no meaningful issues, say so. Also identify missing tests and unverified assumptions."
    ].join("\n");
    // Visual reviews are design work; engineering reviews go to the coding buddy.
    return { content: [{ type: "text", text: await startJob(focus === "visual_design" ? "design" : "coding", "review", prompt, "read-only", { wait: wait ?? true, timeoutMinutes: timeout_minutes, summary: `${focus} review${base_ref ? ` against ${base_ref}` : ""}` }) }] };
  }
);

server.tool("codex_coding_buddy",
  "Sol, the Codex coding buddy (GPT-6.1 Sol). Use advise for a second opinion on systems code (read-only, waits by default). Use edit for big, tedious coding tasks: it runs in the background in its own Git worktree and returns a branch to review and merge.",
  {
    request: z.string().min(10).max(12000).describe("Question or coding task, with context and what a good answer looks like."),
    mode: z.enum(["advise", "edit"]).default("advise"),
    relevant_files: z.array(z.string().max(300)).max(30).optional().describe("Repository-relative files to inspect; Codex must verify paths."),
    ...jobOpts
  },
  async ({ request, mode, relevant_files, wait, timeout_minutes }) => {
    const files = relevant_files?.length ? `\nRelevant paths to verify:\n${relevant_files.map(x => `- ${x}`).join("\n")}\n` : "";
    const prompt = [
      "You are a coding buddy pairing with another engineer on a Hyprland/Wayland desktop-shell repository.",
      "Stay within the repository. Do not access secrets, change host/system configuration, install global packages, or reboot/shutdown.",
      "Read the relevant code before answering. Be concrete: name files, functions and lines, and say what you verified versus assumed.",
      mode === "edit"
        ? "You may edit repository files. Make a minimal, focused change, run relevant safe checks, and finish with files changed, checks run, and risks."
        : "Advise only. DO NOT edit, create, delete, or format files. Give your answer, any code as snippets, and the risks you see.",
      "Do not change visual design (tokens, layout, typography, colour, animation); point it out instead.",
      files, "REQUEST:\n", request
    ].join("\n");
    return { content: [{ type: "text", text: await startJob("coding", "coding", prompt, mode === "edit" ? "workspace-write" : "read-only",
      { wait: wait ?? mode === "advise", timeoutMinutes: timeout_minutes, summary: request }) }] };
  }
);

server.tool("codex_wait_job", "Wait for a background Codex job to finish, up to max_wait_seconds, then return its result or current status.", {
  job_id: z.string().uuid(),
  max_wait_seconds: z.number().int().min(1).max(600).default(300)
}, async ({ job_id, max_wait_seconds }) => {
  const until = Date.now() + max_wait_seconds * 1000;
  for (;;) {
    const job = readJobs().find(j => j.id === job_id);
    if (!job) return { isError: true, content: [{ type: "text", text: `No saved job: ${job_id}` }] };
    if (DONE.has(job.status)) return { content: [{ type: "text", text: resultText(job) }] };
    if (Date.now() >= until) return { content: [{ type: "text", text: `Job ${job_id} is still ${job.status}${job.account ? ` on ${job.account}` : ""}.` }] };
    await new Promise(r => setTimeout(r, 2000));
  }
});

server.tool("codex_get_job", "Retrieve a previous Codex job result by UUID.", {
  job_id: z.string().uuid()
}, async ({ job_id }) => {
  const job = readJobs().find(j => j.id === job_id);
  if (!job) return { isError: true, content: [{ type: "text", text: `No saved job: ${job_id}` }] };
  return { content: [{ type: "text", text: JSON.stringify(job, null, 2) }] };
});

server.tool("codex_recent_jobs", "List recent Codex jobs without their full outputs.", {
  limit: z.number().int().min(1).max(20).default(10)
}, async ({ limit }) => {
  const jobs = readJobs().slice(-limit).reverse().map(({id, kind, status, account, branch, startedAt, finishedAt, summary}) =>
    ({id, kind, status, account, branch, startedAt, finishedAt, summary}));
  return { content: [{ type: "text", text: JSON.stringify(jobs, null, 2) }] };
});

await server.connect(new StdioServerTransport());
