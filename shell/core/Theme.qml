pragma Singleton

import QtQuick
import Quickshell
import "../lib/tokens.mjs" as Tokens

// The AEROLITH Instrument System, resolved against the user's configuration.
// Every visual value used by components comes from here.
Singleton {
    id: root

    readonly property var cfg: Config.theme
    readonly property var palette: Tokens.resolvePalette(cfg.palette)
    readonly property var density: Tokens.densityTokens(cfg.density)
    readonly property var motionSet: Tokens.motionTokens(cfg.motion)
    readonly property real scale: cfg.uiScale

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
    readonly property string mono: cfg.fontMono
    function px(n) {
        return Math.round(n * scale);
    }
    readonly property int fontXs: px(density.fontXs)
    readonly property int fontSm: px(density.fontSm)
    readonly property int fontMd: px(density.fontMd)
    readonly property int fontLg: px(density.fontLg)
    readonly property int fontXl: px(density.fontXl)

    // Space and shape
    readonly property int stripHeight: px(density.stripHeight)
    readonly property int rowHeight: px(density.rowHeight)
    readonly property int pad: px(density.pad)
    readonly property int gap: px(density.gap)
    readonly property int radius: Tokens.SHAPE.radius
    readonly property int border: Tokens.SHAPE.border
    readonly property int bracket: px(Tokens.SHAPE.bracket)
    readonly property int bracketWeight: Tokens.SHAPE.bracketWeight

    // Opacity and effects
    readonly property bool lowEffects: cfg.lowEffects
    readonly property real backdropOpacity: lowEffects ? Tokens.OPACITY.backdropLowEffects : Tokens.OPACITY.backdrop
    readonly property real disabledOpacity: Tokens.OPACITY.disabled
    readonly property real gridMinorOpacity: Tokens.OPACITY.gridMinor

    // Motion (ms). Components must use these, never literals.
    readonly property int fast: motionSet.fast
    readonly property int normal: motionSet.normal
    readonly property int slow: motionSet.slow
    readonly property bool animate: cfg.motion !== "off"

    function stateColor(state) {
        return Tokens.stateColor(palette, state);
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
