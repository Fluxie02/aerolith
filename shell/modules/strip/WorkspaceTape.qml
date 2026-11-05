import QtQuick
import qs.core
import qs.services

// Workspace tape: numbered cells with occupancy ticks. The focused cell is
// boxed with phosphor registration brackets; urgent cells get an amber plate.
Row {
    id: tape
    property var profile: Theme
    property bool compact: false
    spacing: Theme.px(2)

    readonly property var cells: Compositor.workspaceCells

    Repeater {
        model: tape.cells
        delegate: Item {
            id: cell
            required property var modelData
            width: Math.round(Theme.stripHeight * (tape.compact ? .8 : 1.05))
            height: tape.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.px(3)
                color: cell.modelData.urgent ? (Theme.lowEffects || tape.profile.profile === "oled" ? tape.profile.surface2 : Theme.alpha(tape.profile.caution, 0.18)) : hover.containsMouse ? tape.profile.surface2 : "transparent"
                radius: Theme.radius
            }

            // The same soft focus ring used by the Deck route.
            Rectangle {
                anchors.fill: parent; anchors.margins: Theme.px(3)
                visible: cell.modelData.focused
                color: tape.profile.surface2; radius: Theme.radius
                border.width: Theme.border; border.color: tape.profile.signal
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Theme.px(2)
                text: cell.modelData.id
                color: cell.modelData.focused ? tape.profile.signal : cell.modelData.urgent ? tape.profile.caution : cell.modelData.windows > 0 ? tape.profile.text : tape.profile.textDim
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                font.weight: cell.modelData.focused ? Font.Bold : Font.Normal
            }

            // Occupancy: one tick per window, up to four.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.px(5)
                spacing: Theme.px(2)
                Repeater {
                    model: Math.min(4, cell.modelData.windows)
                    Rectangle {
                        width: Theme.px(3)
                        height: Theme.px(2)
                        color: cell.modelData.focused ? tape.profile.signal : tape.profile.textDim
                    }
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Registry.run("workspace.focus", {
                    workspace: cell.modelData.id
                }, {
                    record: false
                })
            }
        }
    }

    WheelHandler {
        onWheel: event => Registry.execute(event.angleDelta.y > 0 ? "workspace.previous" : "workspace.next", {}, {
                record: false
            })
    }
}
