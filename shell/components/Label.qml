import QtQuick
import qs.core

// Small uppercase instrument label.
Text {
    id: label
    property var profile: Theme
    textFormat: Text.PlainText
    property bool strong: false
    color: strong ? label.profile.text : label.profile.textDim
    font.family: Theme.mono
    font.pixelSize: Theme.fontXs
    font.weight: strong ? Font.DemiBold : Font.Medium
    font.letterSpacing: 1
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
}
