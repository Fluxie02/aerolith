import { suite } from "./harness.mjs";
import * as W from "../../shell/lib/welcome.mjs";
import * as T from "../../shell/lib/tour.mjs";
import { validateConfig, setPath, toJsonSchema } from "../../shell/lib/config.mjs";

const context = () => ({configLoaded: true, fileBroken: false, fileMissing: false, configErrors: [],
  outputsReady: true, primary: {name: "DP-1"}, startup: {method: "systemd", enabled: true}, tourCompleted: true});
export default suite("welcome", test => {
  test("fresh installs alone are pending; any prior state or finished tour is upgrade", a => {
    a.equal(W.firstRunPending(true, false, null, null), true);
    for (const c of [[false, false, null, null], [true, true, null, null],
      [true, false, {version: 1, seen: true}, null], [true, false, null, {completed: true, version: 99}]])
      a.equal(W.firstRunPending(...c), false);
  });
  test("versioned persisted handoff and resume step reject corrupt input", a => {
    const empty = {version: 1, tourFinished: null, seen: false, handedOff: false, tourStep: 0};
    for (const r of [null, {}, [], {version: 2, seen: true}]) a.deepEqual(W.readRecord(r), empty);
    a.deepEqual(W.readRecord({version: 1, seen: true, handedOff: true, tourStep: 3}),
      {version: 1, tourFinished: null, seen: true, handedOff: true, tourStep: 3});
    for (const tourStep of [-1, 5, "3", null, 1.5]) a.equal(W.readRecord({version: 1, tourStep}).tourStep, 0);
  });
  test("lock, fullscreen, missing output and unreadiness hold presentation", a => {
    const c = {ready: true, output: {}, locked: false, fullscreen: false};
    a.equal(W.mayShow(c), true);
    for (const patch of [{ready: false}, {output: null}, {locked: true}, {fullscreen: true}])
      a.equal(W.mayShow(Object.assign({}, c, patch)), false);
    a.equal(T.shouldAutoStart(Object.assign({}, c, {enabled: true, welcomeHolds: true})), false);
  });
  test("showOnStartup is a false boolean by default and rejects non-booleans", a => {
    a.equal(validateConfig("").config.welcome.showOnStartup, false);
    a.equal(setPath({}, "welcome.showOnStartup", true).raw.welcome.showOnStartup, true);
    for (const value of ["true", 1, null, []]) a.ok(setPath({}, "welcome.showOnStartup", value).error);
    a.equal(toJsonSchema().properties.welcome.properties.showOnStartup.type, "boolean");
  });
  test("only verified checks pass; missing data is unknown and failures need attention", a => {
    a.deepEqual(W.checklist(context()).map(c => c.state), ["passed", "passed", "passed", "passed"]);
    const c = context(); c.fileMissing = true; c.outputsReady = false; c.startup = {enabled: null}; c.tourCompleted = false;
    a.deepEqual(W.checklist(c).map(c => c.state), ["unknown", "unknown", "unknown", "attention"]);
    c.fileMissing = false; c.fileBroken = true; c.outputsReady = true; c.primary = null; c.startup = {enabled: false};
    a.deepEqual(W.checklist(c).map(c => c.state), ["attention", "attention", "attention", "attention"]);
    c.startup = {enabled: true, method: null}; a.equal(W.checklist(c)[2].state, "unknown");
    c.tourCompleted = null; a.equal(W.checklist(c)[3].state, "unknown");
    c.fileBroken = false; c.configErrors = [{}]; a.equal(W.checklist(c)[0].state, "attention");
  });
  test("doctor failures and missing/invalid data never claim success", a => {
    const good = {code: 0, stdout: JSON.stringify({checks: [{name: "test", status: "ok", detail: "verified"}]})};
    a.equal(W.diagnosticsResult(good).ok, true);
    const fail = {code: 1, stdout: JSON.stringify({checks: [{name: "test", status: "fail", detail: "broken"}]})};
    a.equal(W.diagnosticsResult(fail).ok, false);
    for (const r of [{code: -1, stderr: "missing"}, {code: -1, timedOut: true}, {code: 0, stdout: '{}'},
      {code: 0, stdout: '{"checks":[{"status":"ok"}]}'}]) {
      a.equal(W.diagnosticsResult(r).ok, null); a.ok(W.diagnosticsResult(r).error);
    }
  });
  test("report preserves errors, versions, outputs and diagnostic details without executing content", a => {
    const info = {version: {aerolith: "1.2", quickshell: null, hyprland: null}, dialect: null, gpu: null,
      outputs: [{name: "DP-1", mode: "1920x1080", scale: 1, profile: "oled"}],
      configErrors: [{path: "foo", message: "$(no execution)"}], configWarnings: []};
    const text = W.report(info, {running: false, ok: null, error: null, checks: []});
    for (const part of ["1.2", "Unavailable", "DP-1", "oled", "foo: $(no execution)", "Not run"])
      a.ok(text.indexOf(part) >= 0);
  });
});
