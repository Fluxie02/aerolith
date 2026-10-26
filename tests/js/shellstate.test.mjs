import { suite, manualScheduler } from "./harness.mjs";
import * as S from "../../shell/lib/shellstate.mjs";

function snapshot(clients, monitor) {
  return {
    output: "DP-1",
    monitors: [Object.assign({ name: "DP-1", activeWorkspaceId: 3, specialWorkspaceId: 0 }, monitor || {})],
    clients: clients,
  };
}

function lifecycle() {
  const scheduler = manualScheduler();
  const seen = [];
  const lc = S.createLifecycle({ scheduler: scheduler, enterDelayMs: 400, restoreMs: 300, onChange: (p, prev) => seen.push(prev + ">" + p) });
  return { lc: lc, scheduler: scheduler, seen: seen };
}

export default suite("shellstate", (test) => {
  test("reads the Hyprland fullscreen bitmask and the pre-0.42 boolean", (assert) => {
    assert.equal(S.fullscreenMode({ fullscreen: 0 }), "none");
    assert.equal(S.fullscreenMode({ fullscreen: 1 }), "maximized");
    assert.equal(S.fullscreenMode({ fullscreen: 2 }), "fullscreen");
    assert.equal(S.fullscreenMode({ fullscreen: 3 }), "fullscreen");
    assert.equal(S.fullscreenMode({ fullscreen: true, fullscreenMode: 0 }), "fullscreen");
    assert.equal(S.fullscreenMode({ fullscreen: true, fullscreenMode: 1 }), "maximized");
    assert.equal(S.fullscreenMode({ fullscreen: false }), "none");
    assert.equal(S.fullscreenMode(null), "none");
  });

  test("ignores the fullscreen state the client asked for", (assert) => {
    assert.equal(S.fullscreenMode({ fullscreen: 0, fullscreenClient: 2 }), "none");
  });

  test("a fullscreen window on the output's active workspace takes the output", (assert) => {
    const r = S.outputFullscreen(snapshot([{ address: "0xa", workspaceId: 3, ipc: { fullscreen: 2, class: "steam_app_1" } }]));
    assert.deepEqual(r, { fullscreen: true, address: "0xa", appClass: "steam_app_1" });
  });

  test("a floating window focused over a fullscreen game leaves the output taken", (assert) => {
    // Hyprland keeps the game fullscreen under a focused floating window.
    const r = S.outputFullscreen(snapshot([
      { address: "0xa", workspaceId: 3, ipc: { fullscreen: 2, focusHistoryID: 1, class: "game" } },
      { address: "0xb", workspaceId: 3, ipc: { fullscreen: 0, floating: true, focusHistoryID: 0 } },
    ]));
    assert.equal(r.fullscreen, true);
    assert.equal(r.address, "0xa");
  });

  test("maximized windows and other workspaces do not count", (assert) => {
    assert.equal(S.outputFullscreen(snapshot([{ address: "0xa", workspaceId: 3, ipc: { fullscreen: 1 } }])).fullscreen, false);
    assert.equal(S.outputFullscreen(snapshot([{ address: "0xa", workspaceId: 4, ipc: { fullscreen: 2 } }])).fullscreen, false);
  });

  test("a shown special workspace or an unmapped window releases the output", (assert) => {
    const fs = [{ address: "0xa", workspaceId: 3, ipc: { fullscreen: 2 } }];
    assert.equal(S.outputFullscreen(snapshot(fs, { specialWorkspaceId: -98 })).fullscreen, false);
    assert.equal(S.outputFullscreen(snapshot([{ address: "0xa", workspaceId: 3, ipc: { fullscreen: 2, mapped: false } }])).fullscreen, false);
  });

  test("a removed or unknown output is never fullscreen", (assert) => {
    const fs = [{ address: "0xa", workspaceId: 3, ipc: { fullscreen: 2 } }];
    const two = snapshot(fs);
    two.monitors.push({ name: "HDMI-A-1", activeWorkspaceId: 3 });
    two.output = "gone";
    assert.equal(S.outputFullscreen(two).fullscreen, false);
    assert.equal(S.outputFullscreen(null).fullscreen, false);
    const one = snapshot(fs);
    one.output = "renamed";
    assert.equal(S.outputFullscreen(one).fullscreen, true, "a single output is used even if names disagree");
  });

  test("suspends after the enter delay and restores immediately", (assert) => {
    const t = lifecycle();
    t.lc.update(true);
    t.scheduler.advance(399);
    assert.equal(t.lc.phase, S.DESKTOP);
    t.scheduler.advance(1);
    assert.equal(t.lc.phase, S.SUSPENDED);
    t.lc.update(false);
    assert.equal(t.lc.phase, S.RESTORING);
    t.scheduler.advance(300);
    assert.equal(t.lc.phase, S.DESKTOP);
    assert.deepEqual(t.seen, ["desktop>suspended", "suspended>restoring", "restoring>desktop"]);
  });

  test("repeated detections do not postpone suspension", (assert) => {
    const t = lifecycle();
    for (let i = 0; i < 5; i++) {
      t.lc.update(true);
      t.scheduler.advance(100);
    }
    assert.equal(t.lc.phase, S.SUSPENDED);
  });

  test("a fullscreen flap shorter than the delay never suspends", (assert) => {
    const t = lifecycle();
    t.lc.update(true);
    t.scheduler.advance(200);
    t.lc.update(false);
    t.scheduler.advance(1000);
    assert.equal(t.lc.phase, S.DESKTOP);
    assert.deepEqual(t.seen, []);
  });

  test("re-entering fullscreen while restoring suspends again", (assert) => {
    const t = lifecycle();
    t.lc.update(true);
    t.scheduler.advance(400);
    t.lc.update(false);
    t.lc.update(true);
    t.scheduler.advance(400);
    assert.equal(t.lc.phase, S.SUSPENDED);
  });

  test("a flap while restoring still finishes restoring", (assert) => {
    const t = lifecycle();
    t.lc.update(true);
    t.scheduler.advance(400);
    t.lc.update(false);
    t.lc.update(true);
    t.scheduler.advance(100);
    t.lc.update(false);
    t.scheduler.advance(300);
    assert.equal(t.lc.phase, S.DESKTOP);
    assert.equal(t.scheduler.pending(), 0);
  });
});
