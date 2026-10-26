import { suite, manualScheduler } from "./harness.mjs";
import { createRegistry, checkCommand, ok, fail } from "../../shell/lib/registry.mjs";
import { validateArgs, positionalArgs } from "../../shell/lib/params.mjs";

function volumeRegistry(state, options) {
  const reg = createRegistry(options);
  reg.register({
    id: "audio.volume.set",
    title: "Set volume",
    category: "audio",
    alias: "vol",
    keywords: ["volume", "loudness"],
    params: [{ name: "level", type: "int", min: 0, max: 150, required: true }],
    routine: true,
    available: () => (state.audio ? true : "No audio server"),
    run: (args) => {
      const before = state.volume;
      state.volume = args.level;
      return ok("Volume " + args.level + "%", { undo: { commandId: "audio.volume.set", args: { level: before } } });
    },
  });
  reg.register({
    id: "session.logout",
    title: "Log out",
    category: "system",
    sensitive: true,
    run: () => {
      state.loggedOut = true;
      return ok("Logged out");
    },
  });
  return reg;
}

export default suite("registry", (test) => {
  test("rejects malformed command definitions", (assert) => {
    assert.ok(checkCommand({ id: "Bad ID", title: "x", category: "audio", run: () => 0 }).length > 0);
    assert.ok(checkCommand({ id: "a.b", title: "", category: "audio", run: () => 0 }).length > 0);
    assert.ok(checkCommand({ id: "a.b", title: "x", category: "nope", run: () => 0 }).length > 0);
    assert.ok(checkCommand({ id: "a.b", title: "x", category: "audio" }).length > 0, "missing run");
    assert.ok(checkCommand({ id: "a.b", title: "x", category: "audio", run: () => 0, params: [{ name: "x", type: "blob" }] }).length > 0);
    assert.equal(checkCommand({ id: "a.b", title: "x", category: "audio", run: () => 0 }).length, 0);
  });

  test("refuses duplicate ids and aliases", (assert) => {
    const reg = volumeRegistry({ audio: true });
    assert.throws(() => reg.register({ id: "audio.volume.set", title: "x", category: "audio", run: () => 0 }), /duplicate command/);
    assert.throws(() => reg.register({ id: "audio.other", title: "x", category: "audio", alias: "vol", run: () => 0 }), /duplicate alias/);
  });

  test("search finds commands by title and keyword", (assert) => {
    const reg = volumeRegistry({ audio: true });
    assert.equal(reg.search("set vol", {})[0].commandId, "audio.volume.set");
    assert.equal(reg.search("loudness", {})[0].commandId, "audio.volume.set");
    assert.equal(reg.search("zzzz", {}).length, 0);
  });

  test("alias with arguments becomes a validated invocation", (assert) => {
    const reg = volumeRegistry({ audio: true });
    const top = reg.search("vol 40", {})[0];
    assert.equal(top.kind, "invocation");
    assert.equal(top.valid, true);
    assert.deepEqual(top.args, { level: 40 });
    const bad = reg.search("vol 400", {})[0];
    assert.equal(bad.valid, false);
    assert.match(bad.validation, /at most 150/);
  });

  test("unavailable commands are listed with a reason and rank lower", (assert) => {
    const reg = volumeRegistry({ audio: false });
    const r = reg.search("volume", {})[0];
    assert.equal(r.available, false);
    assert.equal(r.reason, "No audio server");
  });

  test("scope prefixes narrow results", (assert) => {
    const reg = volumeRegistry({ audio: true });
    reg.registerProvider({
      id: "windows",
      kind: "window",
      items: () => [{ id: "w1", title: "Volume Control", commandId: "audio.volume.set", args: { level: 10 } }],
    });
    const all = reg.search("volume", {});
    assert.ok(all.some((r) => r.kind === "window") && all.some((r) => r.kind === "command"));
    const windows = reg.search("@volume", {});
    assert.ok(windows.length > 0 && windows.every((r) => r.kind === "window"));
  });

  test("execute validates arguments before running", (assert) => {
    const state = { audio: true, volume: 50 };
    const reg = volumeRegistry(state);
    return reg.execute("audio.volume.set", { level: 999 }, {}).then((r) => {
      assert.equal(r.ok, false);
      assert.match(r.message, /at most 150/);
      assert.equal(state.volume, 50, "run must not be called");
    });
  });

  test("execute refuses unavailable commands without running them", (assert) => {
    const state = { audio: false, volume: 50 };
    const reg = volumeRegistry(state);
    return reg.execute("audio.volume.set", { level: 20 }, {}).then((r) => {
      assert.equal(r.ok, false);
      assert.match(r.message, /No audio server/);
      assert.equal(state.volume, 50);
    });
  });

  test("quiet results keep their flag; ordinary results do not get one", (assert) => {
    assert.equal(ok("Notice shown", { quiet: true }).quiet, true);
    assert.equal(ok("Volume 40%").quiet, undefined);
    assert.equal(fail("No audio server", { detail: "x" }).quiet, undefined);
  });

  test("sensitive commands need explicit confirmation", (assert) => {
    const state = { audio: true };
    const reg = volumeRegistry(state);
    return reg
      .execute("session.logout", {}, {})
      .then((r) => {
        assert.equal(r.ok, false);
        assert.equal(r.needsConfirmation, true);
        assert.equal(state.loggedOut, undefined);
        return reg.execute("session.logout", {}, {}, { confirmed: true });
      })
      .then((r) => {
        assert.equal(r.ok, true);
        assert.equal(state.loggedOut, true);
      });
  });

  test("exceptions and rejections become failed results", (assert) => {
    const reg = createRegistry();
    reg.register({ id: "x.throw", title: "Thrower", category: "shell", run: () => { throw new Error("boom"); } });
    reg.register({ id: "x.reject", title: "Rejecter", category: "shell", run: () => Promise.reject(new Error("nope")) });
    reg.register({ id: "x.garbage", title: "Garbage", category: "shell", run: () => 42 });
    return reg
      .execute("x.throw", {}, {})
      .then((r) => {
        assert.equal(r.ok, false);
        assert.match(r.message, /boom/);
        return reg.execute("x.reject", {}, {});
      })
      .then((r) => {
        assert.equal(r.ok, false);
        assert.match(r.message, /nope/);
        return reg.execute("x.garbage", {}, {});
      })
      .then((r) => {
        assert.equal(r.ok, false, "a non-result return value must not be reported as success");
      });
  });

  test("slow commands time out with an honest message", (assert) => {
    const sched = manualScheduler();
    const reg = createRegistry({ scheduler: sched, timeoutMs: 1000 });
    reg.register({ id: "x.slow", title: "Slow", category: "shell", run: () => new Promise(() => {}) });
    const p = reg.execute("x.slow", {}, {});
    sched.advance(1001);
    return p.then((r) => {
      assert.equal(r.ok, false);
      assert.match(r.message, /timed out/);
    });
  });

  test("history is bounded and newest first", (assert) => {
    const state = { audio: true, volume: 0 };
    const reg = volumeRegistry(state, { historyLimit: 3 });
    let chain = Promise.resolve();
    for (let i = 1; i <= 5; i++) chain = chain.then(() => reg.execute("audio.volume.set", { level: i }, {}));
    return chain.then(() => {
      const h = reg.history();
      assert.equal(h.length, 3);
      assert.deepEqual(h[0].args, { level: 5 });
      assert.deepEqual(h[2].args, { level: 3 });
    });
  });

  test("unregisterSource removes everything a module registered", (assert) => {
    const reg = createRegistry();
    reg.register({ id: "ai.ask", title: "Ask", category: "ai", run: () => ok("") }, "ai");
    reg.registerProvider({ id: "ai-history", items: () => [] }, "ai");
    reg.register({ id: "shell.reload", title: "Reload", category: "shell", run: () => ok("") });
    assert.equal(reg.unregisterSource("ai"), 2);
    assert.equal(reg.get("ai.ask"), null);
    assert.ok(reg.get("shell.reload"));
  });

  test("AI-origin execution respects aiAllowed=false", (assert) => {
    const reg = createRegistry();
    reg.register({ id: "x.secret", title: "Secret", category: "shell", aiAllowed: false, run: () => ok("ran") });
    return reg.execute("x.secret", {}, {}, { origin: "ai" }).then((r) => {
      assert.equal(r.ok, false);
      assert.match(r.message, /cannot be proposed/);
    });
  });

  test("fail() and ok() build structured results", (assert) => {
    assert.deepEqual(fail("x"), { ok: false, message: "x" });
    assert.deepEqual(ok("y", { detail: "d" }), { ok: true, message: "y", detail: "d" });
  });
});

export const paramsSuite = suite("params", (test) => {
  const specs = [
    { name: "level", type: "int", min: 0, max: 100, required: true },
    { name: "mute", type: "bool", default: false },
    { name: "mode", type: "enum", choices: ["fast", "slow"] },
    { name: "label", type: "string", maxLength: 5 },
  ];

  test("coerces typed text input", (assert) => {
    const v = validateArgs(specs, { level: "40%", mute: "on", mode: "FAST" });
    assert.equal(v.ok, true);
    assert.deepEqual(v.values, { level: 40, mute: true, mode: "fast" });
  });

  test("reports every problem at once", (assert) => {
    const v = validateArgs(specs, { level: "loud", mode: "medium", label: "toolong", extra: 1 });
    assert.equal(v.ok, false);
    const params = v.errors.map((e) => e.param).sort();
    assert.deepEqual(params, ["extra", "label", "level", "mode"]);
  });

  test("required parameters must be present", (assert) => {
    const v = validateArgs(specs, {});
    assert.equal(v.ok, false);
    assert.equal(v.errors[0].param, "level");
  });

  test("integers reject fractions and non-finite values", (assert) => {
    assert.equal(validateArgs(specs, { level: 4.5 }).ok, false);
    assert.equal(validateArgs(specs, { level: Infinity }).ok, false);
    assert.equal(validateArgs(specs, { level: "1e3" }).ok, false);
  });

  test("dynamic enum choices are evaluated with context", (assert) => {
    const s = [{ name: "device", type: "enum", choices: (ctx) => ctx.devices }];
    assert.equal(validateArgs(s, { device: "hdmi" }, { devices: ["hdmi", "usb"] }).ok, true);
    assert.equal(validateArgs(s, { device: "bt" }, { devices: ["hdmi", "usb"] }).ok, false);
  });

  test("string lists validate every entry", (assert) => {
    const s = [{ name: "argv", type: "strings", required: true, maxItems: 3 }];
    assert.deepEqual(validateArgs(s, { argv: ["notify-send", "hi there"] }).values, { argv: ["notify-send", "hi there"] });
    assert.deepEqual(validateArgs(s, { argv: "notify-send hi" }).values, { argv: ["notify-send", "hi"] });
    assert.equal(validateArgs(s, { argv: [] }).ok, false);
    assert.equal(validateArgs(s, { argv: ["a", 1] }).ok, false);
    assert.equal(validateArgs(s, { argv: ["a", "b", "c", "d"] }).ok, false);
    assert.deepEqual(validateArgs([{ name: "argv", type: "strings" }], { argv: "a; rm -rf ~" }).values.argv, ["a;", "rm", "-rf", "~"], "typed text becomes literal argv words, never shell syntax");
  });

  test("positional words map onto parameters; trailing string absorbs the rest", (assert) => {
    const s = [{ name: "workspace", type: "int" }, { name: "note", type: "string" }];
    assert.deepEqual(positionalArgs(s, ["3", "write", "report"]), { args: { workspace: "3", note: "write report" }, extra: [] });
    assert.deepEqual(positionalArgs([{ name: "a", type: "int" }], ["1", "2"]), { args: { a: "1" }, extra: ["2"] });
  });
});
