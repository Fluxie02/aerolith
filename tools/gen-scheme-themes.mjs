#!/usr/bin/env node
// UI-015: app shapes stay in themes/, colours come from the shell catalog.
// This is a build-time Node tool, never imported by the Qt V4 runtime.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SCHEMES, DEFAULT_SCHEME } from "../shell/lib/schemes.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const TEMPLATES = path.join(ROOT, "themes");
const OUTPUT = path.join(TEMPLATES, "schemes");
const APPS = ["kitty", "alacritty", "foot", "btop", "gtk-3.0", "gtk-4.0",
    "qt", "hyprland", "firefox", "discord", "steam", "artcraft", "libreoffice"];
const CHECK = process.argv.includes("--check");
if (process.argv.some(arg => arg.startsWith("--") && arg !== "--check")) {
    throw new Error("Usage: node tools/gen-scheme-themes.mjs [--check]");
}

function walk(directory) {
    if (!fs.existsSync(directory)) return [];
    return fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))
        .flatMap(entry => entry.isDirectory() ? walk(path.join(directory, entry.name)) : [path.join(directory, entry.name)]);
}
function channels(hex) {
    return [1, 3, 5].map(index => Number.parseInt(hex.slice(index, index + 2), 16));
}
function rgb(values) {
    return "#" + values.map(value => Math.round(value).toString(16).padStart(2, "0")).join("");
}
function mix(first, second, amount) {
    const a = channels(first), b = channels(second);
    return rgb(a.map((value, index) => value + (b[index] - value) * amount));
}
function luminance(hex) {
    const c = channels(hex).map(value => {
        const s = value / 255;
        return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
    });
    return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722;
}
function contrast(first, second) {
    const a = luminance(first), b = luminance(second);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}
function readable(color, background, target = 4.5) {
    for (let step = 0; step <= 100; step++) {
        const candidate = mix(color, "#ffffff", step / 100);
        if (contrast(candidate, background) >= target) return candidate;
    }
    throw new Error("Cannot derive a readable foreground");
}
// ANSI blue/magenta/cyan retain their conventional hue semantics. Their
// saturation and lightness come from the chosen scheme's continuity colour.
function ansiHue(hue, reference, background) {
    const c = channels(reference).map(value => value / 255);
    const low = Math.min(...c), high = Math.max(...c), delta = high - low;
    const light = (high + low) / 2;
    const saturation = delta === 0 ? 0.12 : Math.min(0.72, Math.max(0.12, delta / (1 - Math.abs(2 * light - 1))));
    const chroma = (1 - Math.abs(2 * light - 1)) * saturation;
    const x = chroma * (1 - Math.abs((hue / 60) % 2 - 1));
    const m = light - chroma / 2;
    const sections = [[chroma, x, 0], [x, chroma, 0], [0, chroma, x], [0, x, chroma], [x, 0, chroma], [chroma, 0, x]];
    return readable(rgb(sections[Math.floor(hue / 60)].map(value => (value + m) * 255)), background);
}
function derive(scheme) {
    const p = scheme.palette;
    for (const [role, value] of Object.entries({ ...p, link: scheme.link })) {
        if (!/^#[0-9a-f]{6}$/i.test(value)) throw new Error(`${scheme.id}.${role}: expected an RGB hex colour`);
    }
    // Discord's raised/pressed layer and native hover fills must never inherit
    // grid: it is a decorative separator and can be too bright for dim/status
    // text. Native app widgets can place any semantic foreground on this fill.
    let pressed = p.surface2;
    const surfaceForegrounds = [p.text, p.textDim, p.signal, p.caution, p.critical, p.nominal, scheme.link];
    for (let step = 0; step <= 35; step++) {
        const candidate = mix(p.surface2, p.grid, step / 100);
        if (surfaceForegrounds.every(foreground => contrast(foreground, candidate) >= 4.5)) pressed = candidate;
    }
    const normal = [readable(mix(p.textDim, p.obsidian, 0.25), p.obsidian), p.critical,
        p.nominal, p.caution, ansiHue(215, scheme.link, p.obsidian),
        ansiHue(280, scheme.link, p.obsidian), ansiHue(180, scheme.link, p.obsidian), p.textDim];
    const bright = normal.map((value, index) => index === 0 ? p.textDim : index === 7 ? p.text : mix(value, p.text, 0.3));
    return { ...p, link: scheme.link, lower: mix(p.obsidian, p.surface, 0.7), pressed, ansi: { normal, bright } };
}
function colorMap(p, terminal) {
    const semantic = {
        "0d1215": p.obsidian, "1b282b": p.surface, "25373a": p.surface2, "3b5253": p.grid,
        "edf3f5": p.text, "abc0bd": p.textDim, "ceebac": p.signal, "ffd071": p.caution,
        "ff9591": p.critical, "b3e6bd": p.nominal, "81e6ed": p.link,
        "172124": p.lower, "304446": p.pressed,
        "a7c8ee": p.link, "d8b9e8": mix(p.link, p.signal, 0.5)
    };
    if (terminal) {
        const original = ["829691", "ff9591", "ceebac", "ffd071", "a7c8ee", "d8b9e8", "b3e6bd", "abc0bd"];
        const originalBright = ["abc0bd", "ffb3af", "def3c7", "ffe0a0", "c1dbfa", "ead0f5", "d0f4e0", "edf3f5"];
        // Normal green is the stable nominal role. Selection and focus still
        // use signal and must not be recoloured as an ANSI syntax token.
        original.forEach((value, index) => { if (index !== 2) semantic[value] = p.ansi.normal[index]; });
        originalBright.forEach((value, index) => { semantic[value] = p.ansi.bright[index]; });
    }
    return semantic;
}
function replaceColors(source, map, filename) {
    // Exact six-digit colours, optionally with CSS trailing or Qt leading
    // alpha. No replacement cascade: each token is transformed once.
    let result = source.replace(/#([0-9a-f]{8}|[0-9a-f]{6})\b/gi, (token, digits) => {
        const value = digits.toLowerCase();
        if (value === "00000000") return token; // Explicit transparent shadow.
        if (value.length === 6 && map[value]) return map[value];
        if (value.length === 8 && filename === "qt/aerolith.conf" && map[value.slice(2)]) return "#" + value.slice(0, 2) + map[value.slice(2)].slice(1);
        if (value.length === 8 && map[value.slice(0, 6)]) return map[value.slice(0, 6)] + value.slice(6);
        throw new Error(`${filename}: ${token} has no semantic colour mapping`);
    });
    result = result.replace(/\brgb\(([0-9a-f]{6})\)/gi, (token, digits) => {
        if (!map[digits.toLowerCase()]) throw new Error(`${filename}: ${token} has no semantic colour mapping`);
        return "rgb(" + map[digits.toLowerCase()].slice(1) + ")";
    });
    if (filename.startsWith("foot/")) {
        result = result.replace(/(?<![\w#])([0-9a-f]{6})\b/gi, (token, digits) => {
            if (!map[digits.toLowerCase()]) throw new Error(`${filename}: ${token} has no semantic colour mapping`);
            return map[digits.toLowerCase()].slice(1);
        });
    }
    return result;
}
function adaptLibreOffice(source, scheme, p, filename) {
    const direction = filename.endsWith("piyti.xcu") ? "PIYTI" : "THEARS";
    const accent = direction === "PIYTI" ? p.link : p.signal;
    const appRoles = {
        AppBackground: p.obsidian, WindowColor: direction === "PIYTI" ? p.obsidian : p.surface,
        WindowTextColor: p.text, BaseColor: p.obsidian, ButtonColor: p.surface2,
        ButtonTextColor: p.text, AccentColor: accent, DisabledColor: p.surface,
        DisabledTextColor: p.textDim, ShadowColor: p.obsidian, SeparatorColor: p.grid,
        FaceColor: p.surface, ActiveColor: accent, ActiveTextColor: p.obsidian,
        ActiveBorderColor: accent, FieldColor: p.obsidian, MenuBarColor: p.obsidian,
        MenuBarTextColor: p.text, MenuBarHighlightColor: accent, MenuBarHighlightTextColor: p.obsidian,
        MenuColor: p.surface, MenuTextColor: p.text, MenuHighlightColor: accent,
        MenuHighlightTextColor: p.obsidian, InactiveColor: p.surface2,
        InactiveTextColor: p.textDim, InactiveBorderColor: p.grid
    };
    return source.replace(/<node oor:name="([^"]+)">\s*<prop oor:name="Color"><value>(\d+)<\/value><\/prop>/g, (token, role) => {
        return appRoles[role] ? token.replace(/<value>\d+<\/value>/, `<value>${Number.parseInt(appRoles[role].slice(1), 16)}</value>`) : token;
    }).replace(`oor:name="AEROLITH ${direction}"`, `oor:name="AEROLITH ${scheme.name} ${direction}"`);
}
function render(template, source, scheme, p) {
    const terminal = /^(kitty|alacritty|foot)\//.test(template);
    let output = replaceColors(source, colorMap(p, terminal), template);
    output = output.replace(/AEROLITH \/ Limb/g, `AEROLITH / ${scheme.name}`);
    if (terminal) {
        // The shared original phosphor colour serves both interaction and
        // ANSI green, so resolve the actual ANSI declarations by role.
        if (template.startsWith("kitty/")) output = output.replace(/^color2 .+$/m, `color2 ${p.ansi.normal[2]}`);
        if (template.startsWith("alacritty/")) output = output.replace(/^green = .+$/m, `green = "${p.ansi.normal[2]}"`);
        if (template.startsWith("foot/")) output = output.replace(/^regular2=.+$/m, `regular2=${p.ansi.normal[2].slice(1)}`);
    }
    if (template.startsWith("gtk-")) output = output.replace(/background-color: @aerolith_grid;/g, `background-color: ${p.pressed};`);
    if (template === "qt/aerolith.conf") {
        output = output.replace(/^(active_colors|inactive_colors|disabled_colors)=(.+)$/gm, (token, key, values) => {
            const roles = values.split(", ");
            roles[2] = "#ff" + p.pressed.slice(1); // QPalette::Light is the QSS hover fill.
            return key + "=" + roles.join(", ");
        });
    }
    if (template.startsWith("firefox/")) {
        output = output.replace(/--toolbarbutton-active-background: var\(--aero-grid\)/g, `--toolbarbutton-active-background: ${p.pressed}`);
        if (template.endsWith("manifest.json")) {
            const manifest = JSON.parse(output);
            const direction = template.split("/")[1].toUpperCase();
            manifest.name = `AEROLITH — ${scheme.name} / ${direction}`;
            manifest.description = `${scheme.description}. ${direction} application appearance.`;
            manifest.browser_specific_settings.gecko.id = `${scheme.id}-${direction.toLowerCase()}-theme@aerolith.local`;
            manifest.theme.colors.button_background_active = p.pressed;
            output = JSON.stringify(manifest, null, 2) + "\n";
        }
    }
    if (template.startsWith("discord/")) {
        output = output.replace(/@name AEROLITH (PIYTI|THEARS)/, `@name AEROLITH ${scheme.name} $1`);
        output = output.replace(/@description .+/, `@description ${scheme.description}. ${template.includes("piyti") ? "PIYTI" : "THEARS"} communication bay. Requires Vencord; no remote assets.`);
    }
    if (template.startsWith("steam/") && template.endsWith("skin.json")) {
        const skin = JSON.parse(output);
        skin.name = `AEROLITH ${scheme.name} ${template.split("/")[1].toUpperCase()}`;
        skin.description = `${scheme.description}. ${template.split("/")[1].toUpperCase()} application chrome.`;
        output = JSON.stringify(skin, null, 2) + "\n";
    }
    if (template.startsWith("libreoffice/")) {
        if (template.endsWith(".xcu")) output = adaptLibreOffice(source, scheme, p, template);
        if (template.endsWith("description.xml")) output = output
            .replace("org.aerolith.appearance.thears-piyti", `org.aerolith.appearance.schemes.${scheme.id}`)
            .replace("AEROLITH — THEARS and PIYTI", `AEROLITH ${scheme.name} — THEARS and PIYTI`);
    }
    return output;
}
function contrastEvidence(scheme, p) {
    const pairs = [];
    function pair(name, foreground, background, minimum = 4.5) {
        const ratio = contrast(foreground, background);
        pairs.push({ name, foreground, background, ratio: Number(ratio.toFixed(4)), minimum, pass: ratio >= minimum });
        if (ratio < minimum) throw new Error(`${scheme.id}: ${name} contrast ${ratio.toFixed(3)} < ${minimum}`);
    }
    for (const background of ["obsidian", "surface", "surface2", "pressed", "lower"]) {
        pair(`text / ${background}`, p.text, p[background]);
        pair(`textDim / ${background}`, p.textDim, p[background]);
    }
    for (const role of ["signal", "caution", "critical", "nominal", "link"]) {
        for (const background of ["obsidian", "surface", "surface2", "pressed", "lower"]) pair(`${role} / ${background}`, p[role], p[background]);
        pair(`selection ink / ${role}`, p.obsidian, p[role]);
        pair(`focus / ${role}`, p.obsidian, p[role], 3);
    }
    for (let index = 0; index < 8; index++) {
        pair(`ANSI normal ${index} / terminal`, p.ansi.normal[index], p.obsidian);
        pair(`ANSI bright ${index} / terminal`, p.ansi.bright[index], p.obsidian);
    }
    // PhotoCraft's debug Studio theme uses a 14% accent selection tint and
    // light text; primary actions use a separate solid signal + dark ink.
    for (const direction of ["piyti", "thears"]) {
        const accent = direction === "piyti" ? p.link : p.signal;
        pair(`ArtCraft ${direction} text / tinted selection`, p.text, mix(p.surface, accent, 0x24 / 255));
        pair(`ArtCraft ${direction} textDim / tinted selection`, p.textDim, mix(p.surface, accent, 0x24 / 255));
    }
    return { id: scheme.id, name: scheme.name, minimumTextRatio: Math.min(...pairs.filter(entry => entry.minimum === 4.5).map(entry => entry.ratio)), pairs };
}

const templates = APPS.flatMap(app => walk(path.join(TEMPLATES, app)))
    .filter(filename => !filename.endsWith(".md"))
    .map(filename => ({ filename: path.relative(TEMPLATES, filename).split(path.sep).join("/"), source: fs.readFileSync(filename, "utf8") }));
const expected = new Map();
const evidence = [];
const ids = new Set();
for (const scheme of SCHEMES) {
    if (!/^[a-z][a-z0-9-]*$/.test(scheme.id) || ids.has(scheme.id)) throw new Error(`Invalid/duplicate scheme id: ${scheme.id}`);
    ids.add(scheme.id);
    const p = derive(scheme);
    evidence.push(contrastEvidence(scheme, p));
    expected.set(`${scheme.id}/palette.json`, JSON.stringify({ id: scheme.id, name: scheme.name, source: "shell/lib/schemes.mjs", ...p }, null, 2) + "\n");
    for (const template of templates) {
        const contents = render(template.filename, template.source, scheme, p);
        if (template.filename.endsWith(".json")) JSON.parse(contents);
        expected.set(`${scheme.id}/${template.filename}`, contents);
    }
}
expected.set("index.json", JSON.stringify({ version: 1, generatedBy: "tools/gen-scheme-themes.mjs", source: "shell/lib/schemes.mjs", defaultScheme: DEFAULT_SCHEME,
    schemes: SCHEMES.map(scheme => ({ id: scheme.id, name: scheme.name, description: scheme.description, directory: scheme.id,
        directions: ["piyti", "thears"] })), templates: templates.map(template => template.filename) }, null, 2) + "\n");
expected.set("contrast.json", JSON.stringify({ method: "WCAG 2.x sRGB relative luminance, opaque pairs and composited Studio selection tint", textMinimum: 4.5, focusMinimum: 3, schemes: evidence }, null, 2) + "\n");

const differences = [];
const unexpected = [];
for (const [filename, contents] of expected) {
    const output = path.join(OUTPUT, filename);
    if (fs.existsSync(output) && fs.readFileSync(output, "utf8") === contents) continue;
    differences.push(filename);
    if (!CHECK) {
        fs.mkdirSync(path.dirname(output), { recursive: true });
        fs.writeFileSync(output, contents);
    }
}
for (const filename of walk(OUTPUT)) {
    const relative = path.relative(OUTPUT, filename).split(path.sep).join("/");
    if (!expected.has(relative)) unexpected.push(`unexpected generated file: ${relative}`);
}
if (unexpected.length || (CHECK && differences.length)) {
    const failures = differences.concat(unexpected);
    console.error(`Generated scheme themes differ (${failures.length}):\n${failures.join("\n")}`);
    process.exitCode = 1;
} else {
    console.log(`${CHECK ? "Verified" : "Generated"} ${expected.size} files: ${SCHEMES.length} schemes × ${templates.length} app templates + palettes and catalog/contrast evidence.`);
    console.log(`${evidence.reduce((count, scheme) => count + scheme.pairs.length, 0)} contrast pairs passed; minimum ${Math.min(...evidence.map(scheme => scheme.minimumTextRatio)).toFixed(3)}:1.`);
}
