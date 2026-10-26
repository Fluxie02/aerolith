import QtQuick
import qs.core
import qs.services

// A quiet empty state, with controls gated by the existing MPRIS service.
Item {
    id: now
    readonly property var player: Media.active
    readonly property bool hasTrack: player !== null
    implicitHeight: content.height

    Column {
        id: content
        width: parent.width; spacing: Theme.du(12)
        Text {
            text: now.hasTrack ? (Media.playing ? "NOW PLAYING" : "MEDIA / PAUSED") : "NOW PLAYING / NOTHING YET"
            textFormat: Text.PlainText
            color: Media.playing ? Theme.appLink : Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1.2
        }
        Row {
            width: parent.width; spacing: Theme.du(14); visible: now.hasTrack
            Image {
                id: cover
                readonly property string art: now.player ? now.player.trackArtUrl : ""
                source: now.visible ? art : ""
                visible: status === Image.Ready
                width: visible ? Theme.du(68) : 0; height: Theme.du(68)
                sourceSize.width: Theme.du(136); sourceSize.height: Theme.du(136)
                fillMode: Image.PreserveAspectCrop; asynchronous: true
            }
            Column {
                width: parent.width - (cover.visible ? cover.width + parent.spacing : 0)
                spacing: Theme.du(5)
                Text {
                    width: parent.width; text: Media.title; textFormat: Text.PlainText
                    color: Theme.text; font.family: Theme.displaySans
                    font.pixelSize: Theme.fontXl; font.weight: Font.Medium
                    maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight
                }
                Text {
                    width: parent.width; text: Media.artist || (now.player ? now.player.identity : "")
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Theme.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontMd
                }
            }
        }
        Row {
            spacing: Theme.du(8); visible: now.hasTrack
            MediaButton {
                label: Media.playing ? "PAUSE" : "PLAY"
                enabled: now.player !== null && now.player.canTogglePlaying
                onTriggered: Registry.run("media.play-pause", {})
            }
            MediaButton {
                label: "NEXT  →"
                enabled: now.player !== null && now.player.canGoNext
                onTriggered: Registry.run("media.next", {})
            }
        }
        Rectangle { width: parent.width; height: Theme.border; color: Theme.grid }
    }
    component MediaButton: Rectangle {
        id: control
        property string label: ""
        signal triggered()
        width: Theme.du(100); height: Theme.du(36)
        color: pointer.containsMouse && enabled ? Theme.surface2 : Theme.bg
        border.color: activeFocus ? Theme.signal : Theme.grid
        opacity: enabled ? 1 : Theme.disabledOpacity
        activeFocusOnTab: true
        Keys.onReturnPressed: if (enabled) triggered()
        Keys.onSpacePressed: if (enabled) triggered()
        Text {
            anchors.centerIn: parent; text: control.label; textFormat: Text.PlainText
            color: Theme.text; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
        MouseArea {
            id: pointer; anchors.fill: parent; enabled: control.enabled
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: control.triggered()
        }
        Accessible.role: Accessible.Button; Accessible.name: label
        Accessible.onPressAction: if (enabled) triggered()
    }
}
