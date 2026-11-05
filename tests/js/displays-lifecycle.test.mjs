import { suite, manualScheduler } from "./harness.mjs";
import * as S from "../../shell/lib/shellstate.mjs";
export default suite("output lifecycles", test => {
  function fixture() {
    const scheduler = manualScheduler();
    const views = [];
    const controller = S.createOutputLifecycles({ scheduler: scheduler, onChange: s => views.push(s) });
    const outputs = [{ name: "DP-1" }, { name: "DP-2" }];
    const snapshot = { monitors: [{ name: "DP-1", activeWorkspaceId: 1 }, { name: "DP-2", activeWorkspaceId: 2 }],
      clients: [{ workspaceId: 2, ipc: { fullscreen: 2, class: "game" } }] };
    return { scheduler: scheduler, views: views, c: controller, outputs: outputs, snapshot: snapshot };
  }
  test("fullscreen releases only its output; hold precedes release", a => {
    const t = fixture();
    t.c.update(t.outputs, t.snapshot);
    t.scheduler.advance(400);
    const s = t.c.states();
    a.equal(s["DP-1"].phase, S.DESKTOP);
    a.equal(s["DP-1"].released, false);
    a.equal(s["DP-2"].released, true);
    a.equal(s["DP-2"].ownerClass, "game");
    a.ok(t.views.some(v => v["DP-2"].ambientHeld && !v["DP-2"].released));
    t.snapshot.clients = [];
    t.c.update(t.outputs, t.snapshot);
    a.equal(t.c.states()["DP-2"].phase, S.RESTORING);
    a.equal(t.c.states()["DP-2"].released, false);
    a.equal(t.c.states()["DP-2"].ambientHeld, true);
    t.scheduler.advance(300);
    a.equal(t.c.states()["DP-2"].ambientHeld, false);
  });
  test("unplug cancels pending timers; replug never inherits suspension", a => {
    const t = fixture();
    t.c.update(t.outputs, t.snapshot);
    a.equal(t.scheduler.pending(), 1);
    t.c.update([t.outputs[0]], t.snapshot);
    a.equal(t.scheduler.pending(), 0);
    a.equal(t.c.states()["DP-2"], undefined);
    t.snapshot.clients = [];
    t.c.update(t.outputs, t.snapshot);
    t.scheduler.advance(1000);
    a.equal(t.c.states()["DP-2"].released, false);
    t.c.dispose();
    a.equal(t.scheduler.pending(), 0);
  });
  test("a removed output cannot run an entry callback and unavailable IPC restores", a => {
    const t = fixture();
    t.c.update(t.outputs, t.snapshot);
    t.scheduler.advance(400);
    t.c.update(t.outputs, null);
    a.equal(t.c.states()["DP-2"].released, false);
    t.c.update([], null);
    a.deepEqual(t.c.states(), {});
    a.equal(t.scheduler.pending(), 0);
  });
  test("single mismatched names use the joined monitor name", a => {
    const t = fixture();
    t.c.update([{name:"HEADLESS-1", monitorName:"DP-2"}], t.snapshot);
    t.scheduler.advance(400);
    a.equal(t.c.states()["HEADLESS-1"].released, true);
  });
  test("hotplug with a missing monitor snapshot cannot borrow another output's fullscreen", a => {
    const t = fixture();
    // Qt has announced the replugged output, but an older IPC response has
    // left only the primary monitor in Quickshell's model.
    t.snapshot.monitors = [{ name: "DP-1", activeWorkspaceId: 1 }];
    t.snapshot.clients = [{ workspaceId: 1, ipc: { fullscreen: 2, class: "primary-game" } }];
    t.c.update(t.outputs, t.snapshot);
    t.scheduler.advance(1000);
    a.equal(t.c.states()["DP-1"].released, true);
    a.equal(t.c.states()["DP-2"].released, false);
    a.equal(t.c.states()["DP-2"].fullscreen, false);
    // Once metadata catches up, the secondary still owns workspace 5.
    t.snapshot.monitors.push({ name: "DP-2", activeWorkspaceId: 5 });
    t.c.update(t.outputs, t.snapshot);
    t.scheduler.advance(1000);
    a.equal(t.c.states()["DP-2"].released, false);
    t.c.dispose();
    a.equal(t.scheduler.pending(), 0);
  });
  test("the name fallback remains available for one Qt output and one IPC monitor", a => {
    const t = fixture();
    t.c.update([{ name: "HEADLESS-1" }], {
      monitors: [{ name: "DP-1", activeWorkspaceId: 1 }],
      clients: [{ workspaceId: 1, ipc: { fullscreen: 2 } }]
    });
    t.scheduler.advance(1000);
    a.equal(t.c.states()["HEADLESS-1"].released, true);
    t.c.dispose();
  });
});
