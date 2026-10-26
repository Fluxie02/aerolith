import { suite } from "./harness.mjs";
import * as B from "../../shell/lib/brightness.mjs";

export default suite("brightness", (test) => {
  test("prefers firmware, then platform, then raw backlights", (assert) => {
    const list = [
      { name: "intel_backlight", type: "raw", max: 96000, value: 48000 },
      { name: "acpi_video0", type: "firmware", max: 100, value: 50 },
      { name: "nvidia_0", type: "platform", max: 100, value: 50 },
    ];
    assert.equal(B.pickDevice(list).name, "acpi_video0");
    assert.equal(B.pickDevice(list.slice(0, 1).concat(list.slice(2))).name, "nvidia_0");
  });

  test("among equals the finest control wins; unusable entries are skipped", (assert) => {
    assert.equal(B.pickDevice([{ name: "a", type: "raw", max: 255 }, { name: "b", type: "raw", max: 96000 }]).name, "b");
    assert.equal(B.pickDevice([{ name: "a", type: "raw", max: 0 }]), null);
    assert.equal(B.pickDevice([{ name: "../../etc", type: "raw", max: 10 }]), null);
    assert.equal(B.pickDevice([]), null);
    assert.equal(B.pickDevice(null), null);
  });

  test("parses the probe output", (assert) => {
    const d = B.parseDevices("intel_backlight\traw\t96000\t48000\n\nbad line\n");
    assert.deepEqual(d, [{ name: "intel_backlight", type: "raw", max: 96000, value: 48000 }]);
  });

  test("converts between raw values and percent without ever reaching 0", (assert) => {
    assert.equal(B.toPercent(48000, 96000), 50);
    assert.equal(B.fromPercent(50, 96000), 48000);
    assert.equal(B.fromPercent(0, 96000), 960);
    assert.equal(B.fromPercent(1, 7), 1);
    assert.equal(B.fromPercent(150, 255), 255);
    assert.ok(isNaN(B.toPercent(5, 0)));
  });

  test("steps align to the step size and stay in range", (assert) => {
    assert.equal(B.stepPercent(47, 5), 50);
    assert.equal(B.stepPercent(50, 5), 55);
    assert.equal(B.stepPercent(47, -5), 45);
    assert.equal(B.stepPercent(45, -5), 40);
    assert.equal(B.stepPercent(3, -5), 1);
    assert.equal(B.stepPercent(98, 5), 100);
  });
});
