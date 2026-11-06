import QtQuick
import qs.core

// A registered section inside one housing; no independent floating card.
Column {
    id: section
    property var profile: Theme
    property string heading: ""
    spacing: Theme.du(10)
    Rectangle { width: parent.width; height: Theme.border; color: section.profile.grid }
    Text {
        width: parent.width; text: section.heading; textFormat: Text.PlainText
        wrapMode: Text.WordWrap; color: section.profile.signal
        font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1.2
    }
}
