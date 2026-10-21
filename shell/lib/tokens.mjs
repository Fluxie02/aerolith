// AEROLITH Instrument System: design tokens.
//
// All colours, type, spacing, dimensions, opacity, motion and density values
// used by the shell come from here, combined with the user's configuration
// by the Theme singleton. Components never hard-code these values.
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

export const PALETTE = {
  obsidian: "#101318", // background
  surface: "#1A2129", // instrument surface
  surface2: "#222B35", // secondary surface
  grid: "#35414B", // grid lines and dividers
  text: "#E8EEF2", // primary text
  textDim: "#8E9BA7", // secondary text
  signal: "#65D9E8", // cyan: active information and selection
  caution: "#F2B84B", // amber: caution
  critical: "#F06464", // red: errors and critical states
  nominal: "#7FC8A0", // restrained success
};

// Contrast-checked against obsidian and surface in tests/js/tokens.test.mjs.
export const MIN_TEXT_CONTRAST = 4.5;

export const FONTS = {
  sans: "Inter",
  sansFallback: ["Inter Variable", "Noto Sans", "Cantarell", "DejaVu Sans", "sans-serif"],
  mono: "JetBrains Mono",
  monoFallback: ["JetBrains Mono NL", "Noto Sans Mono", "DejaVu Sans Mono", "monospace"],
};

// Sizes in logical pixels at uiScale 1.0, per density.
export const DENSITY = {
  compact: {
    stripHeight: 24,
    rowHeight: 26,
    pad: 6,
    gap: 4,
    fontXs: 9,
    fontSm: 10,
    fontMd: 12,
    fontLg: 15,
    fontXl: 22,
  },
  standard: {
    stripHeight: 28,
    rowHeight: 32,
    pad: 10,
    gap: 6,
    fontXs: 10,
    fontSm: 11,
    fontMd: 13,
    fontLg: 17,
    fontXl: 26,
  },
  comfortable: {
    stripHeight: 34,
    rowHeight: 40,
    pad: 14,
    gap: 8,
    fontXs: 11,
    fontSm: 12,
    fontMd: 15,
    fontLg: 19,
    fontXl: 30,
  },
};

export const SHAPE = {
  radius: 2, // instruments are machined, not pillowy
  border: 1,
  bracket: 10, // length of corner registration marks
  bracketWeight: 2,
  hairline: 1,
};

export const OPACITY = {
  backdrop: 0.55,
  backdropLowEffects: 0.85,
  disabled: 0.4,
  gridMinor: 0.35,
  panel: 0.97,
};

// Durations in ms. "reduced" keeps feedback but drops travel; "off" is instant.
export const MOTION = {
  full: { fast: 90, normal: 160, slow: 260 },
  reduced: { fast: 0, normal: 80, slow: 120 },
  off: { fast: 0, normal: 0, slow: 0 },
};

export function densityTokens(name) {
  return DENSITY[name] || DENSITY.standard;
}

export function motionTokens(name) {
  return MOTION[name] || MOTION.full;
}

// Merge user palette overrides; only known keys with valid colours apply.
export function resolvePalette(overrides) {
  const out = Object.assign({}, PALETTE);
  const o = overrides || {};
  for (const k in o) {
    if (Object.prototype.hasOwnProperty.call(PALETTE, k) && isColor(o[k])) out[k] = o[k];
  }
  return out;
}

export function isColor(s) {
  return typeof s === "string" && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s);
}

// WCAG 2.x relative luminance and contrast ratio.
export function luminance(hex) {
  const h = hex.length === 9 ? hex.slice(3) : hex.slice(1);
  const ch = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16) / 255);
  const lin = ch.map((c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)));
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}

export function contrast(a, b) {
  const la = luminance(a);
  const lb = luminance(b);
  const hi = Math.max(la, lb);
  const lo = Math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

export function fontFamilyList(primary, fallbacks) {
  const list = [primary].concat(fallbacks || []);
  const seen = {};
  return list.filter((f) => {
    if (!f || seen[f]) return false;
    seen[f] = true;
    return true;
  });
}

export function stateColor(palette, state) {
  switch (state) {
    case "critical":
      return palette.critical;
    case "caution":
      return palette.caution;
    case "active":
      return palette.signal;
    case "nominal":
      return palette.nominal;
    case "unknown":
      return palette.textDim;
    default:
      return palette.text;
  }
}
