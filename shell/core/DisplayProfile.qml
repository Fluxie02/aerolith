import QtQuick
import qs.core
import qs.services
import "../lib/tokens.mjs" as Tokens

// One value object at each surface boundary; children receive it explicitly.
QtObject {
    property string output: ""
    property string profile: Displays.settings(output).profile
    readonly property bool blackBackground: !!(Config.display.outputs[output] && Config.display.outputs[output].blackBackground)
    // Only persistent Ground/Strip decoration participates in seat idle.
    property bool persistent: false
    readonly property var state: Tokens.profileState(profile, Config.display.oled, persistent && Idle.idle)
    readonly property bool idleAnimationHeld: profile === "oled" && Idle.idle
    readonly property bool idleDimmed: state.idleDimmed
    readonly property bool hideContent: state.hideContent
    readonly property real opacity: state.opacity

    readonly property var palette: profile === "oled" ? Tokens.oledPalette(Theme.palette, { appLink: String(Theme.appLink) }) : Tokens.backgroundPalette(Theme.palette, blackBackground)
    readonly property color background: palette.obsidian
    readonly property color bg: background
    readonly property color surface: profile === "oled" ? palette.surface : Theme.surface
    readonly property color surface2: profile === "oled" ? palette.surface2 : Theme.surface2
    readonly property color grid: profile === "oled" ? palette.grid : Theme.grid
    // Neutral multipliers preserve current standard-profile rendering.
    readonly property real decorationOpacity: state.decorationOpacity
    readonly property real idleDim: profile === "oled" ? Config.display.oled.idleDimLevel : 1
    readonly property color text: profile === "oled" ? palette.text : Theme.text
    readonly property color textDim: profile === "oled" ? palette.textDim : Theme.textDim
    readonly property color signal: profile === "oled" ? palette.signal : Theme.signal
    readonly property color caution: profile === "oled" ? palette.caution : Theme.caution
    readonly property color critical: profile === "oled" ? palette.critical : Theme.critical
    readonly property color appLink: profile === "oled" ? (palette.appLink || Theme.appLink) : Theme.appLink
    readonly property color nominal: profile === "oled" ? palette.nominal : Theme.nominal
}
