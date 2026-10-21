import QtQuick
import qs.core
import qs.components
import "../../lib/fuzzy.mjs" as Fuzzy

// One Command Core result: category tag, highlighted title, subtitle, and
// right-side annotations (badge, alias, unavailable reason, confirmation).
Item {
    id: row
    property var item: ({})
    property bool selected: false
    property bool confirming: false
    property string tag: "CMD"
    signal activated
    signal hovered

    readonly property bool available: item.available !== false
    opacity: available ? 1 : Theme.disabledOpacity + 0.15

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: Theme.px(1)
        color: row.confirming ? Theme.alpha(Theme.caution, 0.16) : row.selected ? Theme.surface2 : "transparent"
        radius: Theme.radius
        border.color: row.confirming ? Theme.caution : "transparent"
        border.width: Theme.border
    }
    // Selection datum on the left edge.
    Rectangle {
        visible: row.selected
        width: Theme.px(2)
        height: parent.height - Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        color: row.confirming ? Theme.caution : Theme.signal
    }

    Text {
        id: tagText
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(30)
        text: row.tag
        color: row.selected ? Theme.signal : Theme.textDim
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
        font.letterSpacing: 0.6
    }

    AppGlyph {
        id: glyph
        visible: row.item.kind === "app" || row.item.kind === "window"
        anchors.left: tagText.right
        anchors.verticalCenter: parent.verticalCenter
        size: Math.round(row.height * 0.55)
        icon: row.item.icon || ""
        fallback: row.item.title || ""
    }

    Column {
        anchors.left: glyph.visible ? glyph.right : tagText.right
        anchors.leftMargin: Theme.gap
        anchors.right: right.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(1)

        Text {
            width: parent.width
            textFormat: Text.StyledText
            text: Fuzzy.highlightMarkup(row.item.title || "", row.item.highlights ? row.item.highlights.title : [], Theme.signal)
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            elide: Text.ElideRight
        }
        Text {
            visible: (row.item.subtitle || "") !== ""
            width: parent.width
            text: row.item.subtitle || ""
            color: row.item.kind === "invocation" && row.item.valid === false ? Theme.critical : Theme.textDim
            font.family: row.item.kind === "invocation" ? Theme.mono : Theme.sans
            font.pixelSize: Theme.fontXs
            elide: Text.ElideRight
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Text {
            visible: !row.available
            text: "N/A · " + (row.item.reason || "")
            color: Theme.caution
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            width: Math.min(implicitWidth, Theme.px(220))
            elide: Text.ElideRight
        }
        Text {
            visible: row.item.sensitive === true
            text: row.confirming ? "⏎ CONFIRM" : "CONFIRM"
            color: Theme.caution
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
        }
        Text {
            visible: (row.item.badge || "") !== ""
            text: row.item.badge || ""
            color: Theme.signal
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
        }
        Text {
            visible: row.available && (row.item.alias || "") !== "" && row.item.kind !== "invocation"
            text: row.item.alias + (row.item.needsArgs ? " ‹…›" : "")
            color: Theme.textDim
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
