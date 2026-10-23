// Routine engine: named sequences of typed, validated command invocations.
//
// A routine never contains code. Each step names a registry command that is
// marked `routine: true` plus an arguments object, and is validated with the
// same typed parameter rules as everything else. There is no eval and no
// shell: the optional `shell.exec` command (argv list, no shell) exists only
// when the user opts in via routines.allowCommandSteps, and it is sensitive,
// so every run that contains it asks for confirmation.
//
// File format (routines.json):
//   { "schemaVersion": 1,
//     "routines": [ { "id": "focus", "name": "Focus mode",
//                     "description": "...", "onError": "stop",
//                     "steps": [ { "action": "workspace.focus", "args": { "workspace": 3 } } ] } ] }
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

import { validateArgs, formatErrors } from "./params.mjs";

export const ROUTINES_SCHEMA_VERSION = 1;
export const MAX_STEPS = 50;
export const MAX_ROUTINES = 200;
const ROUTINE_ID = /^[a-z0-9][a-z0-9-]{0,47}$/;

function typeName(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v;
}

// Validate a parsed routines document against the registry.
// Returns { routines: [validated], errors: [{ routine, step, message }] }.
// Invalid routines are dropped from the runnable list but reported.
export function validateRoutines(doc, registry, ctx) {
  const errors = [];
  const out = [];
  if (typeName(doc) !== "object") return { routines: out, errors: [{ routine: null, step: null, message: "routines file must contain an object" }] };
  if (doc.schemaVersion !== undefined && doc.schemaVersion !== ROUTINES_SCHEMA_VERSION)
    errors.push({ routine: null, step: null, message: "unsupported routines schemaVersion " + JSON.stringify(doc.schemaVersion) });
  const list = doc.routines;
  if (list === undefined) return { routines: out, errors: errors };
  if (!Array.isArray(list)) return { routines: out, errors: errors.concat([{ routine: null, step: null, message: "\"routines\" must be a list" }]) };
  if (list.length > MAX_ROUTINES) errors.push({ routine: null, step: null, message: "more than " + MAX_ROUTINES + " routines; extra entries ignored" });
  const seen = {};
  for (let i = 0; i < Math.min(list.length, MAX_ROUTINES); i++) {
    const r = validateRoutine(list[i], registry, ctx);
    const rid = r.routine ? r.routine.id : "#" + (i + 1);
    for (let k = 0; k < r.errors.length; k++) errors.push({ routine: rid, step: r.errors[k].step, message: r.errors[k].message });
    if (!r.routine) continue;
    if (seen[r.routine.id]) {
      errors.push({ routine: rid, step: null, message: "duplicate routine id" });
      continue;
    }
    seen[r.routine.id] = true;
    if (r.errors.length === 0) out.push(r.routine);
  }
  return { routines: out, errors: errors };
}

export function validateRoutine(def, registry, ctx) {
  const errors = [];
  if (typeName(def) !== "object") return { routine: null, errors: [{ step: null, message: "routine must be an object" }] };
  if (typeof def.id !== "string" || !ROUTINE_ID.test(def.id))
    return { routine: null, errors: [{ step: null, message: "routine id must match " + ROUTINE_ID.source + ", got " + JSON.stringify(def.id) }] };
  const name = typeof def.name === "string" && def.name.trim().length > 0 ? def.name.trim().slice(0, 80) : def.id;
  const onError = def.onError === undefined ? "stop" : def.onError;
  if (onError !== "stop" && onError !== "continue") errors.push({ step: null, message: "onError must be \"stop\" or \"continue\"" });
  if (!Array.isArray(def.steps) || def.steps.length === 0) errors.push({ step: null, message: "routine needs at least one step" });
  const steps = [];
  const list = Array.isArray(def.steps) ? def.steps : [];
  if (list.length > MAX_STEPS) errors.push({ step: null, message: "more than " + MAX_STEPS + " steps" });
  for (let i = 0; i < Math.min(list.length, MAX_STEPS); i++) {
    const s = list[i];
    if (typeName(s) !== "object" || typeof s.action !== "string") {
      errors.push({ step: i + 1, message: "step must be an object with an \"action\"" });
      continue;
    }
    const cmd = registry.get(s.action);
    if (!cmd) {
      errors.push({ step: i + 1, message: "unknown action " + JSON.stringify(s.action) });
      continue;
    }
    if (cmd.routine !== true) {
      errors.push({ step: i + 1, message: "action " + s.action + " cannot be used in routines" });
      continue;
    }
    const v = validateArgs(cmd.params, s.args || {}, ctx);
    if (!v.ok) {
      errors.push({ step: i + 1, message: s.action + ": " + formatErrors(v.errors) });
      continue;
    }
    steps.push({ index: i + 1, action: s.action, args: v.values, title: cmd.title, sensitive: cmd.sensitive === true });
  }
  return {
    routine: {
      id: def.id,
      name: name,
      description: typeof def.description === "string" ? def.description.slice(0, 300) : "",
      onError: onError === "continue" ? "continue" : "stop",
      steps: steps,
    },
    errors: errors,
  };
}

// Dry run: what would happen, without doing it. Availability is evaluated
// now, so the preview can warn about steps that would fail.
export function preview(routine, registry, ctx) {
  const lines = [];
  let sensitive = false;
  for (let i = 0; i < routine.steps.length; i++) {
    const s = routine.steps[i];
    const cmd = registry.get(s.action);
    let avail = true;
    if (cmd && typeof cmd.available === "function") {
      try {
        const a = cmd.available(ctx);
        avail = a === true || a === undefined ? true : String(a);
      } catch (e) {
        avail = "availability check failed";
      }
    }
    const desc = cmd && typeof cmd.describe === "function" ? cmd.describe(s.args, ctx) : describeArgs(s.args);
    if (s.sensitive) sensitive = true;
    lines.push({ index: s.index, action: s.action, title: s.title, description: desc, available: avail === true, reason: avail === true ? "" : avail, sensitive: s.sensitive });
  }
  return { routine: routine.id, name: routine.name, steps: lines, needsConfirmation: sensitive, blocked: lines.filter((l) => !l.available).length };
}

function describeArgs(args) {
  const parts = [];
  for (const k in args) parts.push(k + "=" + JSON.stringify(args[k]));
  return parts.join(", ");
}

// Run a routine. Returns { promise, cancel }.
// The promise resolves (never rejects) with
//   { routine, ok, cancelled, steps: [{ index, action, ok, message, skipped }], undo: [...] }.
// onStep(stepResult) is called after each step for live progress display.
// Cancellation takes effect between steps: a step that has started is never
// interrupted half-way, because most desktop actions cannot be.
export function run(routine, registry, ctx, options) {
  const opts = options || {};
  let cancelled = false;
  const report = { routine: routine.id, name: routine.name, ok: true, cancelled: false, steps: [], undo: [] };
  const needsConfirmation = routine.steps.some((s) => s.sensitive);
  if (needsConfirmation && opts.confirmed !== true) {
    report.ok = false;
    report.needsConfirmation = true;
    return { promise: Promise.resolve(report), cancel: () => {} };
  }
  let i = 0;
  const next = () => {
    if (cancelled) {
      report.cancelled = true;
      report.ok = false;
      for (let k = i; k < routine.steps.length; k++)
        report.steps.push({ index: routine.steps[k].index, action: routine.steps[k].action, ok: false, skipped: true, message: "cancelled" });
      return Promise.resolve(report);
    }
    if (i >= routine.steps.length) return Promise.resolve(report);
    const step = routine.steps[i++];
    return registry
      .execute(step.action, step.args, ctx, { confirmed: needsConfirmation && opts.confirmed === true, origin: "routine", record: false })
      .then((r) => {
        const sr = { index: step.index, action: step.action, ok: r.ok, message: r.message, skipped: false };
        report.steps.push(sr);
        if (r.ok && r.undo) report.undo.unshift(r.undo);
        if (typeof opts.onStep === "function") {
          try {
            opts.onStep(sr);
          } catch (e) {
            // Progress display problems must not stop the routine.
          }
        }
        if (!r.ok) {
          report.ok = false;
          if (routine.onError === "stop") {
            for (let k = i; k < routine.steps.length; k++)
              report.steps.push({ index: routine.steps[k].index, action: routine.steps[k].action, ok: false, skipped: true, message: "not run: earlier step failed" });
            return report;
          }
        }
        return next();
      });
  };
  return {
    promise: next(),
    cancel: () => {
      cancelled = true;
    },
  };
}

// Revert a finished run using the undo entries its steps reported, newest
// first. Only steps that declared a genuine inverse are reverted.
export function revert(report, registry, ctx) {
  const undo = report && Array.isArray(report.undo) ? report.undo : [];
  const results = [];
  let chain = Promise.resolve();
  for (let i = 0; i < undo.length; i++) {
    const u = undo[i];
    chain = chain.then(() =>
      registry.execute(u.commandId, u.args, ctx, { origin: "routine-revert", record: false, confirmed: true }).then((r) => {
        results.push({ commandId: u.commandId, ok: r.ok, message: r.message });
      }),
    );
  }
  return chain.then(() => ({ ok: results.every((r) => r.ok), steps: results }));
}

export function emptyDocument() {
  return { schemaVersion: ROUTINES_SCHEMA_VERSION, routines: [] };
}
