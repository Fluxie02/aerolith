import { suite, runAll } from "./harness.mjs";
import * as T from "../../shell/lib/tour.mjs";
import { validateConfig, setPath, toJsonSchema } from "../../shell/lib/config.mjs";

function initial() { return { active: false, step: 0, completed: false }; }
function context(patch) {
  return Object.assign({ ready: true, enabled: true, output: { name: "DP-1" },
    locked: false, fullscreen: false, completed: false, started: false }, patch || {});
}

const tourSuite = suite("tour", test => {
  test("uses the five contracted step ids", a => {
    a.deepEqual(T.STEPS, ["hatch", "ring", "search", "apps", "strip"]);
  });
  test("start resets the step without clearing saved completion", a => {
    a.deepEqual(T.transition({ active: false, step: 4, completed: true }, "start"),
      { active: true, step: 0, completed: true });
  });
  test("next on the last step finishes", a => {
    let state = T.transition(initial(), "start");
    for (let i = 1; i < T.STEPS.length; i++) {
      state = T.transition(state, "next");
      a.deepEqual(state, { active: true, step: i, completed: false });
    }
    a.deepEqual(T.transition(state, "next"), { active: false, step: 4, completed: true });
  });
  test("back moves one step and stops at hatch", a => {
    const start = T.transition(initial(), "start");
    a.deepEqual(T.transition(T.transition(start, "next"), "back"), start);
    a.deepEqual(T.transition(start, "back"), start);
  });
  test("inactive next and back do nothing", a => {
    a.deepEqual(T.transition(initial(), "next"), initial());
    a.deepEqual(T.transition(initial(), "back"), initial());
    const done = { active: false, step: 4, completed: true };
    a.deepEqual(T.transition(done, "back"), done);
    a.deepEqual(T.transition(done, "next"), done);
  });
  test("skip and finish complete even at the first step or while inactive", a => {
    for (const action of ["skip", "finish"]) {
      a.deepEqual(T.transition(initial(), action), { active: false, step: 0, completed: true });
      a.deepEqual(T.transition(T.transition(initial(), "start"), action),
        { active: false, step: 0, completed: true });
    }
  });
  test("transitions do not mutate their input", a => {
    const state = initial();
    T.transition(state, "start");
    a.deepEqual(state, initial());
    a.deepEqual(T.transition(state, "unknown"), initial());
  });
  test("old state files and malformed records start incomplete", a => {
    for (const record of [undefined, null, {}, [], false, "done",
      { completed: "true", version: T.VERSION }, { completed: true, version: "1" },
      { completed: true, version: -1 }, { completed: true, version: 1.5 }]) {
      a.equal(T.isCompleted(record), false);
    }
    a.deepEqual(T.readRecord(undefined), { completed: false, version: 0 });
  });
  test("completion belongs to this tour version", a => {
    a.equal(T.isCompleted({ completed: true, version: T.VERSION }), true);
    a.equal(T.isCompleted({ completed: false, version: T.VERSION }), false);
    a.equal(T.isCompleted({ completed: true, version: T.VERSION - 1 }), false);
    a.equal(T.isCompleted({ completed: true, version: T.VERSION + 1 }), false);
  });
  test("first run starts only after readiness and with a primary output", a => {
    a.equal(T.shouldAutoStart(context()), true);
    a.equal(T.shouldAutoStart(context({ ready: false })), false);
    a.equal(T.shouldAutoStart(context({ output: null })), false);
  });
  test("lock and fullscreen hold both automatic and manual presentation", a => {
    for (const patch of [{ locked: true }, { fullscreen: true }]) {
      a.equal(T.shouldAutoStart(context(patch)), false);
      a.equal(T.mayShowNow(context(patch)), false);
    }
    a.equal(T.shouldAutoStart(context()), true, "clearing a block permits the pending first run");
  });
  test("completed or already started never auto-start, but permit manual replay", a => {
    for (const patch of [{ completed: true }, { started: true }]) {
      a.equal(T.shouldAutoStart(context(patch)), false);
      a.equal(T.mayShowNow(context(patch)), true);
    }
  });
  test("disabled prevents both automatic and manual presentation", a => {
    a.equal(T.shouldAutoStart(context({ enabled: false })), false);
    a.equal(T.mayShowNow(context({ enabled: false })), false);
  });
  test("tour.enabled defaults true, accepts false, and validates booleans", a => {
    a.equal(validateConfig("").config.tour.enabled, true);
    a.equal(validateConfig('{"tour":{"enabled":false}}').config.tour.enabled, false);
    for (const invalid of ["false", 0, null, []]) {
      const result = validateConfig(JSON.stringify({ tour: { enabled: invalid } }));
      a.equal(result.config.tour.enabled, true);
      a.equal(result.errors[0].path, "tour.enabled");
    }
    a.equal(setPath({}, "tour.enabled", false).raw.tour.enabled, false);
    a.ok(setPath({}, "tour.enabled", "false").error);
    a.equal(toJsonSchema().properties.tour.properties.enabled.type, "boolean");
  });
});

export default tourSuite;

// Standalone until the merge owner adds this suite to the shared index.
if (typeof process !== "undefined" && /(?:^|\/)tour\.test\.mjs$/.test(process.argv[1] || "")) {
  runAll([tourSuite], line => console.log(line)).then(result => {
    process.exitCode = result.failed ? 1 : 0;
  });
}
