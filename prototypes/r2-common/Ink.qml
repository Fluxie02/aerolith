import QtQuick
Text {
    required property var s
    property bool mono: true
    textFormat: Text.PlainText
    color: s.text
    font.family: mono ? s.mono : s.sans
    font.pixelSize: s.px(13)
    elide: Text.ElideRight
    renderType: Text.NativeRendering
}
