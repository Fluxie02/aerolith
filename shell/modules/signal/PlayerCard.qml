import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services
import "../../lib/telemetry.mjs" as T

// MPRIS player card. Controls the player does not support are shown
// disabled instead of being attempted.
Rectangle {
    id: card
    property var player: null
    property bool active: false
    property bool selected: false
    signal picked
    signal command(string id)

    // Live and endless streams report no length or a meaningless one
    // (shorter than the position); show the length as unknown then.
    readonly property bool lengthKnown: player !== null && player.lengthSupported && player.length > 0 && player.position <= player.length + 2

    function clock(s) {
        if (!isFinite(s) || s < 0)
            return "--:--";
        const m = Math.floor(s / 60);
        const sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    implicitHeight: col.implicitHeight + Theme.pad * 2
    color: selected ? Theme.surface2 : Theme.bg
    border.color: selected ? Theme.signal : active ? Theme.grid : Theme.alpha(Theme.grid, 0.5)
    border.width: Theme.border
    radius: Theme.radius

    MouseArea {
        anchors.fill: parent
        onClicked: card.picked()
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: Theme.px(4)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: card.player.isPlaying ? "▶ PLAYING" : "Ⅱ PAUSED"
                color: card.player.isPlaying ? Theme.signal : Theme.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
            Label {
                Layout.fillWidth: true
                text: card.player.identity + (card.active ? " · active" : "")
            }
        }
        Text {
            Layout.fillWidth: true
            text: card.player.trackTitle || "Unknown title"
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: Theme.fontLg
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: (card.player.trackArtist || card.player.trackAlbum) !== ""
            text: [card.player.trackArtist, card.player.trackAlbum].filter(s => s && s.length > 0).join(" · ")
            color: Theme.textDim
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            visible: card.player.positionSupported
            spacing: Theme.gap
            Text {
                text: card.clock(card.player.position)
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
            TapeGauge {
                Layout.fillWidth: true
                implicitHeight: Theme.px(10)
                value: card.lengthKnown ? card.player.position / card.player.length * 100 : NaN
                showCaret: false
            }
            Text {
                text: card.lengthKnown ? card.clock(card.player.length) : "--:--"
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
        }
        Row {
            spacing: Theme.gap
            Control {
                glyph: "⏮"
                enabled: card.player.canGoPrevious
                onTriggered: {
                    card.picked();
                    card.command("media.previous");
                }
            }
            Control {
                glyph: card.player.isPlaying ? "⏸" : "▶"
                enabled: card.player.canTogglePlaying
                onTriggered: {
                    card.picked();
                    card.command("media.play-pause");
                }
            }
            Control {
                glyph: "⏭"
                enabled: card.player.canGoNext
                onTriggered: {
                    card.picked();
                    card.command("media.next");
                }
            }
        }
    }

    component Control: Rectangle {
        id: btn
        property string glyph: ""
        signal triggered
        width: Theme.px(40)
        height: Theme.px(26)
        color: "transparent"
        border.color: enabled ? Theme.grid : Theme.alpha(Theme.grid, 0.4)
        border.width: Theme.border
        radius: Theme.radius
        opacity: enabled ? 1 : Theme.disabledOpacity
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: Theme.text
            font.pixelSize: Theme.fontMd
        }
        MouseArea {
            anchors.fill: parent
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
