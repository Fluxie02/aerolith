// First-run tour policy. Pure, V4-compatible logic shared with Node tests.
export const VERSION = 1;
export const STEPS = ["hatch", "ring", "search", "apps", "strip"];

export function readRecord(record) {
  const r = record && typeof record === "object" ? record : {};
  return {
    completed: r.completed === true,
    version: Number.isInteger(r.version) && r.version > 0 ? r.version : 0,
  };
}

export function isCompleted(record) {
  const r = readRecord(record);
  return r.completed && r.version === VERSION;
}

// Manual replay ignores completion, but shares all presentation safety gates.
export function mayShowNow(context) {
  return !!(context.ready && context.enabled && context.output
    && !context.locked && !context.fullscreen);
}

export function shouldAutoStart(context) {
  return mayShowNow(context) && !context.completed && !context.started;
}

export function transition(state, action) {
  const next = { active: !!state.active, step: state.step, completed: !!state.completed };
  if (action === "start") {
    next.active = true;
    next.step = 0;
  } else if (action === "skip" || action === "finish"
      || (action === "next" && next.active && next.step === STEPS.length - 1)) {
    next.active = false;
    next.completed = true;
  } else if (action === "next" && next.active) {
    next.step = Math.min(STEPS.length - 1, next.step + 1);
  } else if (action === "back" && next.active) {
    next.step = Math.max(0, next.step - 1);
  }
  return next;
}
