import QtQuick
import qs.core

// E02 material contract. Own no clock, texture, layer or independent surface.
// Instantiate only below Ground/Strip/Deck/Notices, which ShellState destroys.
// The Loader also releases the effect during the pre-teardown ambient hold.
Item {
    id: material
    required property string shader
    property vector4d parameters: Qt.vector4d(0, 0, 0, 0)
    property color accent: Theme.integratedApps ? Theme.appLink : Theme.signal
    property real strength: 1
    readonly property real outputScale: Screen.devicePixelRatio
    readonly property bool supported: GraphicsInfo.shaderType === GraphicsInfo.RhiShader
        && GraphicsInfo.api !== GraphicsInfo.Null && GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property bool available: supported && !Theme.lowEffects && Theme.shaderQuality > 0 && !Theme.ambientSuspended
        && visible && width > 0 && height > 0 && Window.window !== null && Window.window.visible
    // Loader.Ready only means the QML object exists. Keep the native faces
    // until the actual material compiles, including a missing/broken package.
    readonly property bool active: effect.item !== null && effect.item.status === ShaderEffect.Compiled

    Loader {
        id: effect
        anchors.fill: parent
        active: material.available
        sourceComponent: ShaderEffect {
            // std140 order is shared by every shader through material.glsl.
            readonly property color bg: Theme.bg
            readonly property color surface: Theme.surface
            readonly property color surface2: Theme.surface2
            readonly property color grid: Theme.grid
            readonly property color signal: Theme.signal
            readonly property color appLink: Theme.appLink
            readonly property color text: Theme.text
            readonly property color textDim: Theme.textDim
            readonly property color caution: Theme.caution
            readonly property color critical: Theme.critical
            readonly property color nominal: Theme.nominal
            readonly property color accent: material.accent
            readonly property vector4d metrics: Qt.vector4d(width, height, Theme.unit, material.outputScale)
            // Full/reduced/off, intensity, installation direction, quality.
            readonly property vector4d policy: Qt.vector4d(Theme.animate ? Theme.ambientReduced ? 1 : 2 : 0,
                Theme.insane ? 1 : 0, Theme.integratedApps ? 1 : 0, Theme.shaderQuality)
            readonly property vector4d parameters: material.parameters
            readonly property real strength: material.strength
            fragmentShader: Qt.resolvedUrl("../shaders/" + material.shader + ".frag.qsb")
        }
    }
}
