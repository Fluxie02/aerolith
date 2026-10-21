import QtQuick
import qs.core

// Small uppercase instrument label.
Text {
    property bool strong: false
    color: strong ? Theme.text : Theme.textDim
    font.family: Theme.sans
    font.pixelSize: Theme.fontXs
    font.weight: strong ? Font.DemiBold : Font.Medium
    font.letterSpacing: 1.3
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
}
