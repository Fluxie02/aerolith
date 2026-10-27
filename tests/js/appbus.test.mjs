import { suite } from "./harness.mjs";
import * as B from "../../shell/lib/appbus.mjs";
import { recordUse } from "../../shell/lib/launch.mjs";

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

  test("window classes resolve desktop ids and suffixes case-insensitively", assert => {
    const entry = { id: "Editor.DESKTOP", name: "Text Editor" };
    for (const id of ["editor", "EDITOR", "Editor.desktop"])
      assert.equal(B.entryForWindow([entry], id), entry);
    assert.equal(B.entryForWindow([entry], "edit"), null);
  });

  test("StartupWMClass resolves a different desktop id, but exact ids win", assert => {
    const startup = { id: "com.example.Editor", startupClass: "Code", name: "Editor" };
    const exact = { id: "code.desktop", name: "Code" };
    assert.equal(B.entryForWindow([startup], "CODE"), startup);
    assert.equal(B.entryForWindow([startup, exact], "Code"), exact);
    const apps = B.barApps([startup, exact], [win("0xa", "Code", 0)], {}, 100);
    assert.equal(apps[0].id, exact.id);
    assert.equal(B.matches("Code", apps.find(e => e.id === startup.id)), false);
  });

  test("reverse-DNS and Flatpak classes keep their desktop entry name and icon", assert => {
    const entries = [
      { id: "org.gnome.Nautilus.desktop", name: "Files", icon: "org.gnome.Nautilus" },
      { id: "org.mozilla.firefox", name: "Firefox", icon: "firefox" },
      { id: "dev.vencord.Vesktop.desktop", name: "Vesktop", icon: "vesktop" }
    ];
    for (const pair of [["ORG.GNOME.NAUTILUS", 0], ["org.mozilla.Firefox.desktop", 1], ["firefox", 1], ["vesktop", 2]])
      assert.equal(B.entryForWindow(entries, pair[0]), entries[pair[1]]);
    assert.equal(B.entryForWindow(entries, "firefox-helper"), null);
    const apps = B.barApps(entries, [win("0xa", "org.gnome.Nautilus", 0)], {}, 100, 1);
    assert.equal(apps[0].name, "Files");
    assert.equal(apps[0].icon, "org.gnome.Nautilus");
  });

  test("unknown windows have readable names, stable ids and a generic icon", assert => {
    const apps = B.barApps([], [win("0xa", "com.example.some_app", 0), win("0xb", "COM.EXAMPLE.SOME_APP", 1), win("0xc", "", 2)], {}, 100);
    assert.equal(apps.length, 1);
    assert.equal(apps[0].id, "com.example.some_app");
    assert.equal(apps[0].name, "Some app");
    assert.equal(apps[0].icon, "application-x-executable");
    assert.equal(apps[0].running, true);
    assert.equal(apps[0].windows.length, 2);
    assert.equal(B.readableName(""), "Application");
    assert.deepEqual(B.action([], apps[0], "", []), { kind: "search", query: "Some app" });
  });

  test("usage ranks before running apps and unused installs, with a caller limit", assert => {
    const now = 50 * 24 * 3600 * 1000;
    const entries = [{ id: "a", name: "A" }, { id: "b.desktop", name: "B" }, { id: "c", name: "C" }];
    const windows = [win("0xa", "a", 0)];
    const usage = { "apps:B.DESKTOP": { count: 2, last: now }, "apps:c": { count: 10, last: 0 }, "commands:a": { count: 999, last: now } };
    const rank = () => B.barApps(entries, windows, usage, now, 2);
    assert.deepEqual(rank().map(e => e.id), ["b.desktop", "c"]);
    assert.equal(rank()[0].running, false);
    assert.deepEqual(B.barApps(entries, windows, {}, now).map(e => e.id), ["a", "b.desktop", "c"]);
    assert.equal(B.barApps(entries, windows, usage, now, 0).length, 0);
    for (let i = 0; i < 3; i++) recordUse(usage, "apps:a", now);
    assert.deepEqual(rank().map(e => e.id), ["a", "b.desktop"]);
    assert.deepEqual(entries.map(e => e.id), ["a", "b.desktop", "c"]);
  });

  test("resolved aliases deduplicate windows and preserve focus, cycle and launch", assert => {
    const entry = { id: "com.example.Editor.desktop", name: "Editor", startupClass: "Code" };
    const windows = [win("0xb", "CODE", 0), win("0xa", "com.example.Editor", 2), win("0xc", "code-helper", 1)];
    const apps = B.barApps([entry, entry], windows, {}, 100);
    assert.equal(apps.length, 2);
    const app = apps.find(e => e.id === entry.id);
    assert.equal(app.windows.length, 2);
    assert.equal(B.matches("code-helper", app), false);
    assert.deepEqual(B.action(windows, app, "0xc", [entry]), { kind: "focus", address: "0xb" });
    assert.deepEqual(B.action(windows, app, "0xb", [entry]), { kind: "focus", address: "0xa" });
    assert.deepEqual(B.action([windows[0]], app, "0xb", [entry]), { kind: "none" });
    assert.deepEqual(B.action([], app, "", [entry]), { kind: "launch", id: entry.id });
  });
});
