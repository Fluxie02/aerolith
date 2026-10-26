import QtQuick
import qs.core
QtObject {
    property int concept: 0
    readonly property bool observatory: concept === 0
    readonly property bool architecture: concept === 1
    readonly property bool index: concept === 2
    readonly property var overrides: Config.theme.palette || ({})
    function role(key, fallback) { return overrides[key] || fallback; }
    readonly property color bg: role("obsidian", observatory ? "#111c28" : architecture ? "#d5cfc2" : "#dce4d9")
    readonly property color surface: role("surface", observatory ? "#192735" : architecture ? "#f2eee4" : "#f0f2e8")
    readonly property color inset: role("surface2", observatory ? "#203243" : architecture ? "#e6dfd1" : "#e3e9dd")
    readonly property color ink: role("text", observatory ? "#f0eee4" : "#202a25")
    readonly property color dim: role("textDim", observatory ? "#b6c1c9" : "#526056")
    readonly property color line: role("grid", observatory ? "#455664" : "#afb9a9")
    readonly property color accent: role("signal", observatory ? "#e6bb77" : architecture ? "#963b29" : "#943f32")
    readonly property color warning: role("caution", observatory ? "#f6d085" : "#77530d")
    readonly property color error: role("critical", observatory ? "#ffa6a0" : "#a52b28")
    readonly property color success: role("nominal", observatory ? "#a8d5af" : "#286140")
    // Decorative inks are fixed inverse material, never assigned semantic meaning.
    readonly property color margin: "#202b26"
    readonly property color inverse: "#f0f2e8"
    readonly property color inverseDim: "#b8c4b8"
    readonly property real unit: Config.theme.uiScale
    readonly property int gap: px(Config.theme.density === "compact" ? 12 : Config.theme.density === "comfortable" ? 24 : 18)
    readonly property int row: px(Config.theme.density === "compact" ? 46 : Config.theme.density === "comfortable" ? 66 : 56)
    readonly property int body: px(Config.theme.density === "compact" ? 14 : Config.theme.density === "comfortable" ? 17 : 15)
    readonly property int small: px(12)
    readonly property int title: px(48)
    readonly property int fast: Theme.fast
    readonly property int normal: Theme.normal
    readonly property bool animate: Theme.animate && !Theme.lowEffects
    readonly property bool travel: animate && Config.theme.motion === "full"
    function px(n) { return Math.round(n * unit); }
}
