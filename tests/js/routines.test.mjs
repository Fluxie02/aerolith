import { suite } from "./harness.mjs";
import { createRegistry, ok, fail } from "../../shell/lib/registry.mjs";
import { validateRoutines, validateRoutine, preview, run, revert } from "../../shell/lib/routines.mjs";

function desktop() {
  const state = { workspace: 1, volume: 50, launched: [], profile: "balanced", log: [] };
  const reg = createRegistry();
  reg.register({
    id: "workspace.focus",
    title: "Focus workspace",
    category: "workspaces",
    routine: true,
    params: [{ name: "workspace", type: "int", min: 1, max: 20, required: true }],
    run: (a) => {
      const prev = state.workspace;
      state.workspace = a.workspace;
      state.log.push("ws" + a.workspace);
      return ok("Workspace " + a.workspace, { undo: { commandId: "workspace.focus", args: { workspace: prev } } });
    },
  });
  reg.register({
    id: "audio.volume.set",
    title: "Set volume",
    category: "audio",
    routine: true,
    params: [{ name: "level", type: "int", min: 0, max: 150, required: true }],
    run: (a) => {
      const prev = state.volume;
      state.volume = a.level;
      state.log.push("vol" + a.level);
      return ok("Volume", { undo: { commandId: "audio.volume.set", args: { level: prev } } });
    },
  });
  reg.register({
    id: "app.launch",
    title: "Launch",
    category: "apps",
    routine: true,
    params: [{ name: "app", type: "string", required: true }],
    run: (a) => {
      if (a.app === "missing.desktop") return fail("No such application");
      state.launched.push(a.app);
      state.log.push("launch " + a.app);
      return ok("Launched");
    },
  });
  reg.register({
    id: "shell.exec",
    title: "Run program",
    category: "system",
    routine: true,
    sensitive: true,
    params: [{ name: "argv", type: "string", required: true }],
    run: () => {
      state.log.push("exec");
      return ok("ran");
    },
  });
  reg.register({ id: "session.lock", title: "Lock", category: "system", run: () => ok("locked") });
  return { reg: reg, state: state };
}

const FOCUS = {
  id: "focus",
  name: "Focus mode",
  steps: [
    { action: "workspace.focus", args: { workspace: 3 } },
    { action: "app.launch", args: { app: "firefox.desktop" } },
    { action: "audio.volume.set", args: { level: 30 } },
  ],
};

export default suite("routines", (test) => {
  test("valid routines pass and get typed arguments", (assert) => {
    const d = desktop();
    const r = validateRoutines({ schemaVersion: 1, routines: [FOCUS] }, d.reg);
    assert.equal(r.errors.length, 0);
    assert.equal(r.routines[0].steps[0].args.workspace, 3);
  });

  test("unknown actions, bad arguments and non-routine commands are rejected", (assert) => {
    const d = desktop();
    const r = validateRoutine(
      {
        id: "bad",
        steps: [
          { action: "rm.rf", args: {} },
          { action: "workspace.focus", args: { workspace: 99 } },
          { action: "session.lock" },
          { action: "audio.volume.set", args: { level: 10, extra: true } },
        ],
      },
      d.reg,
    );
    assert.equal(r.errors.length, 4);
    assert.match(r.errors[0].message, /unknown action/);
    assert.match(r.errors[1].message, /at most 20/);
    assert.match(r.errors[2].message, /cannot be used in routines/);
    assert.match(r.errors[3].message, /unknown parameter/);
  });

  test("routine definitions cannot smuggle code", (assert) => {
    const d = desktop();
    const r = validateRoutine({ id: "x", steps: [{ action: "workspace.focus", args: { workspace: "3; rm -rf ~" } }] }, d.reg);
    assert.equal(r.errors.length, 1);
    assert.match(r.errors[0].message, /must be a number/);
  });

  test("invalid documents and duplicate ids are reported", (assert) => {
    const d = desktop();
    assert.equal(validateRoutines("nope", d.reg).errors.length, 1);
    const dup = validateRoutines({ routines: [FOCUS, FOCUS] }, d.reg);
    assert.equal(dup.routines.length, 1);
    assert.match(dup.errors[0].message, /duplicate/);
    assert.match(validateRoutines({ routines: [{ id: "Bad Id", steps: [] }] }, d.reg).errors[0].message, /routine id/);
  });

  test("preview runs nothing and flags sensitive steps", (assert) => {
    const d = desktop();
    const routine = validateRoutine(
      { id: "p", steps: [{ action: "workspace.focus", args: { workspace: 2 } }, { action: "shell.exec", args: { argv: "x" } }] },
      d.reg,
    ).routine;
    const p = preview(routine, d.reg, {});
    assert.equal(p.steps.length, 2);
    assert.equal(p.needsConfirmation, true);
    assert.equal(d.state.log.length, 0, "preview must not execute");
  });

  test("run executes steps in order and records undo information", (assert) => {
    const d = desktop();
    const routine = validateRoutine(FOCUS, d.reg).routine;
    const seen = [];
    return run(routine, d.reg, {}, { onStep: (s) => seen.push(s.index) }).promise.then((rep) => {
      assert.equal(rep.ok, true);
      assert.deepEqual(d.state.log, ["ws3", "launch firefox.desktop", "vol30"]);
      assert.deepEqual(seen, [1, 2, 3]);
      assert.equal(rep.undo.length, 2, "launch has no genuine inverse");
      assert.equal(rep.undo[0].commandId, "audio.volume.set", "newest first");
    });
  });

  test("onError=stop skips the remaining steps", (assert) => {
    const d = desktop();
    const routine = validateRoutine(
      {
        id: "s",
        steps: [
          { action: "app.launch", args: { app: "missing.desktop" } },
          { action: "audio.volume.set", args: { level: 10 } },
        ],
      },
      d.reg,
    ).routine;
    return run(routine, d.reg, {}).promise.then((rep) => {
      assert.equal(rep.ok, false);
      assert.equal(rep.steps[1].skipped, true);
      assert.equal(d.state.volume, 50);
    });
  });

  test("onError=continue keeps going and still reports failure", (assert) => {
    const d = desktop();
    const routine = validateRoutine(
      {
        id: "c",
        onError: "continue",
        steps: [
          { action: "app.launch", args: { app: "missing.desktop" } },
          { action: "audio.volume.set", args: { level: 10 } },
        ],
      },
      d.reg,
    ).routine;
    return run(routine, d.reg, {}).promise.then((rep) => {
      assert.equal(rep.ok, false);
      assert.equal(d.state.volume, 10);
    });
  });

  test("routines with sensitive steps do nothing until confirmed", (assert) => {
    const d = desktop();
    const routine = validateRoutine({ id: "e", steps: [{ action: "shell.exec", args: { argv: "x" } }] }, d.reg).routine;
    return run(routine, d.reg, {})
      .promise.then((rep) => {
        assert.equal(rep.needsConfirmation, true);
        assert.equal(d.state.log.length, 0);
        return run(routine, d.reg, {}, { confirmed: true }).promise;
      })
      .then((rep) => {
        assert.equal(rep.ok, true);
        assert.deepEqual(d.state.log, ["exec"]);
      });
  });

  test("cancellation stops before the next step", (assert) => {
    const d = desktop();
    const routine = validateRoutine(FOCUS, d.reg).routine;
    let handle;
    handle = run(routine, d.reg, {}, { onStep: (s) => { if (s.index === 1) handle.cancel(); } });
    return handle.promise.then((rep) => {
      assert.equal(rep.cancelled, true);
      assert.deepEqual(d.state.log, ["ws3"]);
      assert.equal(rep.steps.filter((s) => s.skipped).length, 2);
    });
  });

  test("revert applies recorded inverses newest first", (assert) => {
    const d = desktop();
    const routine = validateRoutine(FOCUS, d.reg).routine;
    return run(routine, d.reg, {})
      .promise.then((rep) => revert(rep, d.reg, {}))
      .then((rv) => {
        assert.equal(rv.ok, true);
        assert.equal(d.state.volume, 50);
        assert.equal(d.state.workspace, 1);
      });
  });
});
