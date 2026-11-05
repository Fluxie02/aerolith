// Executes production QML JavaScript with fakes. This does not validate QML
// types/signals; tests/scenarios/runtime.sh covers those in Quickshell.
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { suite } from "./harness.mjs";
import * as Ambient from "../../shell/lib/ambient.mjs";
import * as ConfigLib from "../../shell/lib/config.mjs";
import * as HD from "../../shell/lib/hyprdispatch.mjs";

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

// Exercise Config's real queue callbacks with controlled fresh reads and saves.
// Actual QML type/signal and output lifetime coverage remains in config.sh.
function configHarness() {
  const text = source("shell/core/Config.qml");
  const jobs = [], writes = [], failures = [];
  const ctx = { ConfigLib, raw: {}, preview: null, previewApplying: false, previewError: "",
    saves: [], savePhase: "", writeText: "", diskText: "", loaded: false,
    hasGood: false, fileBroken: false, revision: 0, freshStarted: false, reloadPending: false,
    Log: {info() {}, warn() {}, error() {}}, reloaded() {}, commits: 0,
    committedChanged() { ctx.commits++; }, saveFailed(message) { failures.push(message); },
    Qt: {callLater(fn) { if (!jobs.includes(fn)) jobs.push(fn); }},
    fresh: {reload() {}, setText(text) { writes.push(text); }}, file: {reload() {}} };
  ctx.root = ctx;
  const sandbox = vm.createContext(ctx);
  for (const match of text.matchAll(/^    function (\w+)\(([^\n]*)\) \{/gm))
    vm.runInContext("function " + match[1] + "(" + match[2] + ") {" + block(text, match[0].trimStart()) + "}", sandbox);
  Object.defineProperties(ctx, {
    previewActive: {get: () => ctx.preview !== null},
    previewDirty: {get: () => ctx.preview !== null && ctx.preview.changes.length > 0},
    data: {get: () => ConfigLib.previewData(ctx.raw, ctx.preview)},
    committedData: {get: () => ConfigLib.previewData(ctx.raw, null)},
    projectedData: {get: () => ConfigLib.previewData(ctx.projectedRaw(), ctx.preview)}
  });
  return {ctx, jobs, writes, failures,
    tick() { for (const job of jobs.splice(0)) job(); },
    saved() { vm.runInContext(block(text, "onSaved: {"), sandbox); }
  };
}

export default suite("runtime-qml", test => {
  test("Config draft publishes no commit and survives external reloads until Cancel", a => {
    const {ctx, writes} = configHarness();
    ctx.apply('{"theme":{"scheme":"limb"}}');
    a.equal(ctx.beginPreview(), "");
    const commits = ctx.commits;
    a.equal(ctx.setPreviewValues([{path: "theme.scheme", value: "iris"}]), "");
    a.equal(ctx.data.theme.scheme, "iris");
    a.equal(ctx.raw.theme.scheme, "limb");
    a.equal(ctx.commits, commits);
    a.equal(writes.length, 0);
    a.match(ctx.setValue("strip.edge", "bottom"), /Apply or cancel/);
    ctx.apply('{"theme":{"scheme":"limb","density":"compact"}}');
    a.equal(ctx.data.theme.scheme, "iris");
    a.equal(ctx.data.theme.density, "compact");
    a.match(ctx.setPreviewValues([{path: "notifications.server", value: true}]), /appearance/);
    a.equal(ctx.data.theme.scheme, "iris");
    ctx.cancelPreview();
    a.equal(ctx.data.theme.scheme, "limb");
    a.equal(ctx.data.theme.density, "compact");
    a.equal(writes.length, 0);
  });

  test("Config Apply uses one queue request and one write after fresh rebase", a => {
    const h = configHarness(), c = h.ctx;
    c.apply('{}'); c.beginPreview();
    c.setPreviewValues([{path: "theme.scheme", value: "iris"}, {path: "strip.edge", value: "bottom"}]);
    a.equal(c.applyPreview(), "");
    a.equal(c.saves.length, 1);
    a.equal(h.writes.length, 0);
    h.tick();
    a.equal(c.savePhase, "reading");
    c.readForSave('{"future":42,"theme":{"density":"compact"}}');
    a.equal(c.previewActive, true);
    a.equal(c.raw.future, 42);
    a.equal(c.committedData.theme.scheme, "limb");
    h.tick();
    a.equal(h.writes.length, 1);
    const saved = JSON.parse(h.writes[0]);
    a.equal(saved.future, 42);
    a.deepEqual(saved.theme, {density: "compact", scheme: "iris"});
    a.equal(saved.strip.edge, "bottom");
    h.saved();
    a.equal(c.previewActive, false);
    a.equal(c.previewApplying, false);
    a.equal(c.saves.length, 0);
    a.equal(c.raw.theme.scheme, "iris");
    a.equal(h.failures.length, 0);
  });

  test("Config conflicts and write failure keep a retryable draft without partial commits", a => {
    const h = configHarness(), c = h.ctx;
    c.apply('{"theme":{"scheme":"limb"}}'); c.beginPreview();
    c.setPreviewValues([{path: "theme.scheme", value: "iris"}, {path: "strip.edge", value: "bottom"}]);
    c.applyPreview(); h.tick();
    c.readForSave('{"theme":{"scheme":"corona"},"future":7}');
    a.equal(h.writes.length, 0);
    a.match(c.previewError, /theme.scheme/);
    a.equal(c.previewActive, true);
    a.equal(c.previewApplying, false);
    a.equal(c.data.theme.scheme, "iris");
    a.equal(c.committedData.theme.scheme, "corona");
    a.equal(c.raw.future, 7);
    c.cancelPreview(); c.beginPreview();
    c.setPreviewValues([{path: "theme.scheme", value: "iris"}]);
    c.applyPreview(); h.tick(); c.readForSave(c.diskText); h.tick();
    c.finishSave("Could not write config");
    a.equal(c.previewActive, true);
    a.equal(c.previewApplying, false);
    a.equal(c.raw.theme.scheme, "corona");
    a.match(c.previewError, /Could not write/);
    c.applyPreview(); h.tick(); c.readForSave(c.diskText); h.tick(); h.saved();
    a.equal(c.previewActive, false);
    a.equal(c.raw.theme.scheme, "iris");
  });

  test("Config cancels an Apply before its fresh read or deferred write finishes", a => {
    for (const afterRead of [false, true]) {
      const h = configHarness(), c = h.ctx;
      c.apply('{}'); c.beginPreview();
      c.setPreviewValues([{path: "theme.scheme", value: "iris"}]);
      c.applyPreview(); h.tick();
      if (afterRead) c.readForSave('{}');
      c.cancelPreview();
      if (afterRead) h.tick(); else c.readForSave('{}');
      a.equal(h.writes.length, 0);
      a.equal(c.saves.length, 0);
      a.equal(c.previewApplying, false);
      a.equal(c.data.theme.scheme, "limb");
    }
  });

  test("Config queued projection steps twice while committed consumers stay unchanged", a => {
    const h = configHarness(), c = h.ctx;
    c.apply('{}');
    for (let i = 0; i < 2; i++) {
      const values = ["compact", "standard", "comfortable"];
      const next = values[(values.indexOf(c.projectedData.theme.density) + 1) % values.length];
      a.equal(c.setValues([{path: "theme.density", value: next}]), "");
    }
    a.equal(c.projectedData.theme.density, "compact");
    a.equal(c.data.theme.density, "standard");
    a.equal(c.saves.length, 2);
    h.tick(); c.readForSave('{}'); h.tick(); h.saved();
    h.tick(); c.readForSave(h.writes[0]); h.tick(); h.saved();
    a.equal(c.data.theme.density, "compact");
    a.equal(h.failures.length, 0);
  });

  // Evaluate the actual production bindings; the headless scenario also
  // checks their live QML dependencies and mapped surfaces.
  function binding(path, name, context) {
    const text = source(path);
    const match = text.match(new RegExp("^    (?:readonly )?property \\w+ " + name + ": ([^\\n]*(?:\\n        [^\\n]+)*)", "m"));
    if (!match) throw new Error("missing binding: " + path + ":" + name);
    return vm.runInNewContext(match[1], context);
  }

  test("ambient consumers use their own window on either held output", a => {
    for (const held of ["DP-1", "DP-2"]) for (const output of ["DP-1", "DP-2"]) {
      const Theme = { ambient: held !== "DP-1", ambientSuspended: held === "DP-1",
        ambientFor: name => name !== held, ambientHeldFor: name => name === held,
        travel: true, bootProgress: 1, lowEffects: false, shaderQuality: 1 };
      for (const [name, prop] of [["Counterphase", "driving"], ["Hatch", "motionAllowed"], ["WorkspaceOrbit", "ambient"], ["Material", "available"]]) {
        const path = "shell/components/" + name + ".qml";
        const Window = { window: { visible: true, screen: { name: output } } };
        const outputName = binding(path, "outputName", { Window, Screen: { name: output } });
        const context = { Theme, Window, outputName, profile: { idleDimmed: false }, visible: true, width: 1, height: 1,
          supported: true, exposed: true, instrument: false, Ui: { deckOpen: false } };
        const ambient = name === "Material" ? true : binding(path, "ambient", context);
        a.equal(binding(path, prop, Object.assign(context, { ambient,
          machine: { ambient, deckHere: false }, hatch: { ambient, deckHere: false }, orbit: { ambient } })), output !== held);
      }
    }
    const orbit = source("shell/components/WorkspaceOrbit.qml");
    a.match(orbit, /onAmbientChanged: if \(!ambient\) indexMotion.complete\(\)/);
  });

  test("OLED seat idle holds ambient work even when a transient surface bypasses dimming", a => {
    const Theme = { ambientFor: () => true, ambientHeldFor: () => false,
      travel: true, bootProgress: 1, lowEffects: false, shaderQuality: 1 };
    const context = { Theme, Window: { window: { visible: true } }, outputName: "OLED",
      profile: { idleDimmed: false, idleAnimationHeld: true }, visible: true, width: 1, height: 1,
      supported: true, exposed: true, ambient: true, instrument: true,
      machine: { ambient: true, deckHere: false }, hatch: { ambient: true, deckHere: false } };
    for (const [name, prop] of [["Counterphase", "driving"], ["Hatch", "motionAllowed"], ["WorkspaceOrbit", "ambient"], ["Material", "available"]]) {
      const path = "shell/components/" + name + ".qml";
      a.equal(binding(path, prop, context), false, name + " stops work at idle");
      context.profile.idleAnimationHeld = false;
      a.equal(binding(path, prop, context), true, name + " resumes on input");
      context.profile.idleAnimationHeld = true;
    }
  });

  test("per-output coverage normalises Qt array-like IPC geometry", a => {
    const outputs = [{ name: "DP-1", monitorName: "DP-1", strip: true }, { name: "DP-2", monitorName: "DP-2", strip: true }];
    const monitors = outputs.map((o, i) => ({ name: o.name, x: i * 1920, y: 0,
      width: 1920, height: 1080, scale: 1, activeWorkspace: { id: i + 1 }, lastIpcObject: {} }));
    const windows = [{ workspaceId: 2, at: null, size: null, floating: false,
      toplevel: { lastIpcObject: { at: { 0: 1920, 1: 32, length: 2 }, size: { 0: 1920, 1: 1048, length: 2 } } } }];
    const covered = vm.runInNewContext("(function() {" + block(source("shell/core/Theme.qml"), "readonly property var coveredOutputs: {") + "})()", {
      Displays: { outputs }, Compositor: { available: true, windows: () => windows },
      Hyprland: { monitors: { values: monitors } }, Ambient, HD, stripHeight: 32,
      Config: { strip: { edge: "top" } }, du: n => n
    });
    a.equal(covered["DP-1"], false);
    a.equal(covered["DP-2"], true);
  });

  test("removed fullscreen delegates cannot reload before Variants deletes them", a => {
    const text = source("shell/shell.qml");
    for (const id of ["groundLoader", "stripLoader"]) {
      const component = text.slice(text.indexOf("id: " + id));
      const active = component.match(/^            active: (.*)$/m)[1];
      const removed = { name: "DP-2" };
      const ctx = { modelData: removed, outputScreen: null, ShellState: { releasedFor: () => false } };
      a.equal(vm.runInNewContext(active, ctx), false);
      ctx.outputScreen = { name: "DP-1" };
      a.equal(vm.runInNewContext(active, ctx), true);
      ctx.ShellState.releasedFor = () => true;
      a.equal(vm.runInNewContext(active, ctx), false);
    }
  });

  test("strip demand counts enabled visible outputs and keeps one sampling cadence", a => {
    const outputs = [{ name: "DP-1", strip: true }, { name: "DP-2", strip: true }];
    const released = new Set();
    const committed = { strip: { telemetry: "alert", visible: true }, display: { outputs: {} } };
    const ctx = { Config: { committedData: committed, strip: { telemetry: "off", visible: false } },
      Displays: { outputs }, ShellState: { releasedFor: name => released.has(name), surfacesReleased: false } };
    const demand = () => binding("shell/services/Telemetry.qml", "stripDemand", ctx);
    a.equal(demand(), 2, "draft strip settings must not alter probes");
    released.add("DP-1"); a.equal(demand(), 1);
    released.add("DP-2"); a.equal(demand(), 0);
    released.clear(); outputs[0].strip = false;
    a.equal(demand(), 2, "draft output visibility must not alter probes");
    committed.display.outputs["DP-1"] = { strip: false }; a.equal(demand(), 1);
    committed.display.outputs["DP-2"] = { strip: false }; a.equal(demand(), 0);
    committed.display.outputs["DP-2"].strip = true;
    committed.strip.telemetry = "off"; a.equal(demand(), 0);
    committed.strip.telemetry = "alert"; committed.strip.visible = false; a.equal(demand(), 0);
    committed.strip.visible = true; ctx.Displays.outputs = []; a.equal(demand(), 0);
  });

  test("OLED idle demand and notification server state ignore appearance drafts", a => {
    const committed = {display: {outputs: {}, oled: {idleDimAfter: 300}}, notifications: {server: false}};
    const ctx = {Config: {committedData: committed, notifications: {server: true}},
      Displays: {outputs: [{name: "DP-1", profile: "oled"}]}};
    a.equal(binding("shell/services/Idle.qml", "timeout", ctx), 0);
    a.equal(binding("shell/services/Notifications.qml", "enabled", ctx), false);
    committed.display.outputs["DP-1"] = {profile: "oled"};
    ctx.Displays.outputs[0].profile = "standard";
    a.equal(binding("shell/services/Idle.qml", "timeout", ctx), 300);
    committed.notifications.server = true;
    a.equal(binding("shell/services/Notifications.qml", "enabled", ctx), true);
  });

  test("AppThemes observes committed schemes while a draft is visible", a => {
    const text = source("shell/services/AppThemes.qml");
    let scheduled = 0;
    const ctx = {root: {}, Config: {loaded: true, fileBroken: false,
      theme: {scheme: "limb"}, committedData: {theme: {scheme: "limb"}}},
      ready: false, observed: "", handled: "", pending: "", busy: false,
      ShellState: {surfacesReleased: false}, debounce: {stop() {}, restart() { scheduled++; }} };
    const observe = vm.runInNewContext("(function() {" + block(text, "function observe() {") + "})", ctx);
    observe();
    a.equal(scheduled, 0);
    ctx.Config.theme.scheme = "iris"; observe();
    a.equal(scheduled, 0, "draft must not schedule external refresh");
    ctx.Config.committedData.theme.scheme = "iris"; observe();
    a.equal(scheduled, 1);
    observe(); a.equal(scheduled, 1);
  });

  test("Deck takeover and popup hold follow the notice output including fullscreen Deck", a => {
    const primary = { name: "DP-1" }, secondary = { name: "DP-2" };
    for (const noticeScreen of [primary, secondary, null]) for (const overlayScreen of [primary, secondary]) {
      for (const deckMapped of [false, true]) for (const released of ["DP-1", "DP-2"]) {
        const Ui = { noticeScreen, overlayScreen, deckMapped };
        const ShellState = { releasedFor: name => name === released, surfacesReleased: released === "DP-1" };
        ShellState.noticesInDeck = binding("shell/services/ShellState.qml", "noticesInDeck", { Ui });
        a.equal(ShellState.noticesInDeck, deckMapped && noticeScreen === overlayScreen);
        a.equal(binding("shell/services/Notifications.qml", "held", { Ui, ShellState }),
          !noticeScreen || (noticeScreen.name === released && !ShellState.noticesInDeck));
      }
    }
    const column = source("shell/modules/notices/NoticeColumn.qml");
    const deck = source("shell/modules/deck/DeckView.qml");
    const columnVisible = column.match(/^    visible: (.*)$/m)[1];
    const deckVisible = deck.match(/^        visible: hasContent.*$/m)[0].split("visible: ")[1];
    for (const takeover of [false, true]) {
      const ctx = { hasContent: true, stack: { hasContent: true }, Ui: { noticeScreen: primary, deckMapped: true }, ShellState: { noticesInDeck: takeover } };
      a.equal(vm.runInNewContext(columnVisible, ctx), !takeover);
      a.equal(vm.runInNewContext(deckVisible, ctx), takeover);
      a.equal(binding("shell/modules/deck/DeckView.qml", "noticeReserve", {
        deckNotices: { visible: takeover, hasContent: true, width: 100 }, Theme: { pad: 10 } }), takeover ? 120 : 0);
    }
  });

  test("external lock refuses absent lockers and never calls loginctl", async assert => {
    const calls = [];
    const ctx = {
      root: {}, Config: { lock: { enabled: false }, cancelPreview: () => {} }, Registry: registry(),
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
    const ctx = { root: {}, Config: { lock: { enabled: false }, cancelPreview: () => {} }, Registry: registry(),
      Exec: { run: argv => Promise.resolve({ code: argv[0] === "sh" ? 0 : 1, stdout: "", stderr: "no session" }) } };
    const result = await service("shell/services/Power.qml", ctx)["session.lock"].run();
    assert.equal(result.ok, false);
    assert.match(result.message, /loginctl failed/);
  });

  test("external lock supports idle listeners and the ScreenSaver interface", async assert => {
    for (const processPresent of [true, false]) {
      const calls = [];
      const ctx = {
        root: {}, Config: { lock: { enabled: false }, cancelPreview: () => {} }, Registry: registry(),
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

  test("session actions discard a preview before invoking external commands", async a => {
    for (const id of ["session.lock", "system.suspend", "system.reboot", "system.poweroff", "session.logout"]) {
      let active = true, calls = 0;
      const beforeEffect = () => { a.equal(active, false, id); calls++; };
      const ctx = {root: {}, Registry: registry(),
        Config: {lock: {enabled: false}, cancelPreview() { active = false; }},
        Exec: {run() { beforeEffect(); return Promise.resolve({code: 0, stdout: "", stderr: ""}); }},
        Compositor: {dispatch() { beforeEffect(); return Promise.resolve({ok: true}); }} };
      const result = await service("shell/services/Power.qml", ctx)[id].run();
      a.equal(result.ok, true);
      a.ok(calls > 0);
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
