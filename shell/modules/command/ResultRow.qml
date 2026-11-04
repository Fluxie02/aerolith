import QtQuick
import qs.core
import qs.components
import "../../lib/fuzzy.mjs" as Fuzzy

// A ruled entry in Limb's command field. Rich text is restricted to the
// escaped markup produced by Fuzzy; every annotation is plain text.
Item {
    id: row
    property var profile: Theme
    property var item: ({})
    property bool selected: false
    property bool confirming: false
    property string tag: "CMD"
    signal activated
    signal hovered

    readonly property bool available: item.available !== false

    Rectangle {
        anchors.fill: parent
        color: row.confirming ? (Theme.lowEffects || row.profile.profile === "oled" ? row.profile.surface2 : Theme.alpha(row.profile.caution, 0.12)) : row.selected ? row.profile.surface2 : "transparent"
        border.color: row.confirming ? row.profile.caution : "transparent"
        border.width: Theme.border
        radius: Theme.radius
    }
    Rectangle {
        visible: row.selected
        width: Theme.px(3)
        y: Theme.radius
        height: Math.max(0, parent.height - 2 * y)
        radius: width / 2
        color: row.confirming ? row.profile.caution : row.profile.signal
    }
    Rectangle {
        anchors.bottom: parent.bottom
        x: Theme.radius; width: parent.width - 2 * x
        height: Theme.border
        color: row.profile.grid
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad * 1.6
        anchors.right: right.left
        anchors.rightMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap
        Text {
            width: parent.width
            textFormat: Text.StyledText
            text: Fuzzy.highlightMarkup(row.item.title || "", row.item.highlights ? row.item.highlights.title : [], row.profile.signal)
            color: row.available ? row.profile.text : row.profile.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontMd + Theme.px(3)
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: !row.available ? "N/A · " + (row.item.reason || "unavailable") : row.item.subtitle || row.item.commandId || ""
            textFormat: Text.PlainText
            color: !row.available ? row.profile.caution : row.item.kind === "invocation" && row.item.valid === false ? row.profile.critical : row.profile.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs + Theme.px(1)
            elide: Text.ElideRight
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad * 1.6
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.pad
        Text {
            visible: (row.item.badge || "") !== ""
            text: row.item.badge || ""
            textFormat: Text.PlainText
            color: row.profile.signal
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            width: Math.min(implicitWidth, row.width * 0.13)
            elide: Text.ElideRight
        }
        Text {
            visible: row.available && (row.item.alias || "") !== "" && row.item.kind !== "invocation" && row.width > Theme.px(660)
            text: row.item.alias + (row.item.needsArgs ? " ‹…›" : "")
            textFormat: Text.PlainText
            color: row.profile.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            width: Math.min(implicitWidth, row.width * 0.13)
            elide: Text.ElideRight
        }
        Text {
            text: row.confirming ? "⏎ CONFIRM" : row.item.sensitive === true ? "CONFIRM" : row.tag
            textFormat: Text.PlainText
            color: row.item.sensitive === true ? row.profile.caution : row.profile.signal
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
        onEntered: row.hovered()
    }
}
