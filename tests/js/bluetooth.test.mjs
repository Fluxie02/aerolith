import { suite, runAll } from "./harness.mjs";
import { sortDevices, connectedCount, stateLabel, batteryPercent } from "../../shell/lib/bluetooth.mjs";

const tests = suite("bluetooth", test => {
  test("devices sort connected then paired then name, with stable address ties", a => {
    const rows = [{address:"4",name:"Zulu",connected:true}, {address:"3",name:"Zulu",paired:true},
      {address:"2",name:"Alpha"}, {address:"1",name:"Alpha"}];
    a.deepEqual(sortDevices(rows).map(d=>d.address), ["4","3","1","2"]);
    a.equal(rows[0].address,"4");
    a.equal(sortDevices([]).length,0);
  });
  test("connected count excludes pairing and pending connections", a => {
    a.equal(connectedCount([{connected:true},{connecting:true},{paired:true},{connected:true}]),2);
    a.equal(connectedCount([]),0);
  });
  test("device state labels prefer connected", a => {
    a.equal(stateLabel(true,true),"connected");
    a.equal(stateLabel(false,true),"connecting");
    a.equal(stateLabel(false,false),"disconnected");
  });
  test("unknown battery is -1 while an empty battery remains zero", a => {
    a.equal(batteryPercent(false,0),-1); a.equal(batteryPercent(true,NaN),-1);
    a.equal(batteryPercent(true,0),0); a.equal(batteryPercent(true,0.755),76);
    a.equal(batteryPercent(true,2),100); a.equal(batteryPercent(true,-1),0);
  });
});
export default tests;
if (typeof process !== "undefined" && process.argv[1] && process.argv[1].endsWith("/bluetooth.test.mjs"))
  runAll([tests], line => console.log(line)).then(r => { process.exitCode = r.failed ? 1 : 0; });
