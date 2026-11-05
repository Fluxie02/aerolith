import { suite, runAll } from "./harness.mjs";
import { summary, sortNetworks, stateLabel, percent } from "../../shell/lib/network.mjs";

const tests = suite("network", test => {
  test("missing backend and empty backend have distinct states", a => {
    a.deepEqual(summary(false, []), {kind:"none", state:"unavailable", connectionName:"", signal:-1});
    a.equal(summary(true, []).state, "disconnected");
  });
  test("connected ethernet wins over connected wifi regardless of device order", a => {
    const wifi = {kind:"wifi", state:"connected", name:"Air", signal:82};
    const wire = {kind:"ethernet", state:"connected", name:"Desk"};
    a.deepEqual(summary(true, [wifi, wire]), {kind:"ethernet", state:"connected", connectionName:"Desk", signal:-1});
    a.equal(summary(true, [wire, wifi]).kind, "ethernet");
  });
  test("a connected route wins over a connecting route", a => {
    a.equal(summary(true, [{kind:"ethernet", state:"connecting"}, {kind:"wifi", state:"connected", signal:40}]).kind, "wifi");
    a.equal(summary(true, [{kind:"wifi", state:"connecting", name:"Air", signal:40}]).state, "connecting");
  });
  test("networks sort connected then known then signal, without mutating input", a => {
    const rows = [{name:"Strong", signal:95}, {name:"Known", signal:10, known:true}, {name:"Active", signal:5, connected:true}];
    a.deepEqual(sortNetworks(rows).map(n => n.name), ["Active", "Known", "Strong"]);
    a.equal(rows[0].name, "Strong");
  });
  test("password support is kept per network, so enterprise networks never get a password prompt", a => {
    const rows = sortNetworks([{name:"Home", signal:60, secured:true, takesPassword:true}, {name:"eduroam", signal:80, secured:true}]);
    a.deepEqual(rows.map(n => [n.name, n.secured, n.takesPassword]), [["eduroam", true, false], ["Home", true, true]]);
  });
  test("duplicate SSIDs select the actionable connected/known representative", a => {
    const rows = [{name:"Air", signal:95}, {name:"Air", signal:20, known:true}, {name:"Air", signal:10, connected:true}];
    a.equal(sortNetworks(rows).length, 1);
    a.equal(sortNetworks(rows)[0].signal, 10);
    a.equal(sortNetworks(rows.slice(0,2))[0].known, true);
  });
  test("hidden SSIDs are omitted; special names and equal signal are deterministic", a => {
    a.deepEqual(sortNetworks([{name:"",signal:99},{name:"__proto__",signal:2},{name:"__proto__",signal:1}]).map(n=>n.name), ["__proto__"]);
    a.deepEqual(sortNetworks([{name:"B",signal:2},{name:"A",signal:2}]).map(n=>n.name), ["A","B"]);
  });
  test("failure records contain only contract fields and never credentials", a => {
    const n = sortNetworks([{name:"Air", signal:10, failed:true, failReason:"No secrets", psk:"secret"}])[0];
    a.equal(n.failed, true); a.equal(n.failReason, "No secrets"); a.equal(n.psk, undefined);
    a.equal(sortNetworks([{name:"Air",signal:0}])[0].failReason, "");
  });
  test("backend state labels and fractional signal are normalized", a => {
    a.equal(stateLabel("disconnecting"), "disconnected");
    a.equal(stateLabel("connecting"), "connecting");
    a.equal(percent(0.815), 82); a.equal(percent(-1), 0); a.equal(percent(2),100); a.equal(percent(NaN),0);
  });
});
export default tests;
if (typeof process !== "undefined" && process.argv[1] && process.argv[1].endsWith("/network.test.mjs"))
  runAll([tests], line => console.log(line)).then(r => { process.exitCode = r.failed ? 1 : 0; });
