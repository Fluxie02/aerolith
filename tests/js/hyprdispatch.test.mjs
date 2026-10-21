import { suite } from "./harness.mjs";
import {
  luaString,
  normalizeAddress,
  workspaceSelector,
  focusWorkspace,
  focusWindow,
  moveWindowToWorkspace,
  closeWindow,
  exitSession,
  interpretReply,
} from "../../shell/lib/hyprdispatch.mjs";

export default suite("hyprdispatch", (test) => {
  test("Lua string literals escape quotes, backslashes and control characters", (assert) => {
    assert.equal(luaString('a"b'), '"a\\"b"');
    assert.equal(luaString("a\\b"), '"a\\\\b"');
    assert.equal(luaString("a\nb\tc"), '"a\\nb\\tc"');
    assert.equal(luaString("\r"), '"\\013"');
    assert.equal(luaString("\u0000"), '"\\000"');
  });

  test("Lua string literals cannot be broken out of", (assert) => {
    const hostile = '") os.execute("rm -rf ~") --';
    const lit = luaString(hostile);
    // Inside the literal every quote must be escaped, so the only unescaped
    // quotes are the delimiters.
    const body = lit.slice(1, -1);
    assert.equal(body.replace(/\\\\/g, "").replace(/\\"/g, "").indexOf('"'), -1);
    assert.equal(lit.charAt(0), '"');
    assert.equal(lit.charAt(lit.length - 1), '"');
  });

  test("non-ASCII is emitted as three-digit UTF-8 byte escapes", (assert) => {
    assert.equal(luaString("é"), '"\\195\\169"');
    assert.equal(luaString("1é2"), '"1\\195\\1692"', "digits after an escape stay separate");
    assert.equal(luaString("😀"), '"\\240\\159\\152\\128"');
  });

  test("addresses are normalised and validated", (assert) => {
    assert.equal(normalizeAddress("5a00000001a0"), "0x5a00000001a0");
    assert.equal(normalizeAddress("0x5A00000001A0"), "0x5a00000001a0");
    assert.throws(() => normalizeAddress("0x12; rm"), /invalid window address/);
    assert.throws(() => normalizeAddress(""), /invalid window address/);
    assert.throws(() => normalizeAddress("12345678901234567"), /invalid window address/);
  });

  test("workspace selectors accept ids and safe names only", (assert) => {
    assert.equal(workspaceSelector(3), "3");
    assert.equal(workspaceSelector("7"), "7");
    assert.equal(workspaceSelector({ name: "web" }), "name:web");
    assert.throws(() => workspaceSelector(0), /out of range/);
    assert.throws(() => workspaceSelector(-98), /invalid workspace|out of range/);
    assert.throws(() => workspaceSelector(1.5), /invalid workspace|out of range/);
    assert.throws(() => workspaceSelector({ name: "a,b" }), /unsupported workspace name/);
    assert.throws(() => workspaceSelector({ name: 'x" })' }), /unsupported workspace name/);
  });

  test("legacy dialect produces hyprlang dispatcher strings", (assert) => {
    assert.equal(focusWorkspace("hyprlang", 3), "workspace 3");
    assert.equal(focusWindow("hyprlang", "5a0"), "focuswindow address:0x5a0");
    assert.equal(moveWindowToWorkspace("hyprlang", "5a0", 2, false), "movetoworkspacesilent 2,address:0x5a0");
    assert.equal(moveWindowToWorkspace("hyprlang", "5a0", 2, true), "movetoworkspace 2,address:0x5a0");
    assert.equal(closeWindow("hyprlang", "0x5a0"), "closewindow address:0x5a0");
  });

  test("Lua dialect produces hl.dsp calls with quoted selectors", (assert) => {
    assert.equal(focusWorkspace("lua", 3), 'hl.dsp.focus({ workspace = "3" })');
    assert.equal(focusWorkspace("lua", { name: "web" }), 'hl.dsp.focus({ workspace = "name:web" })');
    assert.equal(focusWindow("lua", "5a0"), 'hl.dsp.focus({ window = "address:0x5a0" })');
    assert.equal(
      moveWindowToWorkspace("lua", "5a0", 4, false),
      'hl.dsp.window.move({ workspace = "4", follow = false, window = "address:0x5a0" })',
    );
    assert.equal(closeWindow("lua", "5a0"), 'hl.dsp.window.close({ window = "address:0x5a0" })');
  });

  test("session exit in both dialects", (assert) => {
    assert.equal(exitSession("lua"), "hl.dsp.exit()");
    assert.equal(exitSession("hyprlang"), "exit");
  });

  test("unknown dialects are rejected", (assert) => {
    assert.throws(() => focusWorkspace("sway", 1), /unknown dispatch dialect/);
  });

  test("dispatch replies are interpreted strictly", (assert) => {
    assert.deepEqual(interpretReply("ok"), { ok: true, message: "ok" });
    assert.equal(interpretReply("ok\n").ok, true);
    assert.equal(interpretReply("Invalid dispatcher").ok, false);
    assert.equal(interpretReply("").ok, false);
    assert.equal(interpretReply(null).message, "no reply from Hyprland");
  });
});
