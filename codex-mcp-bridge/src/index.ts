import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";

const ROOT = path.resolve(process.env.CODEX_MCP_REPO ?? process.cwd());
const CODEX = process.env.CODEX_BIN ?? "codex";
const TIMEOUT_MS = Math.max(30_000, Math.min(Number(process.env.CODEX_MCP_TIMEOUT_MS ?? 600_000), 1_200_000));
const STATE_DIR = path.join(os.homedir(), ".codex-mcp-bridge");
const JOBS_FILE = path.join(STATE_DIR, "jobs.json");
type Job = { id: string; kind: string; status: string; startedAt: string; finishedAt?: string; summary: string; account?: string; output?: string };

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

type Role = "design" | "coding";
type Account = { name: string; cap: number; home?: string; role?: Role; model?: string };
type Window = { used: number; resetsAt: number };
type Usage = { windows: Window[]; observedAt: string; limitHitUntil?: number };
// CODEX_ACCOUNTS="mine:100:role=coding:model=gpt-6.1-sol,dad:80:role=design:home=default":
// ChatGPT logins in priority order, each with the highest used_percent of its plan
// limit at which the bridge still starts a job. Options: role (design or coding;
// unset takes both), model (passed to codex -m), home=default (use the normal
// Codex login in ~/.codex instead of ~/.codex-accounts/<name>).
const ACCOUNTS: Account[] = (process.env.CODEX_ACCOUNTS ?? "").split(",").map(x => x.trim()).filter(Boolean).map(x => {
  const [name, cap, ...rest] = x.split(":");
  if (!/^[a-z0-9_-]+$/i.test(name)) throw new Error(`Invalid account name in CODEX_ACCOUNTS: ${name}`);
  const opt = Object.fromEntries(rest.map(o => o === "default" ? ["home", "default"] : o.split("=", 2)));
  if (opt.role && opt.role !== "design" && opt.role !== "coding") throw new Error(`Invalid role for ${name}: ${opt.role}`);
  if (opt.model && !/^[a-z0-9._-]+$/i.test(opt.model)) throw new Error(`Invalid model for ${name}: ${opt.model}`);
  return { name, cap: Math.max(1, Math.min(Number(cap ?? 100) || 100, 100)), role: opt.role, model: opt.model,
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
function usedPercent(name: string): number | undefined {
  const live = (readUsage()[name]?.windows ?? []).filter(w => w.resetsAt > Date.now());
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
  const used = usedPercent(a.name);
  if (used !== undefined && used >= a.cap) return `${used}% used, cap is ${a.cap}%`;
  return undefined;
}
const LIMIT_HIT = /usage limit|rate.?limit|too many requests|\b429\b|quota/i;

async function runCodex(role: Role, kind: string, prompt: string, sandbox: "workspace-write" | "read-only" = "workspace-write"): Promise<Job> {
  if (!existsSync(ROOT) || !existsSync(path.join(ROOT, ".git")))
    throw new Error(`CODEX_MCP_REPO must point to an existing Git repository: ${ROOT}`);
  const job: Job = { id: crypto.randomUUID(), kind, status: "running", startedAt: new Date().toISOString(), summary: prompt.slice(0, 300) };
  saveJob(job);
  const log: string[] = [];
  for (const account of ACCOUNTS.filter(a => !a.role || a.role === role)) {
    const why = await blocked(account);
    if (why) { log.push(`account=${account.name} skipped: ${why}`); continue; }
    job.account = account.name; saveJob(job);
    const r = await new Promise<{code: number | null; stdout: string; stderr: string; timedOut: boolean}>((resolve, reject) => {
      let stdout = "", stderr = "", timedOut = false;
      const args = ["exec", "--ephemeral", "--json", "--sandbox", sandbox, ...(account.model ? ["-m", account.model] : []), "-C", ROOT, prompt];
      const child = spawn(CODEX, args, { cwd: ROOT, env: accountEnv(account), stdio: ["ignore", "pipe", "pipe"] });
      const timer = setTimeout(() => { timedOut = true; child.kill("SIGTERM"); setTimeout(() => child.kill("SIGKILL"), 5000).unref(); }, TIMEOUT_MS);
      child.stdout.setEncoding("utf8"); child.stderr.setEncoding("utf8");
      child.stdout.on("data", (x: string) => stdout += x);
      child.stderr.on("data", (x: string) => stderr += x);
      child.on("error", e => { clearTimeout(timer); reject(new Error(`Could not launch Codex CLI (${CODEX}): ${e.message}`)); });
      child.on("close", code => { clearTimeout(timer); resolve({ code, stdout, stderr, timedOut }); });
    });
    const windows = rateWindows(r.stdout);
    const limitHit = r.code !== 0 && !r.timedOut && LIMIT_HIT.test(r.stderr + r.stdout.slice(-4000));
    // Block until the window that ran out resets: the fullest one, else the soonest.
    const live = windows.filter(w => w.resetsAt > Date.now());
    const full = live.filter(w => w.used >= 95);
    const resetAt = full.length ? Math.max(...full.map(w => w.resetsAt)) : live.length ? Math.min(...live.map(w => w.resetsAt)) : Date.now() + 3600_000;
    saveUsage(account.name, {
      windows: windows.length ? windows : readUsage()[account.name]?.windows ?? [],
      observedAt: new Date().toISOString(),
      limitHitUntil: limitHit ? resetAt : undefined
    });
    log.push(`account=${account.name} used_percent=${usedPercent(account.name) ?? "unknown"} cap=${account.cap}%${limitHit ? " (usage limit hit, trying next account)" : ""}`);
    job.status = r.timedOut ? "timed_out" : (r.code === 0 ? "succeeded" : "failed");
    job.output = `exit_code=${r.code}\ntimed_out=${r.timedOut}\n\nSTDOUT:\n${r.stdout}\n\nSTDERR:\n${r.stderr}`;
    if (!limitHit) break;
  }
  if (job.status === "running") {
    job.status = "no_account";
    job.output = `No Codex account for ${role} work can take this job. Run codex_status for details.`;
  }
  job.finishedAt = new Date().toISOString();
  job.output = clip(`${log.join("\n")}\n${job.output}`);
  saveJob(job);
  return job;
}
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
      const used = usedPercent(acc.name);
      lines.push(`- ${acc.name} (${acc.role ?? "design+coding"}${acc.model ? `, model ${acc.model}` : ""}): cap ${acc.cap}%, used ${used === undefined ? "unknown" : `${used}%`}, ${why ? `blocked (${why})` : "available"}` +
        `${acc.home ? `, CODEX_HOME=${acc.home}` : ""}\n  login: ${login.text}`);
    }
    return { content: [{ type: "text", text: `Repository: ${ROOT}\nCodex binary: ${CODEX}\nAccounts (priority order):\n${lines.join("\n")}\nNext design job goes to: ${next.design ?? "none"}\nNext coding job goes to: ${next.coding ?? "none"}` }] };
  }
);

server.tool("codex_design_task",
  "Delegate a bounded UI design task to Codex in the configured Git repository. Codex may edit repository files.",
  {
    brief: z.string().min(10).max(12000).describe("Design task, constraints, and acceptance criteria."),
    relevant_files: z.array(z.string().max(300)).max(30).optional().describe("Repository-relative files to inspect; Codex must verify paths.")
  },
  async ({ brief, relevant_files }) => {
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
    const job = await runCodex("design", "design", prompt);
    return { content: [{ type: "text", text: resultText(job) }] };
  }
);

server.tool("codex_review_diff",
  "Review the current Git changes for visual quality or engineering risks. Review-only: do not edit files.",
  {
    focus: z.enum(["visual_design", "linux_integration", "general"]).default("general"),
    base_ref: z.string().max(200).optional().describe("Optional Git base ref for review context.")
  },
  async ({ focus, base_ref }) => {
    const prompt = [
      "Review only. DO NOT edit, create, delete, or format files.",
      "Inspect current Git changes and relevant surrounding code. Report only actionable findings.",
      `Focus: ${focus}.`,
      base_ref ? `Compare with base ref ${base_ref}; treat it as a Git ref, not a shell command.` : "Review uncommitted changes and current branch context.",
      "For each finding give severity, file/line if available, evidence, impact, and concrete fix.",
      "If there are no meaningful issues, say so. Also identify missing tests and unverified assumptions."
    ].join("\n");
    // Visual reviews are design work; engineering reviews go to the coding buddy.
    const job = await runCodex(focus === "visual_design" ? "design" : "coding", "review", prompt, "read-only");
    return { content: [{ type: "text", text: resultText(job) }] };
  }
);

server.tool("codex_coding_buddy",
  "Ask the Codex coding buddy for a second opinion on systems code: a design question, a bug hunt, or a proposed implementation. Advise mode is read-only; edit mode may change repository files.",
  {
    request: z.string().min(10).max(12000).describe("Question or coding task, with context and what a good answer looks like."),
    mode: z.enum(["advise", "edit"]).default("advise"),
    relevant_files: z.array(z.string().max(300)).max(30).optional().describe("Repository-relative files to inspect; Codex must verify paths.")
  },
  async ({ request, mode, relevant_files }) => {
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
    const job = await runCodex("coding", "coding", prompt, mode === "edit" ? "workspace-write" : "read-only");
    return { content: [{ type: "text", text: resultText(job) }] };
  }
);

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
  const jobs = readJobs().slice(-limit).reverse().map(({id, kind, status, account, startedAt, finishedAt, summary}) =>
    ({id, kind, status, account, startedAt, finishedAt, summary}));
  return { content: [{ type: "text", text: JSON.stringify(jobs, null, 2) }] };
});

await server.connect(new StdioServerTransport());
