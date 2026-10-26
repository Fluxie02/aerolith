import QtQuick
import qs.core
QtObject {
    property int concept: 0
    readonly property bool keel: concept === 0
    readonly property bool limb: concept === 1
    readonly property bool fault: concept === 2
    readonly property color bg: keel ? "#090f16" : limb ? "#0d1215" : "#111215"
    readonly property color surface: keel ? "#15232f" : limb ? "#1b282b" : "#27272c"
    readonly property color inset: keel ? "#1d3543" : limb ? "#25373a" : "#333137"
    readonly property color line: keel ? "#354c5b" : limb ? "#3b5253" : "#535057"
    readonly property color dim: keel ? "#9aafb9" : limb ? "#abc0bd" : "#beb9ba"
    readonly property color text: "#edf3f5"
    readonly property color accent: keel ? "#87dfed" : limb ? "#ceebac" : "#ffc080"
    readonly property color caution: "#ffd071"
    readonly property color error: "#ff9591"
    readonly property color nominal: "#b3e6bd"
    readonly property string mono: Config.theme.fontMono
    readonly property string sans: Config.theme.fontSans === "Inter" ? (fault ? "Noto Sans" : "Inter Display") : Config.theme.fontSans
    readonly property bool travel: Theme.animate && !Theme.lowEffects && Config.theme.motion === "full"
    readonly property bool animate: Theme.animate && !Theme.lowEffects
    readonly property int enter: travel ? Theme.normal : animate ? Theme.fast : 0
    readonly property int ease: Easing.OutCubic
    readonly property real unit: Theme.scale * (Config.theme.density === "compact" ? 0.92 : Config.theme.density === "comfortable" ? 1.08 : 1)
    function px(n) { return Math.round(n * unit); }
    function alpha(c, a) { return Theme.alpha(c, Theme.lowEffects ? 1 : a); }
}
