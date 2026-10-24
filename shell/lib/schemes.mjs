// UI-015: the single colour source for the shell, instrument specimens and
// generated app themes. Keep this module compatible with Qt's V4 engine.
export const DEFAULT_SCHEME = "limb";

function specimen(id, name, description, link, field, plane, recess, rule, ink, dim, signal) {
  return { id: id, name: name, description: description, link: link, palette: {
    obsidian: field, surface: plane, surface2: recess, grid: rule,
    text: ink, textDim: dim, signal: signal,
    caution: "#ffd071", critical: "#ff9591", nominal: "#b3e6bd"
  } };
}

// Signal is interaction; link is PIYTI's application continuity edge. Status
// colours keep their meanings in every spectrum, including the neutral one.
export const SCHEMES = [
  specimen("limb", "Limb", "Mineral green / phosphor", "#81e6ed", "#0d1215", "#1b282b", "#25373a", "#3b5253", "#edf3f5", "#abc0bd", "#ceebac"),
  specimen("bathyal", "Bathyal", "Deep petrol / sea glass", "#a1c9ff", "#091619", "#122b30", "#1d383e", "#385b63", "#e1f4f1", "#acc8cc", "#80e1cf"),
  specimen("corona", "Corona", "Indigo field / ion blue", "#edbaff", "#101222", "#1e253c", "#2a3450", "#495a7b", "#edf0ff", "#b6c0df", "#a7bcff"),
  specimen("cinder", "Cinder", "Carbon brown / fired copper", "#f6e2b3", "#1a1210", "#30241f", "#40322b", "#685144", "#fff0e4", "#d4baaa", "#ffc08a"),
  specimen("ferrite", "Ferrite", "Oxide red / rose alloy", "#ffcc9c", "#1b1016", "#33212b", "#432e39", "#6b4859", "#ffeaf0", "#d7b4c3", "#ffa8ad"),
  specimen("iris", "Iris", "Violet shale / lilac light", "#a9d9f6", "#161121", "#292137", "#372e46", "#5c4b73", "#f3ecff", "#c8b8dc", "#d7b7ff"),
  specimen("argent", "Argent", "Graphite / silver inscription", "#bdced3", "#121415", "#25292b", "#34393b", "#545e62", "#f3f5f5", "#bec7ca", "#e2e6e8"),
  specimen("lichen", "Lichen", "Olive stone / living lime", "#8dd9b2", "#14170e", "#282e1e", "#353d29", "#576343", "#f0f3e3", "#c1c9a9", "#bddd84"),
  specimen("helios", "Helios", "Blue charcoal / solar gold", "#b9d8ed", "#11151c", "#232c35", "#303c46", "#506373", "#f5f2e7", "#c2c8cb", "#f4db83"),
  specimen("umbra", "Umbra", "Aubergine / spectral pink", "#c5b9ff", "#1a101d", "#302034", "#3f2c43", "#68476d", "#fcecff", "#d1b5d5", "#f5abe2"),
  specimen("vellum", "Vellum", "Warm slate / pale ceramic", "#c7d6ae", "#181612", "#2d2923", "#3c372f", "#625b4d", "#f7f1e6", "#cfc4b2", "#e9ccb0"),
  specimen("glacial", "Glacial", "Polar blue / ice edge", "#c1caff", "#0d1620", "#1b2b39", "#273b4b", "#425f73", "#e9f5ff", "#b1c9db", "#9be1f2")
];

export function schemeById(id) {
  for (let i = 0; i < SCHEMES.length; i++) if (SCHEMES[i].id === id) return SCHEMES[i];
  return SCHEMES[0];
}

export function paletteForScheme(id) {
  return Object.assign({}, schemeById(id).palette);
}
