// The AEROLITH command registry: one action model for the whole shell.
//
// Everything the user can do (launch an app, focus a window, set the volume,
// run a routine, ask an AI provider) is a *command* with typed parameters.
// Dynamic things the user can pick (apps, windows, audio devices) come from
// *providers*, and each provided item points at a command plus arguments.
// The Command Core, the routine engine, IPC and AI proposals all execute
// through execute() below, so validation, availability checks, confirmation
// of sensitive actions and history behave identically everywhere.
//
// Search, validation, execution and presentation are separate: search()
// returns plain data, execute() returns a Promise of a structured result, and
// the QML layer only renders.
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

import { matchFields, tokenize } from "./fuzzy.mjs";
import { checkSpec, validateArgs, positionalArgs, formatErrors } from "./params.mjs";

export const CATEGORIES = [
  "apps",
  "windows",
  "workspaces",
  "audio",
  "media",
  "system",
  "routines",
  "settings",
  "shell",
  "ai",
];

// Typed prefixes that narrow the search scope.
export const SCOPE_PREFIXES = {
  ">": "command",
  "@": "window",
  "!": "routine",
  "?": "ai",
};

const ID = /^[a-z][a-z0-9-]*(\.[a-z0-9][a-z0-9-]*)*$/;
const ALIAS = /^[a-z][a-z0-9-]{0,15}$/;

export function result(ok, message, extra) {
  const r = { ok: ok === true, message: String(message === undefined ? "" : message) };
  if (extra) {
    if (extra.detail !== undefined) r.detail = String(extra.detail);
    if (extra.data !== undefined) r.data = extra.data;
    if (extra.undo !== undefined) r.undo = extra.undo;
    if (extra.needsConfirmation) r.needsConfirmation = true;
  }
  return r;
}

export function ok(message, extra) {
  return result(true, message, extra);
}

export function fail(message, extra) {
  return result(false, message, extra);
}

function normalizeResult(cmd, r) {
  if (r === undefined || r === null) return ok(cmd.title + ": done");
  if (typeof r !== "object" || typeof r.ok !== "boolean") return fail(cmd.title + ": command returned an invalid result");
  return result(r.ok, r.message === undefined ? cmd.title : r.message, r);
}

export function checkCommand(def) {
  const problems = [];
  if (!def || typeof def !== "object") return ["command must be an object"];
  if (typeof def.id !== "string" || !ID.test(def.id)) problems.push("invalid command id " + JSON.stringify(def.id));
  if (typeof def.title !== "string" || def.title.length === 0) problems.push("command " + def.id + " needs a title");
  if (CATEGORIES.indexOf(def.category) === -1) problems.push("command " + def.id + " has unknown category " + JSON.stringify(def.category));
  if (typeof def.run !== "function") problems.push("command " + def.id + " needs a run function");
  if (def.alias !== undefined && (typeof def.alias !== "string" || !ALIAS.test(def.alias)))
    problems.push("command " + def.id + " has invalid alias " + JSON.stringify(def.alias));
  const params = def.params || [];
  if (!Array.isArray(params)) problems.push("command " + def.id + " params must be a list");
  else for (let i = 0; i < params.length; i++) problems.push.apply(problems, checkSpec(params[i]));
  return problems;
}

// Returns true, or a string explaining why the command cannot run now.
function availability(cmd, ctx) {
  if (typeof cmd.available !== "function") return true;
  try {
    const a = cmd.available(ctx);
    if (a === true || a === undefined) return true;
    return typeof a === "string" && a.length > 0 ? a : "Unavailable";
  } catch (e) {
    return "Availability check failed: " + e;
  }
}

export function createRegistry(options) {
  const opts = options || {};
  const historyLimit = opts.historyLimit === undefined ? 100 : opts.historyLimit;
  const scheduler = opts.scheduler || null;
  const defaultTimeoutMs = opts.timeoutMs === undefined ? 15000 : opts.timeoutMs;
  const commands = new Map();
  const providers = new Map();
  const history = [];
  const listeners = [];

  function changed() {
    for (let i = 0; i < listeners.length; i++) {
      try {
        listeners[i]();
      } catch (e) {
        // A broken listener must not break registration.
      }
    }
  }

  function register(def, source) {
    const problems = checkCommand(def);
    if (problems.length > 0) throw new Error("invalid command: " + problems.join("; "));
    if (commands.has(def.id)) throw new Error("duplicate command id " + def.id);
    if (def.alias !== undefined) {
      for (const c of commands.values()) if (c.alias === def.alias) throw new Error("duplicate alias " + def.alias);
    }
    const cmd = Object.assign({}, def, { source: source || def.source || "core", params: def.params || [] });
    commands.set(cmd.id, cmd);
    changed();
    return function unregister() {
      if (commands.get(cmd.id) === cmd) {
        commands.delete(cmd.id);
        changed();
      }
    };
  }

  function registerProvider(def, source) {
    if (!def || typeof def.id !== "string" || !ID.test(def.id) || typeof def.items !== "function")
      throw new Error("invalid provider " + (def && def.id));
    if (providers.has(def.id)) throw new Error("duplicate provider id " + def.id);
    const p = Object.assign({}, def, { source: source || def.source || "core" });
    providers.set(p.id, p);
    changed();
    return function unregister() {
      if (providers.get(p.id) === p) {
        providers.delete(p.id);
        changed();
      }
    };
  }

  // Remove every command and provider registered by a source (e.g. "ai").
  function unregisterSource(source) {
    let n = 0;
    for (const [id, c] of Array.from(commands.entries())) if (c.source === source) {
      commands.delete(id);
      n++;
    }
    for (const [id, p] of Array.from(providers.entries())) if (p.source === source) {
      providers.delete(id);
      n++;
    }
    if (n > 0) changed();
    return n;
  }

  function get(id) {
    return commands.get(id) || null;
  }

  function list(filter) {
    const out = [];
    for (const c of commands.values()) if (!filter || filter(c)) out.push(c);
    out.sort((a, b) => (a.category === b.category ? a.title.localeCompare(b.title) : a.category.localeCompare(b.category)));
    return out;
  }

  function findAlias(word) {
    const w = String(word).toLowerCase();
    for (const c of commands.values()) if (c.alias === w) return c;
    return null;
  }

  function commandItem(cmd, ctx) {
    const avail = availability(cmd, ctx);
    return {
      key: "cmd:" + cmd.id,
      kind: cmd.kind || "command",
      title: cmd.title,
      subtitle: cmd.description || "",
      category: cmd.category,
      icon: cmd.icon || "",
      keywords: cmd.keywords || [],
      commandId: cmd.id,
      args: {},
      available: avail === true,
      reason: avail === true ? "" : avail,
      sensitive: cmd.sensitive === true,
      shortcut: cmd.shortcut || "",
      alias: cmd.alias || "",
      needsArgs: (cmd.params || []).some((p) => p.required && p.default === undefined),
      featured: cmd.featured === true,
      boost: 0,
    };
  }

  function providerItems(ctx, query) {
    const out = [];
    for (const p of providers.values()) {
      let items;
      try {
        items = p.items(ctx, query) || [];
      } catch (e) {
        items = [];
      }
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        const cmd = commands.get(it.commandId);
        if (!cmd) continue;
        const avail = availability(cmd, ctx);
        out.push({
          key: p.id + ":" + (it.id === undefined ? i : it.id),
          kind: it.kind || p.kind || "item",
          title: String(it.title || ""),
          subtitle: String(it.subtitle || ""),
          category: it.category || cmd.category,
          icon: it.icon || "",
          keywords: it.keywords || [],
          commandId: it.commandId,
          args: it.args || {},
          available: avail === true && it.available !== false,
          reason: avail !== true ? avail : it.reason || "",
          sensitive: cmd.sensitive === true,
          shortcut: "",
          alias: "",
          needsArgs: false,
          featured: it.featured === true,
          boost: typeof it.boost === "number" ? it.boost : 0,
          badge: it.badge || "",
        });
      }
    }
    return out;
  }

  // Parse leading scope prefix: "> vol" -> { scope: "command", text: "vol" }.
  function parseScope(query) {
    const q = String(query || "");
    const first = q.charAt(0);
    if (SCOPE_PREFIXES[first] !== undefined) return { scope: SCOPE_PREFIXES[first], text: q.slice(1).trim() };
    return { scope: null, text: q.trim() };
  }

  // search(query, ctx, { limit, scope, usage })
  //   usage(key) -> number: optional frecency boost for an item key.
  function search(query, ctx, searchOpts) {
    const so = searchOpts || {};
    const limit = so.limit === undefined ? 50 : so.limit;
    const parsed = parseScope(query);
    const scope = so.scope || parsed.scope;
    const text = parsed.text;
    const usage = typeof so.usage === "function" ? so.usage : () => 0;

    const results = [];

    // Alias invocation: "vol 40" runs audio.volume.set with level=40.
    const words = tokenize(text);
    if (words.length > 0 && (scope === null || scope === "command")) {
      const aliased = findAlias(words[0]);
      if (aliased && words.length > 1) {
        const pos = positionalArgs(aliased.params, words.slice(1));
        const v = validateArgs(aliased.params, pos.args, ctx);
        const extraErr = pos.extra.length > 0 ? [{ param: "input", message: "has extra words: " + pos.extra.join(" ") }] : [];
        const item = commandItem(aliased, ctx);
        item.key = "invoke:" + aliased.id + ":" + JSON.stringify(v.values);
        item.kind = "invocation";
        item.args = v.values;
        item.needsArgs = false;
        item.valid = v.ok && extraErr.length === 0;
        item.validation = formatErrors(v.errors.concat(extraErr));
        item.subtitle = item.valid ? describeInvocation(aliased, v.values) : item.validation;
        item.score = 1e6;
        results.push(item);
      }
    }

    let candidates = [];
    for (const c of commands.values()) {
      if (c.hidden === true) continue;
      candidates.push(commandItem(c, ctx));
    }
    candidates = candidates.concat(providerItems(ctx, text));
    if (scope) candidates = candidates.filter((it) => it.kind === scope || it.category === scope);

    if (text.length === 0) {
      for (let i = 0; i < candidates.length; i++) {
        const it = candidates[i];
        const u = usage(it.key);
        if (!it.featured && u <= 0) continue;
        it.score = (it.featured ? 10 : 0) + u + it.boost;
        it.highlights = {};
        results.push(it);
      }
    } else {
      for (let i = 0; i < candidates.length; i++) {
        const it = candidates[i];
        const fields = [
          { text: it.title, weight: 1.0 },
          { text: it.keywords.join(" "), weight: 0.75 },
          { text: it.subtitle, weight: 0.45 },
          { text: it.alias, weight: 0.9 },
          { text: it.category, weight: 0.35 },
        ];
        const m = matchFields(text, fields);
        if (!m) continue;
        it.score = m.score + it.boost + usage(it.key) + (it.available ? 0 : -25);
        it.highlights = { title: m.highlights[0] || [], subtitle: m.highlights[2] || [] };
        results.push(it);
      }
    }

    results.sort((a, b) => (b.score !== a.score ? b.score - a.score : a.title.localeCompare(b.title)));
    return results.slice(0, limit);
  }

  function describeInvocation(cmd, values) {
    const parts = [];
    for (let i = 0; i < cmd.params.length; i++) {
      const p = cmd.params[i];
      if (values[p.name] !== undefined) parts.push(p.name + "=" + values[p.name]);
    }
    return cmd.title + (parts.length ? " · " + parts.join(", ") : "");
  }

  function validate(commandId, args, ctx) {
    const cmd = commands.get(commandId);
    if (!cmd) return { ok: false, values: {}, errors: [{ param: "command", message: "unknown command " + commandId }] };
    return validateArgs(cmd.params, args, ctx);
  }

  function pushHistory(entry) {
    history.unshift(entry);
    while (history.length > historyLimit) history.pop();
  }

  function withTimeout(promise, ms, cmd) {
    if (!scheduler || !ms || ms <= 0) return promise;
    return new Promise((resolve) => {
      let done = false;
      const handle = scheduler.setTimeout(() => {
        if (done) return;
        done = true;
        resolve(fail(cmd.title + ": timed out after " + Math.round(ms / 1000) + " s", { detail: "The action may still complete in the background." }));
      }, ms);
      promise.then((r) => {
        if (done) return;
        done = true;
        scheduler.clearTimeout(handle);
        resolve(r);
      });
    });
  }

  // execute(commandId, args, ctx, { confirmed, origin, timeoutMs, record })
  // Always resolves (never rejects) with a structured result.
  function execute(commandId, args, ctx, execOpts) {
    const eo = execOpts || {};
    const origin = eo.origin || "user";
    const cmd = commands.get(commandId);
    const finish = (r) => {
      if (eo.record !== false && cmd && cmd.record !== false)
        pushHistory({
          at: Date.now(),
          commandId: commandId,
          title: cmd ? cmd.title : commandId,
          args: args || {},
          ok: r.ok,
          message: r.message,
          origin: origin,
        });
      return r;
    };
    if (!cmd) return Promise.resolve(finish(fail("Unknown command: " + commandId)));
    const avail = availability(cmd, ctx);
    if (avail !== true) return Promise.resolve(finish(fail(cmd.title + ": " + avail)));
    const v = validateArgs(cmd.params, args, ctx);
    if (!v.ok) return Promise.resolve(finish(fail(cmd.title + ": " + formatErrors(v.errors))));
    if (cmd.sensitive === true && eo.confirmed !== true)
      return Promise.resolve(fail(cmd.title + " needs confirmation", { needsConfirmation: true }));
    if (origin === "ai" && cmd.aiAllowed === false)
      return Promise.resolve(finish(fail(cmd.title + " cannot be proposed by an AI provider")));
    let p;
    try {
      p = Promise.resolve(cmd.run(v.values, ctx));
    } catch (e) {
      return Promise.resolve(finish(fail(cmd.title + " failed: " + e)));
    }
    const settled = p.then(
      (r) => normalizeResult(cmd, r),
      (e) => fail(cmd.title + " failed: " + (e && e.message ? e.message : e)),
    );
    return withTimeout(settled, eo.timeoutMs === undefined ? cmd.timeoutMs || defaultTimeoutMs : eo.timeoutMs, cmd).then(finish);
  }

  return {
    register: register,
    registerProvider: registerProvider,
    unregisterSource: unregisterSource,
    get: get,
    list: list,
    findAlias: findAlias,
    search: search,
    validate: validate,
    execute: execute,
    parseScope: parseScope,
    history: () => history.slice(),
    clearHistory: () => {
      history.length = 0;
    },
    onChanged: (fn) => listeners.push(fn),
    size: () => commands.size,
  };
}
