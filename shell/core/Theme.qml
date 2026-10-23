pragma Singleton

import QtQuick
import Quickshell
import "../lib/tokens.mjs" as Tokens

// Limb's mineral planes and phosphor inscriptions, resolved against config.
// Every visual value used by components comes from here.
Singleton {
    id: root

    readonly property var cfg: Config.theme
    readonly property var palette: Tokens.resolvePalette(cfg.palette)
    readonly property var density: Tokens.densityTokens(cfg.density)
    readonly property var motionSet: Tokens.motionTokens(cfg.motion)
    readonly property real scale: cfg.uiScale

    // Both intensities share Limb geometry. Config changes apply to live bindings.
    readonly property string intensity: cfg.intensity === "insane" ? "insane" : "saturated"
    readonly property bool insane: intensity === "insane"
    readonly property int variantLevel: insane ? 3 : 2
    readonly property string variantName: insane ? "Insane" : "Saturated"
    // UI-012 visual seam. Claude will bind this to an approved setting; until
    // then THEARS is the shipped composition, PIYTI is a review build choice.
    property string applicationDirection: "thears"
    readonly property bool integratedApps: applicationDirection === "piyti"
    readonly property string applicationName: integratedApps ? "PIYTI" : "THEARS"
    readonly property color appLink: integratedApps ? "#81e6ed" : signal
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
        if (travel) { bootProgress = 0; ignition.restart(); }
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
    function px(n) {
        return Math.round(n * scale);
    }
    readonly property real unit: scale * (cfg.density === "compact" ? 0.92 : cfg.density === "comfortable" ? 1.08 : 1)
    function du(n) {
        return Math.round(n * unit);
    }
    readonly property int fontXs: px(density.fontXs)
    readonly property int fontSm: px(density.fontSm)
    readonly property int fontMd: px(density.fontMd)
    readonly property int fontLg: px(density.fontLg)
    readonly property int fontXl: px(density.fontXl)
    readonly property int titleSize: du(36)
    readonly property int inputSize: du(28)
    readonly property int resultSize: du(16)
    readonly property int resultHeight: du(68)
    readonly property int headerHeight: du(56)
    readonly property int contentInset: du(28)
    readonly property int inputHeight: du(76)

    // Space and shape
    readonly property int stripHeight: px(density.stripHeight)
    readonly property int rowHeight: px(density.rowHeight)
    readonly property int pad: px(density.pad)
    readonly property int gap: px(density.gap)
    readonly property int radius: du(Tokens.SHAPE.radius)
    readonly property int panelRadius: du(20)
    readonly property int border: Tokens.SHAPE.border
    readonly property int bracket: px(Tokens.SHAPE.bracket)
    readonly property int bracketWeight: Tokens.SHAPE.bracketWeight

    // Opacity and effects
    readonly property bool lowEffects: cfg.lowEffects
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

    function stateColor(state) {
        return Tokens.stateColor(palette, state);
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
