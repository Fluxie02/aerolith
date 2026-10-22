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
type Job = { id: string; kind: string; status: string; startedAt: string; finishedAt?: string; summary: string; output?: string };

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

async function runCodex(kind: "design" | "review", prompt: string): Promise<Job> {
  if (!existsSync(ROOT) || !existsSync(path.join(ROOT, ".git")))
    throw new Error(`CODEX_MCP_REPO must point to an existing Git repository: ${ROOT}`);
  const job: Job = { id: crypto.randomUUID(), kind, status: "running", startedAt: new Date().toISOString(), summary: prompt.slice(0, 300) };
  saveJob(job);
  const args = ["exec", "--ephemeral", "--json", "--sandbox", "workspace-write", "-C", ROOT, prompt];
  const r = await new Promise<{code: number | null; stdout: string; stderr: string; timedOut: boolean}>((resolve, reject) => {
    let stdout = "", stderr = "", timedOut = false;
    const child = spawn(CODEX, args, { cwd: ROOT, env: { ...process.env }, stdio: ["ignore", "pipe", "pipe"] });
    const timer = setTimeout(() => { timedOut = true; child.kill("SIGTERM"); setTimeout(() => child.kill("SIGKILL"), 5000).unref(); }, TIMEOUT_MS);
    child.stdout.setEncoding("utf8"); child.stderr.setEncoding("utf8");
    child.stdout.on("data", (x: string) => stdout += x);
    child.stderr.on("data", (x: string) => stderr += x);
    child.on("error", e => { clearTimeout(timer); reject(new Error(`Could not launch Codex CLI (${CODEX}): ${e.message}`)); });
    child.on("close", code => { clearTimeout(timer); resolve({ code, stdout, stderr, timedOut }); });
  });
  job.status = r.timedOut ? "timed_out" : (r.code === 0 ? "succeeded" : "failed");
  job.finishedAt = new Date().toISOString();
  job.output = clip(`exit_code=${r.code}\ntimed_out=${r.timedOut}\n\nSTDOUT:\n${r.stdout}\n\nSTDERR:\n${r.stderr}`);
  saveJob(job);
  return job;
}
function resultText(job: Job) { return `Job ${job.id} — ${job.status}\n${job.output ?? ""}`; }

const server = new McpServer({ name: "codex-mcp-bridge", version: "0.1.0" });

server.tool("codex_status",
  "Check Codex CLI authentication status and configured repository. Never returns credentials.",
  {},
  async () => {
    const auth = await new Promise<string>(resolve => {
      const p = spawn(CODEX, ["login", "status"], { cwd: ROOT, env: { ...process.env }, stdio: ["ignore", "pipe", "pipe"] });
      let out = "";
      p.stdout.setEncoding("utf8"); p.stderr.setEncoding("utf8");
      p.stdout.on("data", (x: string) => out += x);
      p.stderr.on("data", (x: string) => out += x);
      p.on("error", e => resolve(`Codex CLI unavailable: ${e.message}`));
      p.on("close", code => resolve(`exit_code=${code}; ${out.slice(0, 2000)}`));
    });
    return { content: [{ type: "text", text: `Repository: ${ROOT}\nCodex binary: ${CODEX}\nAuth status: ${auth}` }] };
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
    const job = await runCodex("design", prompt);
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
    const job = await runCodex("review", prompt);
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
  const jobs = readJobs().slice(-limit).reverse().map(({id, kind, status, startedAt, finishedAt, summary}) =>
    ({id, kind, status, startedAt, finishedAt, summary}));
  return { content: [{ type: "text", text: JSON.stringify(jobs, null, 2) }] };
});

await server.connect(new StdioServerTransport());
