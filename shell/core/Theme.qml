pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import "../lib/tokens.mjs" as Tokens
import "../lib/geometry.mjs" as Geometry
import "../lib/schemes.mjs" as Schemes
import "../lib/ambient.mjs" as Ambient
import "../lib/hyprdispatch.mjs" as HD

// Limb's mineral planes and phosphor inscriptions, resolved against config.
// Every visual value used by components comes from here.
Singleton {
    id: root

    readonly property var cfg: Config.theme
    readonly property string scheme: Schemes.schemeById(cfg.scheme).id
    readonly property var specimen: Schemes.schemeById(scheme)
    readonly property var palette: Tokens.resolvePalette(cfg.palette, scheme)
    readonly property var density: Tokens.densityTokens(cfg.density)
    readonly property var typography: Tokens.textTokens(cfg.density, cfg.textSize, cfg.uiScale)
    readonly property real textScale: typography.factor
    readonly property var motionSet: Tokens.motionTokens(cfg.motion)
    readonly property real scale: cfg.uiScale

    // Both intensities share Limb geometry. Config changes apply to live bindings.
    readonly property string intensity: cfg.intensity === "insane" ? "insane" : "saturated"
    readonly property bool insane: intensity === "insane"
    readonly property int variantLevel: insane ? 3 : 2
    readonly property string variantName: insane ? "Insane" : "Saturated"
    // Installation-only seam: Claude wires the one-time THEARS/PIYTI choice.
    // PIYTI is the base; THEARS remains available through the same visual seam.
    property string applicationDirection: Config.applicationDirection
    readonly property bool integratedApps: applicationDirection === "piyti"
    readonly property string applicationName: integratedApps ? "PIYTI" : "THEARS"
    readonly property color appLink: integratedApps ? specimen.link : signal
    // Process lifetime latch survives hidden/recreated views. Freeze the selected
    // startup duration so changing intensity during assembly cannot retime it.
    property bool bootPlayed: false
    property bool bootRequested: false
    property bool bootInsane: false
    property real bootProgress: 1
    readonly property int ignitionDuration: slow * (bootInsane ? 10 : 8)
    function ignite() {
        bootRequested = true;
        if (bootPlayed || !Config.loaded) return;
        bootPlayed = true;
        bootInsane = insane;
        if (travel && ambient) { bootProgress = 0; ignition.restart(); }
    }
    Connections {
        target: Config
        function onLoadedChanged() {
            if (Config.loaded && root.bootRequested) root.ignite();
        }
    }
    onTravelChanged: if (!travel) { ignition.stop(); bootProgress = 1; }
    NumberAnimation {
        id: ignition; target: root; property: "bootProgress"
        to: 1; duration: root.ignitionDuration; easing.type: Easing.Linear
    }

    // Colour roles
    readonly property color bg: palette.obsidian
    readonly property color surface: palette.surface
    readonly property color surface2: palette.surface2
    readonly property color grid: palette.grid
    readonly property color text: palette.text
    readonly property color textDim: palette.textDim
    readonly property color signal: palette.signal
    readonly property color caution: palette.caution
    readonly property color critical: palette.critical
    readonly property color nominal: palette.nominal

    // Type
    readonly property string sans: cfg.fontSans
    readonly property string displaySans: cfg.fontSans === "Inter" ? "Inter Display" : cfg.fontSans
    readonly property string mono: cfg.fontMono
    readonly property var installedFontFamilies: Qt.fontFamilies()
    readonly property string canvasMono: Ambient.canvasFamily(mono, installedFontFamilies)
    function px(n) {
        return Math.round(n * scale);
    }
    readonly property real unit: scale * (cfg.density === "compact" ? 0.92 : cfg.density === "comfortable" ? 1.08 : 1)
    function textDu(n) { return Math.round(n * unit * textScale); }
    function du(n) {
        return Math.round(n * unit);
    }
    // All surfaces classify the full output, with that output's actual strip.
    function stripReservation(outputName) {
        return Displays.settings(outputName).strip ? stripHeight : 0;
    }
    function layoutFor(width, height, outputName) {
        return Geometry.workArea(width, height, scale, stripReservation(outputName));
    }
    function groundGeometry(width, height, outputName) {
        return Geometry.ground(width, height, unit, stripReservation(outputName),
            Config.strip.edge === "bottom", scale, gap, textScale);
    }
    readonly property int fontXs: typography.fontXs
    readonly property int fontSm: typography.fontSm
    readonly property int fontMd: typography.fontMd
    readonly property int fontLg: typography.fontLg
    readonly property int fontXl: typography.fontXl
    readonly property int titleSize: typography.titleSize
    readonly property int inputSize: typography.inputSize
    readonly property int resultSize: typography.resultSize
    readonly property int resultHeight: typography.resultHeight
    readonly property int headerHeight: typography.headerHeight
    readonly property int contentInset: du(28)
    readonly property int inputHeight: typography.inputHeight

    // Space and shape
    readonly property int stripHeight: typography.stripHeight
    readonly property int rowHeight: typography.rowHeight
    readonly property int pad: px(density.pad)
    readonly property int gap: px(density.gap)
    readonly property int radius: du(Tokens.SHAPE.radius)
    readonly property int panelRadius: du(20)
    readonly property int border: Tokens.SHAPE.border
    readonly property int bracket: px(Tokens.SHAPE.bracket)
    readonly property int bracketWeight: Tokens.SHAPE.bracketWeight

    // Opacity and effects
    readonly property bool lowEffects: cfg.lowEffects
    // E02: one inexpensive material pass. Opus owns the future config seam;
    // 0 releases ShaderEffects and leaves the native material in place.
    property int shaderQuality: 1
    readonly property real backdropOpacity: lowEffects ? Tokens.OPACITY.backdropLowEffects : Tokens.OPACITY.backdrop
    readonly property real disabledOpacity: Tokens.OPACITY.disabled
    readonly property real gridMinorOpacity: Tokens.OPACITY.gridMinor
    readonly property real panelOpacity: lowEffects ? 1 : Tokens.OPACITY.panel

    // Motion (ms). Components must use these, never literals.
    readonly property int fast: lowEffects ? 0 : motionSet.fast
    readonly property int normal: lowEffects ? 0 : motionSet.normal
    readonly property int slow: lowEffects ? 0 : motionSet.slow
    readonly property bool animate: cfg.motion !== "off" && !lowEffects
    readonly property bool travel: animate && cfg.motion === "full"
    // Hz is output metadata, never an animation clock or a guessed 60 Hz.
    // The monitor snapshot already maintained by Quickshell is event-driven.
    readonly property real refreshRate: {
        if (!Ui.screen || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return NaN;
        const monitors = Hyprland.monitors.values;
        for (let i = 0; i < monitors.length; i++) {
            const monitor = monitors[i];
            if (monitor.name !== Ui.screenName) continue;
            const ipc = monitor.lastIpcObject;
            const rate = ipc ? ipc.refreshRate : null;
            return typeof rate === "number" && isFinite(rate) && rate > 0 ? rate : NaN;
        }
        return NaN;
    }
    // UI-013: the only ambient-motion switch. Claude's fullscreen lifecycle
    // hook sets ambientSuspended before unmapping/unloading visual surfaces.
    property bool ambientSuspended: false
    // Coverage and fullscreen hold belong to the surface's output. The
    // compatibility properties below continue to describe the primary.
    readonly property var coveredOutputs: {
        const covered = {};
        const outputs = Displays.outputs;
        const monitors = Compositor.available ? Hyprland.monitors.values : [];
        const windows = Compositor.available ? Compositor.windows().map(w => {
            const ipc = w.toplevel ? w.toplevel.lastIpcObject : null;
            // Qt exposes JSON lists as array-like values, not always JS Arrays.
            // Normalise geometry before passing it to the pure coverage test.
            return { workspaceId: w.workspaceId,
                at: ipc && ipc.at ? [ipc.at[0], ipc.at[1]] : w.at,
                size: ipc && ipc.size ? [ipc.size[0], ipc.size[1]] : w.size,
                floating: w.floating, ipc: ipc };
        }) : [];
        for (let k = 0; k < outputs.length; k++) {
            const output = outputs[k];
            let monitor = null;
            for (let i = 0; i < monitors.length; i++)
                if (monitors[i].name === output.monitorName) monitor = monitors[i];
            if (!monitor) continue;
            const ipc = monitor.lastIpcObject || {};
            if (ipc.specialWorkspace && ipc.specialWorkspace.id < 0) continue;
            const workspace = monitor.activeWorkspace ? monitor.activeWorkspace.id
                : ipc.activeWorkspace ? ipc.activeWorkspace.id : -1;
            const size = HD.logicalMonitorSize(monitor.width, monitor.height, monitor.scale, ipc.transform || 0);
            if (!size) continue;
            const lane = output.strip ? Math.min(stripHeight, size.height) : 0;
            const geometry = { x: monitor.x,
                y: monitor.y + (Config.strip.edge === "top" ? lane : 0),
                width: size.width, height: size.height - lane };
            covered[output.name] = Ambient.desktopCovered(windows, geometry, workspace, du(40));
        }
        return covered;
    }
    function desktopCoveredFor(name) { return coveredOutputs[name] === true; }
    function ambientHeldFor(name) {
        const deckHere = Ui.deckOpen && Ui.overlayScreen && Ui.overlayScreen.name === name;
        return ShellState.heldFor(name) || (desktopCoveredFor(name) && !deckHere);
    }
    function ambientFor(name) { return animate && !lowEffects && !ambientHeldFor(name); }
    readonly property bool desktopCovered: desktopCoveredFor(Ui.screenName)
    readonly property bool ambientHeld: ambientSuspended || ambientHeldFor(Ui.screenName)
    readonly property bool ambient: animate && !lowEffects && !ambientHeld
    onAmbientChanged: if (!ambient) { ignition.stop(); bootProgress = 1; }
    readonly property bool ambientReduced: cfg.motion === "reduced"
    readonly property int carrierDuration: ambientReduced ? slow * 10 : normal * 3
    // Keep the same wall-time stroke at full output cadence, but amortize its
    // repaint cost over a longer rest on high-Hz outputs (UI-013 CPU budget).
    // Unknown outputs retain the established cadence; there is no FPS cap.
    readonly property real ambientCadenceScale: isFinite(refreshRate) ? Math.max(1, refreshRate / 60) : 1
    readonly property int carrierRest: Math.round((slow * (ambientReduced ? 180 : insane ? 16 : 32) + carrierDuration * 2) * ambientCadenceScale - carrierDuration * 2)

    function stateColor(state) {
        return Tokens.stateColor(palette, state);
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
