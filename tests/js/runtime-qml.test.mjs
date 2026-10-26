// Executes production QML JavaScript with fakes. This does not validate QML
// types/signals; tests/scenarios/runtime.sh covers those in Quickshell.
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { suite } from "./harness.mjs";

function source(path) {
  return readFileSync(new URL("../../" + path, import.meta.url), "utf8");
}

// A QML block ends at its opening indentation. Nested JS uses deeper indentation.
function block(text, marker) {
  const start = text.indexOf(marker);
  if (start < 0) throw new Error("missing QML block: " + marker);
  const indent = text.slice(text.lastIndexOf("\n", start) + 1, start).match(/^ */)[0];
  const body = text.slice(text.indexOf("{", start) + 1);
  return body.slice(0, body.indexOf("\n" + indent + "}"));
}

function service(path, context) {
  const text = source(path);
  const sandbox = vm.createContext(context);
  for (const match of text.matchAll(/^    function (\w+)\(([^\n]*)\) \{/gm)) {
    const fn = match[1];
    vm.runInContext("function " + fn + "(" + match[2] + ") {" + block(text, match[0].trimStart()) + "}", sandbox);
    context.root[fn] = sandbox[fn];
  }
  const commands = {};
  context.Registry.register = def => { commands[def.id] = def; };
  context.Registry.registerProvider = () => {};
  vm.runInContext(block(text, "Component.onCompleted: {"), sandbox);
  return commands;
}

function registry() {
  return { ok: message => ({ ok: true, message }), fail: message => ({ ok: false, message }) };
}

export default suite("runtime-qml", test => {
  test("external lock refuses absent lockers and never calls loginctl", async assert => {
    const calls = [];
    const ctx = {
      root: {}, Config: { lock: { enabled: false } }, Registry: registry(),
      Exec: { run: argv => { calls.push(argv); return Promise.resolve({ code: argv[0] === "loginctl" ? 0 : 1, stdout: "", stderr: "no owner" }); } }
    };
    const commands = service("shell/services/Power.qml", ctx);
    const result = await commands["session.lock"].run();
    assert.equal(result.ok, false);
    assert.match(result.message, /no.*locker.*running/i);
    assert.equal(calls.filter(c => c[0] === "loginctl").length, 0);
  });

  test("the built-in lock bypasses the external probe and preserves confirmation", async assert => {
    const ctx = { root: {}, Config: { lock: { enabled: true } }, Registry: registry(),
      Ui: { requestLock: callback => callback(false, "Compositor refused the lock") },
      Exec: { run: () => { throw new Error("unexpected external command"); } } };
    const result = await service("shell/services/Power.qml", ctx)["session.lock"].run();
    assert.equal(result.ok, false);
    assert.equal(result.message, "Compositor refused the lock");
  });

  test("loginctl errors are preserved when an external listener exists", async assert => {
    const ctx = { root: {}, Config: { lock: { enabled: false } }, Registry: registry(),
      Exec: { run: argv => Promise.resolve({ code: argv[0] === "sh" ? 0 : 1, stdout: "", stderr: "no session" }) } };
    const result = await service("shell/services/Power.qml", ctx)["session.lock"].run();
    assert.equal(result.ok, false);
    assert.match(result.message, /loginctl failed/);
  });

  test("external lock supports idle listeners and the ScreenSaver interface", async assert => {
    for (const processPresent of [true, false]) {
      const calls = [];
      const ctx = {
        root: {}, Config: { lock: { enabled: false } }, Registry: registry(),
        Exec: { run: argv => {
          calls.push(argv);
          return Promise.resolve({ code: argv[0] === "sh" && !processPresent ? 1 : 0, stdout: "", stderr: "" });
        } }
      };
      const result = await service("shell/services/Power.qml", ctx)["session.lock"].run();
      assert.equal(result.ok, true);
      assert.ok(calls.some(c => processPresent ? c[0] === "loginctl" : c.includes("org.freedesktop.ScreenSaver")));
    }
  });

  test("Navigator inputs already exclude named and special workspace ids", assert => {
    const compositor = source("shell/services/Compositor.qml");
    const workspaces = vm.runInNewContext("(function() {" + block(compositor, "readonly property var workspaces: {") + "})()", {
      workspaceObjects: [{ id: -98 }, { id: -1337 }, { id: 3, name: "3" }], focusedWorkspaceId: -98
    });
    assert.deepEqual(Array.from(workspaces, w => w.id), [3]);
    const navigator = source("shell/modules/navigator/SpatialNavigator.qml");
    const sectors = vm.runInNewContext("(function() {" + block(navigator, "readonly property var sectors: {") + "})()", {
      allWindows: [{ workspaceId: -98 }, { workspaceId: -1337 }],
      Compositor: { workspaces, focusedWorkspaceId: -98 }, Config: { navigator: { showEmptyWorkspaces: false } }
    });
    assert.deepEqual(Array.from(sectors, s => s.id), [3]);
  });

  test("numbered stepping enters from either end of named/special workspaces", async assert => {
    for (const current of [-98, -1337, 5]) {
      for (const direction of [1, -1]) {
        let target;
        const ctx = { root: { focusedWorkspaceId: current, workspaces: [{ id: 3 }, { id: 7 }] },
          Registry: registry(), hyprAvailable: () => true };
        const commands = service("shell/services/Compositor.qml", ctx);
        ctx.root.focusWorkspace = id => { target = id; return Promise.resolve({ ok: true }); };
        await commands[direction > 0 ? "workspace.next" : "workspace.previous"].run();
        assert.equal(target, current > 0 ? current + direction : direction > 0 ? 3 : 7);
      }
    }
  });

  test("the 101st notification closes the evicted sender and removes its popup", assert => {
    const text = source("shell/services/Notifications.qml");
    let dismissed = 0;
    const root = { items: [], popups: [], doNotDisturb: false,
      showPopup: n => root.popups.push(n), dropPopup: n => { root.popups = root.popups.filter(x => x !== n); } };
    const receive = vm.runInNewContext("(n) => {" + block(text, "onNotification: n => {") + "}",
      { root, NotificationUrgency: { Low: 0 } });
    const notifications = [];
    for (let i = 0; i < 103; i++) {
      let close;
      const n = { id: i, urgency: 1, closed: { connect: callback => { close = callback; } },
        dismiss: () => { dismissed++; close(); } };
      notifications.push(n);
      receive(n);
    }
    assert.equal(root.items.length, 100);
    assert.equal(dismissed, 3);
    assert.equal(root.popups.includes(notifications[0]), false);
    assert.equal(root.items[0].id, 102);
  });

  test("Exec rejects failed starts on runningChanged and bounds streaming output", assert => {
    const text = source("shell/core/Exec.qml");
    let result;
    const ctx = vm.createContext({ running: false, done: false, exitedFlag: false, command: ["missing-program"],
      maxOutput: 16, stdoutText: "", stderrText: "", proc: { finish: r => { result = r; } } });
    vm.runInContext(block(text, "onRunningChanged: {"), ctx);
    assert.equal(result.code, -1);
    assert.match(result.stderr, /could not start.*missing-program/);
    assert.equal(result.timedOut, false);

    // Arbitrary chunks include no newline: a line parser would still grow without bound.
    assert.equal((text.match(/splitMarker: ""/g) || []).length, 2);
    assert.equal(text.includes("StdioCollector"), false);
    const handlers = [...text.matchAll(/onRead: data => ([^\n]+)/g)].map(m => m[1]);
    assert.equal(handlers.length, 2);
    ctx.proc = ctx;
    ctx.data = "abcdefghij";
    for (let i = 0; i < 1000; i++) for (const handler of handlers) vm.runInContext(handler, ctx);
    assert.equal(ctx.stdoutText, "abcdefghijabcdef");
    assert.equal(ctx.stderrText, "abcdefghijabcdef");
  });
});
