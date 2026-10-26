import { suite } from "./harness.mjs";
import * as B from "../../shell/lib/appbus.mjs";

const port = (name) => B.PORTS.find((p) => p.name === name);
const win = (address, appId, focusHistory) => ({ address, appId, focusHistory });

export default suite("appbus", (test) => {
  test("a running app's link focuses its most recent window, not the Navigator", (assert) => {
    const windows = [win("0xb", "firefox", 3), win("0xa", "firefox", 1), win("0xc", "foot", 0)];
    assert.deepEqual(B.action(windows, port("Firefox"), "0xc", []), { kind: "focus", address: "0xa" });
  });

  test("clicking the focused app again visits each of its windows in turn", (assert) => {
    const windows = [win("0xa", "firefox", 0), win("0xb", "firefox", 1), win("0xc", "firefox", 2)];
    const seen = [];
    let active = "0xa";
    for (let i = 0; i < 3; i++) {
      const a = B.action(windows, port("Firefox"), active, []);
      seen.push(a.address);
      active = a.address;
    }
    assert.deepEqual(seen, ["0xb", "0xc", "0xa"]);
  });

  test("an app whose only window has focus does nothing", (assert) => {
    assert.deepEqual(B.action([win("0xa", "firefox", 0)], port("Firefox"), "0xa", []), { kind: "none" });
  });

  test("an installed app that is not running is started from its desktop entry", (assert) => {
    const entries = [{ id: "libreoffice-writer" }, { id: "libreoffice-startcenter" }, { id: "org.mozilla.firefox" }];
    assert.deepEqual(B.action([], port("LibreOffice"), "", entries), { kind: "launch", id: "libreoffice-startcenter" });
    assert.deepEqual(B.action([], port("Firefox"), "", entries), { kind: "launch", id: "org.mozilla.firefox" });
    assert.deepEqual(B.action([], port("Discord"), "", [{ id: "dev.vencord.Vesktop" }]), { kind: "launch", id: "dev.vencord.Vesktop" });
  });

  test("an app that is not installed opens the search", (assert) => {
    assert.deepEqual(B.action([], port("Steam"), "", [{ id: "firefox" }]), { kind: "search", query: "steam" });
  });

  test("games launched by Steam are not Steam's windows", (assert) => {
    assert.equal(B.matches("steam_app_460920", port("Steam")), false);
    assert.equal(B.matches("steam", port("Steam")), true);
  });

  test("desktop ids match without .desktop and case", (assert) => {
    assert.equal(B.entryFor([{ id: "Steam.desktop" }], port("Steam")).id, "Steam.desktop");
  });
});
