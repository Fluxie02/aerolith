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
    property var profile: Theme
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
    color: selected ? card.profile.surface2 : card.profile.bg
    border.color: selected ? card.profile.signal : card.profile.grid
    border.width: Theme.border
    radius: Theme.radius

    Rectangle {
        x: Theme.px(12)
        y: Theme.px(14)
        width: Theme.px(5)
        height: width
        rotation: 45
        color: card.selected || card.active ? card.profile.signal : card.profile.grid
    }

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
        anchors.leftMargin: Theme.pad + Theme.px(12)
        spacing: Theme.px(6)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: card.player.isPlaying ? "PLAYING / MPRIS" : "PAUSED / MPRIS"
                color: card.player.isPlaying ? card.profile.signal : card.profile.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                font.letterSpacing: 0.8
            }
            Label { profile: card.profile;
                Layout.fillWidth: true
                text: card.player.identity + (card.active ? " · active" : "")
            }
        }
        Text {
            Layout.fillWidth: true
            text: card.player.trackTitle || "Unknown title"
            textFormat: Text.PlainText
            color: card.profile.text
            font.family: Theme.displaySans
            font.pixelSize: Theme.fontLg
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: (card.player.trackArtist || card.player.trackAlbum) !== ""
            text: [card.player.trackArtist, card.player.trackAlbum].filter(s => s && s.length > 0).join(" · ")
            textFormat: Text.PlainText
            color: card.profile.textDim
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
                color: card.profile.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
            TapeGauge { profile: card.profile;
                Layout.fillWidth: true
                implicitHeight: Theme.px(10)
                value: card.lengthKnown ? card.player.position / card.player.length * 100 : NaN
                showCaret: false
            }
            Text {
                text: card.lengthKnown ? card.clock(card.player.length) : "--:--"
                color: card.profile.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
            }
        }
        Row {
            spacing: Theme.gap
            Control { profile: card.profile;
                glyph: "⏮"
                enabled: card.player.canGoPrevious
                onTriggered: {
                    card.picked();
                    card.command("media.previous");
                }
            }
            Control { profile: card.profile;
                glyph: card.player.isPlaying ? "⏸" : "▶"
                enabled: card.player.canTogglePlaying
                onTriggered: {
                    card.picked();
                    card.command("media.play-pause");
                }
            }
            Control { profile: card.profile;
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
        property var profile: Theme
        property string glyph: ""
        signal triggered
        width: Theme.px(44)
        height: Theme.px(30)
        color: controlMouse.containsMouse && enabled ? btn.profile.surface2 : "transparent"
        border.color: btn.profile.grid
        border.width: Theme.border
        radius: Theme.radius
        opacity: enabled ? 1 : Theme.disabledOpacity
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.profile.text
            font.pixelSize: Theme.fontMd
        }
        MouseArea {
            id: controlMouse
            anchors.fill: parent
            enabled: btn.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
