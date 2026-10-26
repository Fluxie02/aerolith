import { suite } from "./harness.mjs";
import { desktopCovered, canvasFamily } from "../../shell/lib/ambient.mjs";

const output = { x: 0, y: 32, width: 2560, height: 1408 };
function window(x, y, width, height, extra) {
  return Object.assign({ workspaceId: 1, at: [x, y], size: [width, height], floating: false, ipc: {} }, extra || {});
}
const full = () => window(0, 32, 2560, 1408);

export default suite("ambient exposure", test => {
  test("a maximized client covers the logical 4K/1.5 work area", a => {
    a.equal(desktopCovered([window(0, 32, 2560, 1408, { ipc: { fullscreen: 1 } })], output, 1), true);
  });
  test("adjacent tiled windows cover together; removing one resumes", a => {
    const left = window(0, 32, 1280, 1408), right = window(1280, 32, 1280, 1408);
    a.equal(desktopCovered([left, right], output, 1), true);
    a.equal(desktopCovered([left], output, 1), false);
    a.equal(desktopCovered([], output, 1), false);
  });
  test("overlap does not count twice and a narrow exposed gap resumes", a => {
    a.equal(desktopCovered([window(0, 32, 1800, 1408), window(0, 32, 1800, 1408)], output, 1), false);
    a.equal(desktopCovered([window(0, 32, 1279, 1408), window(1280, 32, 1280, 1408)], output, 1), false);
    a.equal(desktopCovered([window(0, 32, 2560, 700), window(0, 733, 2560, 707)], output, 1), false);
  });
  test("four tiles and overlap cover the full union", a => {
    a.equal(desktopCovered([window(0, 32, 1300, 720), window(1280, 32, 1280, 720),
      window(0, 740, 1280, 700), window(1280, 740, 1280, 700)], output, 1), true);
  });
  test("switching workspaces, including named workspaces, changes exposure", a => {
    a.equal(desktopCovered([full()], output, 2), false);
    const named = full(); named.workspaceId = -1337;
    a.equal(desktopCovered([named], output, -1337), true);
    a.equal(desktopCovered([named], output, -1), false);
  });
  test("hidden and unmapped clients cannot hold ambient", a => {
    a.equal(desktopCovered([Object.assign(full(), { ipc: { mapped: false } })], output, 1), false);
    a.equal(desktopCovered([Object.assign(full(), { ipc: { hidden: true } })], output, 1), false);
  });
  test("ordinary floating windows do not hold; a maximized floating client can", a => {
    const floating = Object.assign(full(), { floating: true });
    a.equal(desktopCovered([floating], output, 1), false);
    floating.ipc = { fullscreen: 1 };
    a.equal(desktopCovered([floating], output, 1), true);
    floating.ipc = { fullscreen: true, fullscreenMode: 1 };
    a.equal(desktopCovered([floating], output, 1), true);
    floating.ipc = { fullscreenClient: 1 };
    a.equal(desktopCovered([floating], output, 1), false);
  });
  test("offset, rotated logical outputs and bottom strip reserve use the same coordinates", a => {
    const rotated = { x: -1440, y: 100, width: 1440, height: 2528 };
    a.equal(desktopCovered([window(-1500, 90, 1600, 2600)], rotated, 1), true);
    a.equal(desktopCovered([full()], rotated, 1), false);
  });
  test("bad or absent geometry never guesses coverage", a => {
    for (const o of [null, { x: 0, y: 0, width: 0, height: 100 }, { x: 0, y: 0, width: NaN, height: 100 }])
      a.equal(desktopCovered([full()], o, 1), false);
    for (const w of [window(0, 32, NaN, 1408), window(0, 32, -1, 1408), { workspaceId: 1 }, null])
      a.equal(desktopCovered([w], output, 1), false);
    a.equal(desktopCovered(null, output, 1), false);
  });
  test("font family lists resolve installed multiword names with generic fallback", a => {
    const installed = ["Noto Sans Mono", "JetBrains Mono"];
    a.equal(canvasFamily("JetBrains Mono", installed), "JetBrains Mono, monospace");
    a.equal(canvasFamily('"Missing Face", "Noto Sans Mono", monospace', installed), "Noto Sans Mono, monospace");
    a.equal(canvasFamily("jetbrains mono", installed), "JetBrains Mono, monospace");
    a.equal(canvasFamily("Missing Face", installed), "monospace");
    a.equal(canvasFamily("", installed), "monospace");
    a.equal(canvasFamily("Noto Sans Mono", { 0: "Noto Sans Mono", length: 1 }), "Noto Sans Mono, monospace");
    a.equal(canvasFamily("Odd;Face", ["Odd;Face"]), "monospace");
  });
});
