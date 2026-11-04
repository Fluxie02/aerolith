import QtQuick
import qs.core
import "../lib/tokens.mjs" as Tokens

// One lightweight value object per surface. OLED-2 supplies the output's
// configured profile; this object does not discover outputs or own services.
QtObject {
    property string output: ""
    property string profile: "standard" // standard | oled

    readonly property var palette: profile === "oled" ? Tokens.oledPalette(Theme.palette) : Theme.palette
    readonly property color background: profile === "oled" ? palette.obsidian : Theme.bg
    readonly property color bg: background
    readonly property color surface: profile === "oled" ? palette.surface : Theme.surface
    readonly property color surface2: profile === "oled" ? palette.surface2 : Theme.surface2
    readonly property color grid: profile === "oled" ? palette.grid : Theme.grid
    // Neutral multipliers preserve current standard-profile rendering.
    readonly property real decorationOpacity: profile === "oled" ? palette.decorationOpacity : 1
    readonly property real idleDim: profile === "oled" ? palette.idleDim : 1
    readonly property color text: profile === "oled" ? palette.text : Theme.text
    readonly property color textDim: profile === "oled" ? palette.textDim : Theme.textDim
    readonly property color signal: profile === "oled" ? palette.signal : Theme.signal
    readonly property color caution: profile === "oled" ? palette.caution : Theme.caution
    readonly property color critical: profile === "oled" ? palette.critical : Theme.critical
    readonly property color nominal: profile === "oled" ? palette.nominal : Theme.nominal
}
