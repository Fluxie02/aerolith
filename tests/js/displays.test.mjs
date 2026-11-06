import { suite } from "./harness.mjs";
import * as D from "../../shell/lib/displays.mjs";
import { validateConfig, toJsonSchema } from "../../shell/lib/config.mjs";

const screens = [{ name: "DP-1" }, { name: "HDMI-A-1" }];
const monitors = [{ name: "DP-1", id: 3, scale: 1.5, refreshRate: 240 }, { name: "HDMI-A-1", id: 0, scale: 1, refreshRate: 60, focused: true }];
export default suite("displays", test => {
  test("live screen rejects removed wrappers and same-name replacements", a => {
    const removed = { name: "DP-1" }, replugged = { name: "DP-1" };
    a.equal(D.liveScreen([removed], removed), removed);
    a.equal(D.liveScreen([], removed), null);
    a.equal(D.liveScreen([replugged], removed), null);
    a.equal(D.liveScreen([replugged], replugged), replugged);
    a.equal(D.liveScreen(null, removed), null);
  });
  test("joins by name, preserves screens and monitor metadata", a => {
    const r = D.resolveDisplays(screens, monitors);
    a.equal(r.outputs[0].screen, screens[0]);
    a.equal(r.outputs[0].scale, 1.5);
    a.equal(r.outputs[0].refresh, 240);
    a.equal(r.primary.name, "HDMI-A-1");
    a.equal(r.focused, r.primary);
  });
  test("primary, deprecated alias, lowest id, then first screen", a => {
    a.equal(D.resolveDisplays(screens, monitors, { primary: "DP-1", output: "HDMI-A-1" }).primary.name, "DP-1");
    a.equal(D.resolveDisplays(screens, monitors, { primary: "unplugged", output: "DP-1" }).primary.name, "DP-1");
    a.equal(D.resolveDisplays(screens, monitors, { primary: "renamed", output: "old" }).primary.name, "HDMI-A-1");
    a.equal(D.resolveDisplays(screens, []).primary.screen, screens[0]);
    a.equal(D.resolveDisplays([], monitors).primary, null);
  });
  test("per-output defaults, profiles and global disable switches", a => {
    const cfg = { outputs: { "DP-1": { strip: false, profile: "oled" }, old: { ground: false } } };
    a.deepEqual(D.settingsFor(cfg, "DP-1"), { strip: false, ground: true, profile: "oled" });
    a.deepEqual(D.settingsFor(cfg, "renamed"), { strip: true, ground: true, profile: "standard" });
    a.deepEqual(D.settingsFor(cfg, "DP-1", { ground: { enabled: false } }), { strip: false, ground: false, profile: "oled" });
    a.equal(D.settingsFor({ outputs: { "DP-1": { strip: true } } }, "DP-1", { strip: { visible: false } }).strip, false);
    a.equal(D.settingsFor(cfg, "__proto__").ground, true);
  });
  test("overlay follows focus by default; notices use primary or explicit output", a => {
    const r = D.resolveDisplays(screens, monitors, { primary: "DP-1" });
    a.equal(r.overlay.name, "HDMI-A-1");
    a.equal(r.notices.name, "DP-1");
    a.equal(D.resolveDisplays(screens, monitors, { primary: "DP-1", overlayOn: "primary", noticesOn: "focused" }).overlay.name, "DP-1");
    a.equal(D.resolveDisplays(screens, monitors, { noticesOn: "DP-1" }).notices.name, "DP-1");
    a.equal(D.resolveDisplays(screens, monitors, { noticesOn: "gone" }).notices.name, "HDMI-A-1");
    a.equal(D.resolveDisplays(screens, [], {}).focused.screen, screens[0]);
  });
  test("hotplug only creates real screens and missing choices fall back and recover", a => {
    const cfg = { primary: "HDMI-A-1", noticesOn: "HDMI-A-1" };
    const unplugged = D.resolveDisplays([screens[0]], monitors, cfg);
    a.equal(unplugged.outputs.length, 1);
    a.equal(unplugged.overlay.name, "DP-1");
    a.equal(unplugged.notices.name, "DP-1");
    a.equal(D.resolveDisplays(screens, monitors, cfg).primary.name, "HDMI-A-1");
    a.equal(D.resolveDisplays([], [], cfg).overlay, null);
  });
  test("single mismatched names retain monitor focus and alias compatibility", a => {
    const r = D.resolveDisplays([{ name: "HEADLESS-1" }], [monitors[0]], { output: "DP-1" });
    a.equal(r.primary.name, "HEADLESS-1");
    a.equal(r.primary.monitorName, "DP-1");
    a.equal(r.primary.id, 3);
  });
  test("config validates nested output settings independently and keeps old keys", a => {
    const r = validateConfig(JSON.stringify({ display: { output: "DP-1", warnOnMultipleDisplays: true,
      primary: "HDMI-A-1", overlayOn: "primary", noticesOn: "DP-1",
      outputs: { "DP-1": { ground: false, profile: "oled", strip: "no" }, "old-name": { profile: "invalid" } } } }));
    a.equal(r.warnings.length, 0);
    a.equal(r.errors.length, 2);
    a.deepEqual(r.config.display.outputs["DP-1"], { ground: false, strip: true, profile: "oled", blackBackground: false });
    a.equal(r.config.display.outputs["old-name"].profile, "standard");
    a.equal(r.config.display.output, "DP-1");
    a.equal(r.config.display.warnOnMultipleDisplays, true);
    a.equal(toJsonSchema().properties.display.properties.outputs.additionalProperties.properties.strip.default, true);
    const bad = validateConfig('{"display":{"outputs":{"DP-1":false},"overlayOn":"bad"}}');
    a.equal(bad.errors.length, 2);
    a.equal(bad.config.display.overlayOn, "focused");
  });
});
