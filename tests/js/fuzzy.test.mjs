import { suite } from "./harness.mjs";
import { matchToken, matchFields, normalize, segments, highlightMarkup, tokenize } from "../../shell/lib/fuzzy.mjs";

export default suite("fuzzy", (test) => {
  test("rejects text that does not contain the query as a subsequence", (assert) => {
    assert.equal(matchToken("xyz", "Firefox"), null);
    assert.equal(matchToken("foxf", "Firefox"), null, "order matters");
    assert.equal(matchToken("firefoxx", "Firefox"), null, "longer than text");
  });

  test("empty query matches with zero score", (assert) => {
    assert.deepEqual(matchToken("", "anything"), { score: 0, positions: [] });
  });

  test("is case and diacritic insensitive", (assert) => {
    assert.ok(matchToken("FIRE", "firefox"));
    assert.ok(matchToken("cafe", "Café"));
    assert.equal(normalize("Ångström"), "angstrom");
  });

  test("aligns to word starts rather than the first fitting letters", (assert) => {
    assert.deepEqual(matchToken("vsc", "Visual Studio Code").positions, [0, 7, 14]);
    assert.deepEqual(matchToken("gc", "git-commit").positions, [0, 4]);
  });

  test("camelCase transitions count as word starts", (assert) => {
    const camel = matchToken("ds", "DesktopSettings");
    assert.deepEqual(camel.positions, [0, 7]);
  });

  test("ranks a word-start match above a mid-word match", (assert) => {
    const firefox = matchToken("ff", "Firefox");
    const office = matchToken("ff", "Office Suite");
    assert.ok(firefox.score > office.score, "Firefox " + firefox.score + " vs Office " + office.score);
  });

  test("ranks exact and prefix matches above scattered ones", (assert) => {
    const exact = matchToken("term", "term");
    const prefix = matchToken("term", "Terminal");
    const scattered = matchToken("term", "The Error Monitor");
    assert.ok(exact.score > prefix.score);
    assert.ok(prefix.score > scattered.score);
  });

  test("consecutive runs beat the same letters spread out", (assert) => {
    const run = matchToken("vol", "volume");
    const spread = matchToken("vol", "very old log");
    assert.ok(run.score > spread.score);
  });

  test("multi-token queries require every token (AND)", (assert) => {
    const fields = [{ text: "Firefox", weight: 1 }, { text: "web browser internet", weight: 0.7 }];
    assert.ok(matchFields("fire web", fields));
    assert.equal(matchFields("fire mail", fields), null);
  });

  test("each token uses its best field and highlights land in that field", (assert) => {
    const fields = [{ text: "Firefox", weight: 1 }, { text: "web browser", weight: 0.7 }];
    const m = matchFields("brow", fields);
    assert.ok(m);
    assert.deepEqual(m.highlights, { 1: [4, 5, 6, 7] });
  });

  test("weights change ranking between fields", (assert) => {
    const heavy = matchFields("vol", [{ text: "volume", weight: 1 }]);
    const light = matchFields("vol", [{ text: "volume", weight: 0.2 }]);
    assert.ok(heavy.score > light.score);
  });

  test("tokenize collapses whitespace", (assert) => {
    assert.deepEqual(tokenize("  set   vol  "), ["set", "vol"]);
    assert.deepEqual(tokenize(""), []);
  });

  test("segments split text into matched and unmatched runs", (assert) => {
    assert.deepEqual(segments("Firefox", [0, 4]), [
      { text: "F", match: true },
      { text: "ire", match: false },
      { text: "f", match: true },
      { text: "ox", match: false },
    ]);
  });

  test("highlight markup escapes HTML in titles", (assert) => {
    const html = highlightMarkup("<b>&", [0], "#65D9E8");
    assert.equal(html, '<font color="#65D9E8">&lt;</font>b&gt;&amp;');
  });
});
