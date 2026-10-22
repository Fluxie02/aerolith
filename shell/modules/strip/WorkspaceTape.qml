import QtQuick
import qs.core
import qs.services

// Workspace tape: numbered cells with occupancy ticks. The focused cell is
// boxed with phosphor registration brackets; urgent cells get an amber plate.
Row {
    id: tape
    spacing: Theme.px(2)

    // Cells 1..max(configured minimum, highest existing workspace).
    readonly property var cells: {
        const known = {};
        let highest = 0;
        const ws = Compositor.workspaces;
        for (let i = 0; i < ws.length; i++) {
            known[ws[i].id] = ws[i];
            highest = Math.max(highest, ws[i].id);
        }
        const n = Math.min(30, Math.max(Config.strip.workspaceCount, highest));
        const out = [];
        for (let id = 1; id <= n; id++) {
            const w = known[id];
            out.push({
                id: id,
                windows: w ? w.windows : 0,
                focused: id === Compositor.focusedWorkspaceId,
                urgent: w ? w.urgent : false
            });
        }
        return out;
    }

    Repeater {
        model: tape.cells
        delegate: Item {
            id: cell
            required property var modelData
            width: Math.round(Theme.stripHeight * 1.05)
            height: tape.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.px(3)
                color: cell.modelData.urgent ? (Theme.lowEffects ? Theme.surface2 : Theme.alpha(Theme.caution, 0.18)) : hover.containsMouse ? Theme.surface2 : "transparent"
                radius: Theme.radius
            }

            // Brackets around the focused workspace.
            Repeater {
                model: cell.modelData.focused ? 4 : 0
                delegate: Item {
                    required property int index
                    readonly property bool r: index % 2 === 1
                    readonly property bool b: index >= 2
                    x: r ? cell.width - width - Theme.px(2) : Theme.px(2)
                    y: b ? cell.height - height - Theme.px(3) : Theme.px(3)
                    width: Theme.px(5)
                    height: Theme.px(5)
                    Rectangle {
                        width: parent.width
                        height: Theme.px(2)
                        y: parent.b ? parent.height - height : 0
                        color: Theme.signal
                    }
                    Rectangle {
                        width: Theme.px(2)
                        height: parent.height
                        x: parent.r ? parent.width - width : 0
                        color: Theme.signal
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Theme.px(2)
                text: cell.modelData.id
                color: cell.modelData.focused ? Theme.signal : cell.modelData.urgent ? Theme.caution : cell.modelData.windows > 0 ? Theme.text : Theme.textDim
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
                        color: cell.modelData.focused ? Theme.signal : Theme.textDim
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
