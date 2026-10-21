// Minimal test harness that runs unchanged in Node.js and in Qt's V4 engine.
//
// Node's `node:test`/`assert` are not available inside Qt, and Qt's
// TestCase is not available in Node, so tests use this shared harness and
// the same suites run in both engines (tests/js/run-node.mjs and
// tests/js/run-qt.qml). Promise-returning tests are awaited by chaining.

export class AssertionError extends Error {
  constructor(message) {
    super(message);
    this.name = "AssertionError";
  }
}

function show(v) {
  try {
    return JSON.stringify(v);
  } catch (e) {
    return String(v);
  }
}

function deepEqual(a, b) {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (a === null || b === null || typeof a !== "object") return Number.isNaN(a) && Number.isNaN(b);
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  for (let i = 0; i < ka.length; i++) {
    if (!Object.prototype.hasOwnProperty.call(b, ka[i])) return false;
    if (!deepEqual(a[ka[i]], b[ka[i]])) return false;
  }
  return true;
}

export const assert = {
  ok(v, msg) {
    if (!v) throw new AssertionError(msg || "expected truthy, got " + show(v));
  },
  equal(a, b, msg) {
    if (a !== b) throw new AssertionError((msg ? msg + ": " : "") + "expected " + show(b) + ", got " + show(a));
  },
  deepEqual(a, b, msg) {
    if (!deepEqual(a, b)) throw new AssertionError((msg ? msg + ": " : "") + "expected " + show(b) + ", got " + show(a));
  },
  approx(a, b, eps, msg) {
    if (typeof a !== "number" || Math.abs(a - b) > (eps === undefined ? 1e-9 : eps))
      throw new AssertionError((msg ? msg + ": " : "") + "expected ≈" + b + ", got " + show(a));
  },
  throws(fn, pattern, msg) {
    let threw = false;
    try {
      fn();
    } catch (e) {
      threw = true;
      if (pattern && !pattern.test(String(e && e.message ? e.message : e)))
        throw new AssertionError((msg ? msg + ": " : "") + "error " + show(String(e)) + " does not match " + pattern);
    }
    if (!threw) throw new AssertionError(msg || "expected an exception");
  },
  match(s, re, msg) {
    if (!re.test(String(s))) throw new AssertionError((msg ? msg + ": " : "") + show(s) + " does not match " + re);
  },
};

export function suite(name, define) {
  const tests = [];
  define((title, fn) => tests.push({ title: title, fn: fn }));
  return { name: name, tests: tests };
}

// Run suites sequentially. log(line) receives TAP-like output.
// Resolves with { passed, failed, failures }.
export function runAll(suites, log) {
  const summary = { passed: 0, failed: 0, failures: [] };
  const queue = [];
  for (let i = 0; i < suites.length; i++)
    for (let k = 0; k < suites[i].tests.length; k++) queue.push({ suite: suites[i].name, test: suites[i].tests[k] });
  let idx = 0;
  const step = () => {
    if (idx >= queue.length) {
      log("# passed " + summary.passed + ", failed " + summary.failed);
      return Promise.resolve(summary);
    }
    const item = queue[idx++];
    const label = item.suite + " › " + item.test.title;
    let p;
    try {
      p = Promise.resolve(item.test.fn(assert));
    } catch (e) {
      p = Promise.reject(e);
    }
    return p.then(
      () => {
        summary.passed++;
        log("ok " + idx + " " + label);
        return step();
      },
      (e) => {
        summary.failed++;
        const msg = e && e.message ? e.message : String(e);
        summary.failures.push(label + ": " + msg);
        log("not ok " + idx + " " + label + "\n  # " + msg);
        return step();
      },
    );
  };
  return step();
}

// A deterministic scheduler for code that takes {setTimeout, clearTimeout}.
export function manualScheduler() {
  let now = 0;
  let seq = 0;
  const timers = [];
  return {
    setTimeout(fn, ms) {
      const id = ++seq;
      timers.push({ id: id, at: now + ms, fn: fn });
      return id;
    },
    clearTimeout(id) {
      for (let i = 0; i < timers.length; i++) if (timers[i].id === id) timers.splice(i, 1);
    },
    advance(ms) {
      now += ms;
      timers.sort((a, b) => a.at - b.at);
      while (timers.length && timers[0].at <= now) timers.shift().fn();
    },
    pending() {
      return timers.length;
    },
  };
}
