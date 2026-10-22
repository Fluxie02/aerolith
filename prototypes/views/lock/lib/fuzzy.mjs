// Fuzzy matching for the Command Core.
//
// Shared between Quickshell (Qt V4 engine) and Node.js tests, so this file
// sticks to the JavaScript subset V4 supports: no object spread, no async,
// no class fields, no String.replaceAll / Array.flat (see docs/RESEARCH.md).
//
// The matcher is a subsequence matcher in the style of fzf v1: find the
// first window of `text` that contains the query characters in order, tighten
// it from the right, then score the alignment. Scores reward matches at word
// starts and consecutive runs, and penalise gaps, so "ff" ranks "Firefox"
// above "Office Suite".

const SEPARATORS = " -_./:\\()[]";

const SCORE_MATCH = 16;
const BONUS_BOUNDARY = 10;
const BONUS_CAMEL = 7;
const BONUS_CONSECUTIVE = 6;
const BONUS_FIRST_CHAR = 8;
const PENALTY_GAP_START = 3;
const PENALTY_GAP_EXTENSION = 1;
const BONUS_EXACT = 40;
const BONUS_PREFIX = 20;

// Strip diacritics and lower-case. "Café" and "cafe" should match.
export function normalize(s) {
  return String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function isSeparator(ch) {
  return SEPARATORS.indexOf(ch) !== -1;
}

function isUpper(ch) {
  return ch !== ch.toLowerCase() && ch === ch.toUpperCase();
}

function boundaryBonus(original, i) {
  if (i === 0) return BONUS_BOUNDARY;
  const prev = original[i - 1];
  if (isSeparator(prev)) return BONUS_BOUNDARY;
  if (isUpper(original[i]) && !isUpper(prev)) return BONUS_CAMEL;
  return 0;
}

// Match a single query token against text.
// Returns { score, positions } or null when the token is not a subsequence.
//
// A cheap forward scan rejects non-matches first. Matches are then aligned
// with a dynamic programme over (query index, text index) that maximises the
// score, so "vsc" highlights the word starts of "Visual Studio Code" rather
// than the first letters that happen to fit. Gap penalties are linear, which
// keeps the programme O(query length x text length).
export function matchToken(token, text) {
  const q = normalize(token);
  if (q.length === 0) return { score: 0, positions: [] };
  const original = String(text);
  const t = normalize(original);
  // normalize() can change length when stripping combining marks; bonuses
  // are then computed on the normalised string instead of the original.
  const src = t.length === original.length ? original : t;
  const m = q.length;
  const n = t.length;
  if (m > n) return null;

  // Reject non-subsequences and find the useful window [lo, hi].
  let qi = 0;
  let lo = -1;
  for (let i = 0; i < n && qi < m; i++) {
    if (t[i] === q[qi]) {
      if (qi === 0) lo = i;
      qi++;
    }
  }
  if (qi < m) return null;
  let hi = n - 1;
  while (hi >= 0 && t[hi] !== q[m - 1]) hi--;

  const NEG = -1e9;
  const width = hi - lo + 1;
  const bonus = new Array(width);
  for (let j = 0; j < width; j++) bonus[j] = boundaryBonus(src, lo + j);

  // score[i][j]: best score with q[i] placed at text index lo + j.
  // from[i][j]: text offset of q[i - 1] in that best alignment.
  const score = [];
  const from = [];
  for (let i = 0; i < m; i++) {
    const row = new Array(width);
    const back = new Array(width);
    // Running max of prev[j'] + EXT * j' over j' <= j - 2, for gap transitions.
    let runBest = NEG;
    let runArg = -1;
    for (let j = 0; j < width; j++) {
      if (i > 0 && j >= 2) {
        const cand = score[i - 1][j - 2] + PENALTY_GAP_EXTENSION * (j - 2);
        if (cand > runBest) {
          runBest = cand;
          runArg = j - 2;
        }
      }
      row[j] = NEG;
      back[j] = -1;
      if (t[lo + j] !== q[i]) continue;
      const base = SCORE_MATCH + bonus[j];
      if (i === 0) {
        row[j] = base + (bonus[j] > 0 ? BONUS_FIRST_CHAR : 0);
        continue;
      }
      let best = NEG;
      let arg = -1;
      if (j >= 1 && score[i - 1][j - 1] > NEG / 2) {
        best = score[i - 1][j - 1] + BONUS_CONSECUTIVE;
        arg = j - 1;
      }
      if (runArg >= 0 && runBest > NEG / 2) {
        const gapScore = runBest - PENALTY_GAP_START - PENALTY_GAP_EXTENSION * (j - 2);
        if (gapScore > best) {
          best = gapScore;
          arg = runArg;
        }
      }
      if (arg >= 0) {
        row[j] = best + base;
        back[j] = arg;
      }
    }
    score.push(row);
    from.push(back);
  }

  let bestJ = -1;
  let total = NEG;
  for (let j = 0; j < width; j++)
    if (score[m - 1][j] > total) {
      total = score[m - 1][j];
      bestJ = j;
    }
  if (bestJ < 0 || total <= NEG / 2) return null;

  const positions = new Array(m);
  let j = bestJ;
  for (let i = m - 1; i >= 0; i--) {
    positions[i] = lo + j;
    j = from[i][j];
  }

  if (t === q) total += BONUS_EXACT;
  else if (t.indexOf(q) === 0) total += BONUS_PREFIX;
  // Mild preference for shorter strings when everything else is equal.
  total -= Math.min(n, 120) * 0.05;
  return { score: total, positions: positions };
}

// Split a query into whitespace-separated tokens.
export function tokenize(query) {
  return String(query).trim().split(/\s+/).filter((s) => s.length > 0);
}

// Match a full query against a candidate with weighted fields.
// fields: [{ text, weight }]. Every query token must match at least one
// field (AND semantics). Each token takes its best weighted field score.
// Returns { score, highlights } where highlights maps field index to the
// positions matched in that field, or null if any token fails.
export function matchFields(query, fields) {
  const tokens = tokenize(query);
  if (tokens.length === 0) return { score: 0, highlights: {} };
  let total = 0;
  const highlights = {};
  for (let ti = 0; ti < tokens.length; ti++) {
    let best = null;
    let bestField = -1;
    for (let fi = 0; fi < fields.length; fi++) {
      const f = fields[fi];
      if (!f || f.text === undefined || f.text === null || f.text === "") continue;
      const m = matchToken(tokens[ti], f.text);
      if (!m) continue;
      const weighted = m.score * (f.weight === undefined ? 1 : f.weight);
      if (best === null || weighted > best.score) {
        best = { score: weighted, positions: m.positions };
        bestField = fi;
      }
    }
    if (best === null) return null;
    total += best.score;
    if (!highlights[bestField]) highlights[bestField] = [];
    const h = highlights[bestField];
    for (let i = 0; i < best.positions.length; i++) {
      if (h.indexOf(best.positions[i]) === -1) h.push(best.positions[i]);
    }
  }
  for (const k in highlights) highlights[k].sort((a, b) => a - b);
  return { score: total, highlights: highlights };
}

// Split text into [{ text, match }] runs for rendering highlighted results.
export function segments(text, positions) {
  const s = String(text);
  const set = {};
  for (let i = 0; i < (positions || []).length; i++) set[positions[i]] = true;
  const out = [];
  let cur = "";
  let curMatch = false;
  for (let i = 0; i < s.length; i++) {
    const m = set[i] === true;
    if (i > 0 && m !== curMatch) {
      out.push({ text: cur, match: curMatch });
      cur = "";
    }
    cur += s[i];
    curMatch = m;
  }
  if (cur.length > 0) out.push({ text: cur, match: curMatch });
  return out;
}

// Escape text for Qt's StyledText and wrap matched runs in a tag.
export function highlightMarkup(text, positions, color) {
  const segs = segments(text, positions);
  let html = "";
  for (let i = 0; i < segs.length; i++) {
    const t = escapeHtml(segs[i].text);
    html += segs[i].match ? '<font color="' + color + '">' + t + "</font>" : t;
  }
  return html;
}

export function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
