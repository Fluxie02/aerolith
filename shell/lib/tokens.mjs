// AEROLITH Instrument System: design tokens.
//
// All colours, type, spacing, dimensions, opacity, motion and density values
// used by the shell come from here, combined with the user's configuration
// by the Theme singleton. Components never hard-code these values.
//
// V4-compatible JavaScript (see docs/RESEARCH.md).

import { paletteForScheme, DEFAULT_SCHEME } from "./schemes.mjs";

export const PALETTE = paletteForScheme(DEFAULT_SCHEME);

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
  radius: 10, // shared soft controls; outer chord uses the larger panel radius
  border: 1,
  bracket: 10, // length of corner registration marks
  bracketWeight: 2,
  hairline: 1,
};

export const OPACITY = {
  backdrop: 0.64,
  backdropLowEffects: 1,
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
export function resolvePalette(overrides, scheme) {
  const out = paletteForScheme(scheme);
  const o = overrides || {};
  for (const k in o) {
    if (Object.prototype.hasOwnProperty.call(PALETTE, k) && isColor(o[k])) out[k] = o[k];
  }
  return out;
}

// OLED-1: opt-in derivation only; never mutate the resolved standard palette.
// Fills are opaque. idleDim is a surface opacity multiplier, not a timeout.
// Options may override decorationOpacity/idleDim with finite values in [0, 1].
export function oledPalette(palette, options) {
  const out = Object.assign({}, palette);
  const opts = options || {};
  out.obsidian = "#000000";
  out.background = out.obsidian;
  out.surface = oledTone(palette.surface, 0.55);
  out.surface2 = oledTone(palette.surface2, 0.55);
  // Black overrides must still leave two distinguishable material planes.
  if (luminance(out.surface) < luminance("#0d0d0d")) out.surface = "#0d0d0d";
  if (luminance(out.surface2) <= luminance(out.surface))
    out.surface2 = mixColor(out.surface, "#ffffff", 0.04);
  out.grid = mixColor(palette.grid, "#000000", 0.45);
  out.decorationOpacity = oledLevel(opts.decorationOpacity, 0.55);
  out.idleDim = oledLevel(opts.idleDim, 0.65);

  const backgrounds = [out.obsidian, out.surface, out.surface2];
  const roles = ["text", "textDim", "signal", "caution", "critical", "nominal"];
  for (let i = 0; i < roles.length; i++) {
    const role = roles[i];
    // Retain text brightness; reduce stationary accents while preserving hue.
    const candidate = mixColor(palette[role], "#000000", i < 2 ? 0 : 0.2);
    out[role] = readableOledColor(candidate, backgrounds);
  }
  return out;
}

function oledLevel(value, fallback) {
  return typeof value === "number" && isFinite(value) ? Math.max(0, Math.min(1, value)) : fallback;
}

function mixColor(color, target, amount) {
  // Qt palette overrides use #AARRGGBB; OLED roles deliberately drop alpha.
  const source = color.length === 9 ? color.slice(3) : color.slice(1);
  let out = "#";
  for (let i = 0; i < 6; i += 2) {
    const a = parseInt(source.slice(i, i + 2), 16);
    const b = parseInt(target.slice(i + 1, i + 3), 16);
    const channel = Math.round(a + (b - a) * amount).toString(16);
    out += channel.length === 1 ? "0" + channel : channel;
  }
  return out;
}

function oledTone(color, scale) {
  // Bound even a white custom fill to a dark plane so AA remains achievable.
  const tone = mixColor(color, "#000000", 1 - scale);
  const channels = [1, 3, 5].map(i => parseInt(tone.slice(i, i + 2), 16));
  const peak = Math.max.apply(null, channels);
  return peak > 48 ? mixColor(tone, "#000000", 1 - 48 / peak) : tone;
}

function readableOledColor(color, backgrounds) {
  function readable(candidate) {
    for (let i = 0; i < backgrounds.length; i++)
      if (contrast(candidate, backgrounds[i]) < MIN_TEXT_CONTRAST) return false;
    return true;
  }
  if (readable(color)) return color;
  // A bounded search also repairs low-contrast custom foreground overrides.
  let low = 0;
  let high = 1;
  for (let i = 0; i < 16; i++) {
    const mid = (low + high) / 2;
    if (readable(mixColor(color, "#ffffff", mid))) high = mid;
    else low = mid;
  }
  return mixColor(color, "#ffffff", high);
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
