import QtQuick
import qs.core

Text {
    property var profile: Theme
    width: parent.width
    textFormat: Text.PlainText; wrapMode: Text.Wrap
    color: profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm; lineHeight: 1.3
}
