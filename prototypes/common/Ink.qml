import QtQuick
import qs.core
Text {
    required property var s
    property bool mono: false
    color: s.ink
    // QML font has family, not families; fontconfig supplies missing-family/glyph fallback.
    font.family: mono ? Config.theme.fontMono : Config.theme.fontSans
    font.pixelSize: s.body
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
